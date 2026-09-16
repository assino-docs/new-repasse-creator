public without sharing class RepasseService {

    public Id execute(RepasseRequest req) {
        SObject construtora = findConstrutora(req.construtora.nome);
        if (construtora == null) {
            throw new ApiException(422, 'Construtora não encontrada: ' + req.construtora.nome);
        }
        Id constutoraId = (Id) construtora.get('Id');

        SObject repasseExistente = findRepasseExistente(constutoraId, req.idIncorporadora);
        Boolean mesmoProponente1 = repasseExistente != null &&
            proponenteConstaNoRepasseExistente(normalizeCpf(req.proponente1.cpf), repasseExistente);
        if (mesmoProponente1) {
            return (Id) repasseExistente.get('Id');
        }
        Boolean possivelDuplicado = (repasseExistente != null);

        List<RepasseRequest.ProponenteData> proponentesData = req.proponentes();
        List<Id> proponenteIds = new List<Id>();
        for (RepasseRequest.ProponenteData p : proponentesData) {
            proponenteIds.add((Id) findOrCreateProponente(p.cpf, p.nome, p.telefone, p.email).get('Id'));
        }

        SObject oportunidade = findExistingOportunidade(proponenteIds, constutoraId);
        Boolean oportunidadeNova = (oportunidade == null);
        if (oportunidadeNova) {
            oportunidade = createOportunidade(proponenteIds, construtora, req.idIncorporadora, req.empresa, req.linkDrive);
        } else {
            aplicarLinkDriveEmOportunidadeExistente(oportunidade, req.linkDrive);
        }
        Id oportunidadeId = (Id) oportunidade.get('Id');

        SObject empreendimento = findOrCreateEmpreendimento(req.empreendimento.nome, constutoraId);
        Id empreendimentoId = (Id) empreendimento.get('Id');
        String empreendimentoNome = (String) empreendimento.get('Name');

        SObject unidadeHab = findOrCreateUnidadeHabitacional(
            empreendimentoId, constutoraId, empreendimentoNome, req.torre, req.unidade
        );
        Id unidadeHabId = (Id) unidadeHab.get('Id');

        Boolean pularMontagemAutomatica = req.importacaoManual == true || possivelDuplicado;
        if (pularMontagemAutomatica) {
            RepasseTriggerHandler.pularMontagemAutomatica = true;
        }
        Id repasseId;
        try {
            repasseId = createRepasse(
                req, oportunidadeId, empreendimentoId, unidadeHabId, constutoraId, proponenteIds, empreendimentoNome
            );
        } finally {
            if (pularMontagemAutomatica) {
                RepasseTriggerHandler.pularMontagemAutomatica = false;
            }
        }

        if (oportunidadeNova) {
            FeedItem fi = new FeedItem();
            fi.ParentId = repasseId;
            fi.Body = 'Nenhuma oportunidade existente foi encontrada para os proponentes informados. Uma nova oportunidade foi criada automaticamente e vinculada a este repasse.';
            insert fi;
        }

        if (possivelDuplicado) {
            String baseUrl = Url.getOrgDomainUrl().toExternalForm();
            String link = baseUrl + '/lightning/r/' + SFConfig.OBJ_REPASSE + '/' + repasseExistente.get('Id') + '/view';
            FeedItem fi = new FeedItem();
            fi.ParentId = repasseId;
            fi.Body = 'Já existe um Repasse não concluído para esta Incorporadora + ID da Incorporadora, mas com Proponente 1 diferente — possível transferência do imóvel para outro cliente. Repasse possivelmente relacionado: ' + link;
            insert fi;
        }

        return repasseId;
    }

    // ── Util ──────────────────────────────────────────────────

    private static String normalizeCpf(String cpf) {
        if (cpf == null) return null;
        String d = cpf.replaceAll('[^0-9]', '');
        if (d.length() != 11) return cpf;
        return d.substring(0, 3) + '.' + d.substring(3, 6) + '.' + d.substring(6, 9) + '-' + d.substring(9, 11);
    }

    /**
     * Unidade__c é numérica porque atende o cadastro da unidade na Caixa (SIOPI),
     * que não aceita letras nem símbolos. A incorporadora pode enviar a unidade
     * completa (ex.: "101-A", "Cob 2") — esse valor íntegro vai para
     * Unidade_Incorporadora__c, usado no cadastro da Una Incorporadora.
     */
    private static String somenteDigitos(String valor) {
        if (valor == null) return null;
        return valor.replaceAll('[^0-9]', '');
    }

    // ── Construtora ───────────────────────────────────────────

    private SObject findConstrutora(String nome) {
        String q = 'SELECT Id, Name FROM ' + SFConfig.OBJ_INCORPORADORA +
                   ' WHERE Name = :nome LIMIT 1';
        List<SObject> results = Database.query(q);
        return results.isEmpty() ? null : results[0];
    }

    // ── Proponente ────────────────────────────────────────────

    private SObject findOrCreateProponente(String cpf, String nome, String telefone, String email) {
        String normalizedCpf = normalizeCpf(cpf);
        String categoria = SFConfig.FUNCAO_CLIENTE;
        String q = 'SELECT Id, ' + SFConfig.CON_CATEGORIA + ' FROM ' + SFConfig.OBJ_PROPONENTE +
                   ' WHERE ' + SFConfig.PROP_CPF + ' = :normalizedCpf' +
                   ' AND (' + SFConfig.CON_CATEGORIA + ' = :categoria' +
                   ' OR ' + SFConfig.CON_CATEGORIA + ' = null) LIMIT 1';
        List<SObject> results = Database.query(q);
        if (!results.isEmpty()) {
            SObject found = results[0];
            Boolean categoriaVazia = found.get(SFConfig.CON_CATEGORIA) == null;
            if (categoriaVazia || String.isNotBlank(telefone) || String.isNotBlank(email)) {
                SObject upd = Schema.getGlobalDescribe().get(SFConfig.OBJ_PROPONENTE).newSObject();
                upd.put('Id', found.get('Id'));
                if (categoriaVazia) {
                    upd.put(SFConfig.CON_CATEGORIA, SFConfig.FUNCAO_CLIENTE);
                }
                if (String.isNotBlank(telefone)) {
                    upd.put(SFConfig.CON_MOBILE, telefone);
                    upd.put(SFConfig.CON_TELEFONE, telefone);
                }
                if (String.isNotBlank(email)) {
                    upd.put(SFConfig.CON_EMAIL, email);
                }
                update upd;
            }
            return found;
        }

        SObject prop = Schema.getGlobalDescribe().get(SFConfig.OBJ_PROPONENTE).newSObject();
        prop.put(SFConfig.PROP_CPF, normalizedCpf);
        prop.put(SFConfig.CON_CATEGORIA, SFConfig.FUNCAO_CLIENTE);
        prop.put(SFConfig.CON_LASTNAME, nome);
        if (String.isNotBlank(telefone)) {
            prop.put(SFConfig.CON_MOBILE, telefone);
            prop.put(SFConfig.CON_TELEFONE, telefone);
        }
        if (String.isNotBlank(email)) {
            prop.put(SFConfig.CON_EMAIL, email);
        }
        insert prop;
        return prop;
    }

    // ── Oportunidade ──────────────────────────────────────────

    /**
     * Busca uma Oportunidade aberta vinculada à construtora onde TODOS os
     * proponentes do repasse estejam presentes nos slots de Cliente (em qualquer
     * combinação). A Oportunidade pode ter mais contatos do que os informados.
     */
    private SObject findExistingOportunidade(List<Id> proponenteIds, Id constutoraId) {
        return OportunidadeMatcher.findExistingOportunidadeRepasse(proponenteIds, constutoraId);
    }

    private SObject createOportunidade(
        List<Id> proponenteIds,
        SObject construtora,
        String idIncorporadora,
        String empresa,
        String linkDrive
    ) {
        return OportunidadeMatcher.createOportunidadeRepasse(proponenteIds, construtora, idIncorporadora, empresa, linkDrive);
    }

    /**
     * A Pasta_com_Documentos__c nunca é sobrescrita: se a Oportunidade encontrada
     * já tiver um link, o novo link recebido só é registrado como comentário no
     * Chatter dela (indício de duplicidade), nunca substitui o valor existente.
     */
    private void aplicarLinkDriveEmOportunidadeExistente(SObject oportunidade, String linkDrive) {
        if (String.isBlank(linkDrive)) return;

        String linkAtual = (String) oportunidade.get(SFConfig.OPP_PASTA_DOCS);
        if (String.isBlank(linkAtual)) {
            SObject upd = Schema.getGlobalDescribe().get(SFConfig.OBJ_OPORTUNIDADE).newSObject();
            upd.put('Id', oportunidade.get('Id'));
            upd.put(SFConfig.OPP_PASTA_DOCS, linkDrive);
            update upd;
        } else {
            FeedItem fi = new FeedItem();
            fi.ParentId = (Id) oportunidade.get('Id');
            fi.Body = 'Um novo Repasse informou um link de Drive para esta Oportunidade, que já possui uma pasta vinculada (possível duplicidade): ' + linkDrive;
            insert fi;
        }
    }

    // ── Empreendimento ────────────────────────────────────────

    private SObject findOrCreateEmpreendimento(String nome, Id constutoraId) {
        String alvo = TextUtil.normalizar(nome);
        String q = 'SELECT Id, Name FROM ' + SFConfig.OBJ_EMPREENDIMENTO +
                   ' WHERE ' + SFConfig.EMP_INCORPORADORA + ' = :constutoraId';
        for (SObject emp : Database.query(q)) {
            String nomeExistente = (String) emp.get(SFConfig.EMP_NOME);
            if (nomeExistente != null && TextUtil.normalizar(nomeExistente) == alvo) {
                return emp;
            }
        }

        SObject novo = Schema.getGlobalDescribe().get(SFConfig.OBJ_EMPREENDIMENTO).newSObject();
        novo.put(SFConfig.EMP_NOME, TextUtil.capitalizar(nome));
        novo.put(SFConfig.EMP_INCORPORADORA, constutoraId);
        insertIgnorandoRegraDeDuplicidade(novo);
        return novo;
    }

    /**
     * O dedup já foi feito acima (case/acento-insensitive, por incorporadora);
     * a Duplicate Rule declarativa do Empreendimento__c não tem esse contexto e
     * pode bloquear inserts legítimos. Contorna o bloqueio via
     * DuplicateRuleHeader, mantendo o Apex como única fonte de verdade.
     */
    private static void insertIgnorandoRegraDeDuplicidade(SObject registro) {
        Database.DMLOptions dmo = new Database.DMLOptions();
        dmo.DuplicateRuleHeader.allowSave = true;
        Database.insert(registro, dmo);
    }

    // ── Unidade Habitacional ──────────────────────────────────

    private SObject findOrCreateUnidadeHabitacional(
        Id empreendimentoId,
        Id constutoraId,
        String empreendimentoNome,
        String torre,
        String unidade
    ) {
        String q = 'SELECT Id FROM ' + SFConfig.OBJ_UNIDADE_HAB +
                   ' WHERE ' + SFConfig.UH_EMPREENDIMENTO + ' = :empreendimentoId' +
                   ' AND ' + SFConfig.UH_TORRE + ' = :torre' +
                   ' AND ' + SFConfig.UH_UNIDADE + ' = :unidade LIMIT 1';
        List<SObject> results = Database.query(q);
        if (!results.isEmpty()) return results[0];

        SObject uh = Schema.getGlobalDescribe().get(SFConfig.OBJ_UNIDADE_HAB).newSObject();
        uh.put('Name', empreendimentoNome + '_' + torre + '_' + unidade);
        uh.put(SFConfig.UH_TORRE, torre);
        uh.put(SFConfig.UH_UNIDADE, unidade);
        uh.put(SFConfig.UH_EMPREENDIMENTO, empreendimentoId);
        uh.put(SFConfig.UH_INCORPORADORA, constutoraId);
        insert uh;
        return uh;
    }

    // ── Repasse ───────────────────────────────────────────────

    /**
     * Detecta duplicidade de Repasse__c pela combinação Incorporadora (Account)
     * + ID_da_Incorporadora__c (identificador texto do processo, vindo do
     * payload), restrito a Repasses ainda não Concluídos. Quem chama decide o
     * desfecho: Proponente 1 do payload presente em qualquer um dos 4 slots de
     * CPF do Repasse encontrado = mesmo processo, não recria; ausente = possível
     * transferência do imóvel para outro cliente (cria um novo Repasse, mas
     * sinaliza a duplicidade e não avança a fase).
     */
    private SObject findRepasseExistente(Id constutoraId, String idIncorporadora) {
        String statusConcluido = SFConfig.STATUS_REPASSE_CONCLUIDO;
        String q = 'SELECT Id, ' + SFConfig.REP_CPF_PROP1 + ', ' + SFConfig.REP_CPF_PROP2 +
                   ', ' + SFConfig.REP_CPF_PROP3 + ', ' + SFConfig.REP_CPF_PROP4 +
                   ' FROM ' + SFConfig.OBJ_REPASSE +
                   ' WHERE ' + SFConfig.REP_CONSTRUTORA + ' = :constutoraId' +
                   ' AND ' + SFConfig.REP_ID_INCORPORADORA + ' = :idIncorporadora' +
                   ' AND ' + SFConfig.REP_STATUS_REPASSE + ' != :statusConcluido' +
                   ' LIMIT 1';
        List<SObject> results = Database.query(q);
        return results.isEmpty() ? null : results[0];
    }

    /**
     * A incorporadora pode reenviar os proponentes em outra ordem entre os slots
     * 1-4 (ex.: quem era Proponente 1 numa importação aparece como Proponente 2
     * noutra) — por isso compara contra os 4 slots de CPF do Repasse existente,
     * não só o primeiro.
     */
    private static Boolean proponenteConstaNoRepasseExistente(String cpfNormalizado, SObject repasseExistente) {
        List<String> camposCpf = new List<String>{
            SFConfig.REP_CPF_PROP1, SFConfig.REP_CPF_PROP2,
            SFConfig.REP_CPF_PROP3, SFConfig.REP_CPF_PROP4
        };
        for (String campo : camposCpf) {
            if (cpfNormalizado == (String) repasseExistente.get(campo)) {
                return true;
            }
        }
        return false;
    }

    private Id createRepasse(
        RepasseRequest req,
        Id oportunidadeId,
        Id empreendimentoId,
        Id unidadeHabId,
        Id constutoraId,
        List<Id> proponenteIds,
        String empreendimentoNome
    ) {
        SObject rep = Schema.getGlobalDescribe().get(SFConfig.OBJ_REPASSE).newSObject();
        rep.put('Name', empreendimentoNome + ' - ' + req.torre + ' - ' + req.unidade);
        rep.put(SFConfig.REP_OPORTUNIDADE, oportunidadeId);
        rep.put(SFConfig.REP_EMPREENDIMENTO, empreendimentoId);
        rep.put(SFConfig.REP_CONSTRUTORA, constutoraId);
        rep.put(SFConfig.REP_UNIDADE_HAB, unidadeHabId);
        rep.put(SFConfig.REP_EMPRESA, req.empresa);
        rep.put(SFConfig.REP_TORRE, req.torre);
        String unidadeSiopi = somenteDigitos(req.unidade);
        if (String.isNotBlank(unidadeSiopi)) {
            rep.put(SFConfig.REP_UNIDADE, Decimal.valueOf(unidadeSiopi));
        }
        if (String.isNotBlank(req.unidade)) {
            rep.put(SFConfig.REP_UNIDADE_INCORP, req.unidade.trim());
        }
        rep.put(SFConfig.REP_ID_INCORPORADORA, req.idIncorporadora);
        rep.put(SFConfig.REP_ORIGEM_CRIACAO, SFConfig.ORIGEM_API);
        if (String.isNotBlank(req.dataInput)) {
            rep.put(SFConfig.REP_DATA_INPUT, req.dataInputAsDate());
        }
        if (String.isNotBlank(req.responsavelItbi)) {
            rep.put(SFConfig.REP_RESP_ITBI, req.responsavelItbi);
        }
        if (String.isNotBlank(req.responsavelCustas)) {
            rep.put(SFConfig.REP_RESP_CUSTAS, req.responsavelCustas);
        }
        if (String.isNotBlank(req.enquadramento)) {
            rep.put(SFConfig.REP_ENQUADRAMENTO_UNID, req.enquadramento);
        }
        if (String.isNotBlank(req.pipefyId)) {
            rep.put(SFConfig.REP_PIPEFY_ID, req.pipefyId);
        }

        // Proponentes: lookup (Contact) + campos de texto para nome e CPF
        List<String> clienteSlots = new List<String>{
            SFConfig.REP_CLIENTE1, SFConfig.REP_CLIENTE2,
            SFConfig.REP_CLIENTE3, SFConfig.REP_CLIENTE4
        };
        List<String> nomeProps = new List<String>{
            SFConfig.REP_NOME_PROP1, SFConfig.REP_NOME_PROP2,
            SFConfig.REP_NOME_PROP3, SFConfig.REP_NOME_PROP4
        };
        List<String> cpfProps = new List<String>{
            SFConfig.REP_CPF_PROP1, SFConfig.REP_CPF_PROP2,
            SFConfig.REP_CPF_PROP3, SFConfig.REP_CPF_PROP4
        };
        List<RepasseRequest.ProponenteData> proponentesData = req.proponentes();
        for (Integer i = 0; i < proponentesData.size() && i < 4; i++) {
            rep.put(clienteSlots[i], proponenteIds[i]);
            rep.put(nomeProps[i], proponentesData[i].nome);
            rep.put(cpfProps[i], normalizeCpf(proponentesData[i].cpf));
        }

        // Fiadores — campos de texto apenas (lookup com Contact será adicionado futuramente)
        if (req.fiador1 != null) {
            if (String.isNotBlank(req.fiador1.nome)) rep.put(SFConfig.REP_NOME_FIADOR1, req.fiador1.nome);
            if (String.isNotBlank(req.fiador1.cpf))  rep.put(SFConfig.REP_CPF_FIADOR1, normalizeCpf(req.fiador1.cpf));
        }
        if (req.fiador2 != null) {
            if (String.isNotBlank(req.fiador2.nome)) rep.put(SFConfig.REP_NOME_FIADOR2, req.fiador2.nome);
            // CPF_FIADOR_2__c: campo pendente de confirmação no org
        }

        insert rep;
        return (Id) rep.get('Id');
    }
}