/**
 * Resolve automaticamente Oportunidade__c para Repasses criados manualmente
 * (Origem_de_Criacao__c em branco), reaproveitando a mesma regra de matching
 * usada pela API (OportunidadeMatcher). Se não encontrar uma Oportunidade
 * compatível, cria uma nova — igual ao fluxo da API. Se não for possível
 * determinar a construtora ou nenhum proponente estiver informado, bloqueia
 * o salvamento com addError.
 *
 * Diferente do Case, Repasse__c já tem Construtora__c (lookup direto para
 * Account) e Empresa__c/ID_da_Incorporadora__c preenchidos pelo próprio
 * analista — não precisa passar por Empreendimento nem por um Record Type
 * para descobrir esses dados.
 */
public without sharing class RepasseTriggerHandler {

    /**
     * Quando true, aplicarSinteseInicial não move o Repasse para a sub-fase
     * "Montagem Repasse" nesta transação e, portanto, não dispara a criação
     * automática do card (Flow "Repasse - Criar Card Montagem Repasse").
     * Usado por RepasseService para importações manuais de processos antigos
     * (RepasseRequest.importacaoManual = true), onde o card não deve ser
     * criado/movimentado automaticamente. Escopo: transação atual — quem liga
     * a flag é responsável por desligá-la depois do insert.
     */
    public static Boolean pularMontagemAutomatica = false;

    /**
     * Define a fase inicial (Status_do_Repasse__c) para todo novo Repasse__c,
     * independente da origem de criação (API ou manual). Só aplica o padrão
     * quando o campo vier em branco, para não sobrescrever um valor já informado.
     * Não aplica o padrão em registros já marcados com duplicidade de CPF por
     * checkCpfDuplicado (Mensagem_Erro__c preenchido) — ver comentário lá.
     */
    public static void setStatusInicial(List<SObject> repasses) {
        for (SObject r : repasses) {
            if (r.get(SFConfig.REP_MENSAGEM_ERRO) != null) continue;
            if (r.get(SFConfig.REP_STATUS_REPASSE) == null) {
                r.put(SFConfig.REP_STATUS_REPASSE, SFConfig.STATUS_REPASSE_FORMULARIO);
            }
        }
    }

    /**
     * Porta da regra de duplicidade do ProcessQueueCreateCardDuplicated.cs (Pipefy):
     * ao criar um Repasse__c, verifica se algum outro Repasse__c ainda não concluído
     * (Status_do_Repasse__c != 'Concluído') compartilha ao menos um CPF de proponente
     * (CPF_Proponente_1..4__c). Réplica intencional do comportamento "simples" do
     * original: qualquer colisão de CPF já marca duplicidade — não há checagem de
     * "todos os proponentes batem e a quantidade bate" (no Pipefy original essa
     * checagem existe mas nunca chega a bloquear o IsDuplicated mesmo assim).
     *
     * Quando encontra duplicidade, grava um aviso em Mensagem_Erro__c apontando para
     * o primeiro Repasse__c existente colidente. setStatusInicial e
     * aplicarSinteseInicial verificam esse campo para não aplicar os defaults de
     * fase/sub-fase neste registro, e marcarVendaDuplicada (after insert) o usa
     * como gatilho para marcar Poss_vel_Venda_Duplicada__c.
     *
     * Só compara contra registros já persistidos (outras transações) — Repasses
     * novos do mesmo lote de insert ainda não têm Id e não entram nesta consulta,
     * o que já reproduz a exclusão "do próprio card" do original.
     */
    public static void checkCpfDuplicado(List<SObject> repasses) {
        List<String> cpfFields = new List<String>{
            SFConfig.REP_CPF_PROP1, SFConfig.REP_CPF_PROP2,
            SFConfig.REP_CPF_PROP3, SFConfig.REP_CPF_PROP4
        };

        List<Set<String>> cpfsPorIndice = new List<Set<String>>();
        Set<String> todosCpfs = new Set<String>();
        for (SObject r : repasses) {
            Set<String> cpfsDoRegistro = new Set<String>();
            for (String field : cpfFields) {
                String cpf = (String) r.get(field);
                if (String.isNotBlank(cpf)) {
                    cpfsDoRegistro.add(cpf);
                    todosCpfs.add(cpf);
                }
            }
            cpfsPorIndice.add(cpfsDoRegistro);
        }
        if (todosCpfs.isEmpty()) return;

        String statusConcluido = SFConfig.STATUS_REPASSE_CONCLUIDO;
        String query =
            'SELECT Id, ' + String.join(cpfFields, ', ') +
            ' FROM ' + SFConfig.OBJ_REPASSE +
            ' WHERE ' + SFConfig.REP_STATUS_REPASSE + ' != :statusConcluido' +
            ' AND (' +
                SFConfig.REP_CPF_PROP1 + ' IN :todosCpfs OR ' +
                SFConfig.REP_CPF_PROP2 + ' IN :todosCpfs OR ' +
                SFConfig.REP_CPF_PROP3 + ' IN :todosCpfs OR ' +
                SFConfig.REP_CPF_PROP4 + ' IN :todosCpfs' +
            ')';
        Map<String, Id> primeiroRepassePorCpf = new Map<String, Id>();
        for (SObject existente : Database.query(query)) {
            Id existenteId = (Id) existente.get('Id');
            for (String field : cpfFields) {
                String cpf = (String) existente.get(field);
                if (String.isNotBlank(cpf) && todosCpfs.contains(cpf) && !primeiroRepassePorCpf.containsKey(cpf)) {
                    primeiroRepassePorCpf.put(cpf, existenteId);
                }
            }
        }
        if (primeiroRepassePorCpf.isEmpty()) return;

        String baseUrl = Url.getOrgDomainUrl().toExternalForm();
        for (Integer i = 0; i < repasses.size(); i++) {
            Id duplicadoId = null;
            for (String cpf : cpfsPorIndice[i]) {
                if (primeiroRepassePorCpf.containsKey(cpf)) {
                    duplicadoId = primeiroRepassePorCpf.get(cpf);
                    break;
                }
            }
            if (duplicadoId == null) continue;

            String link = baseUrl + '/lightning/r/' + SFConfig.OBJ_REPASSE + '/' + duplicadoId + '/view';
            repasses[i].put(SFConfig.REP_MENSAGEM_ERRO, SFConfig.REP_MSG_CPF_DUPLICADO.replace('{link}', link));
        }
    }

    /**
     * Define a sub-fase inicial (Sintese_Formulario__c) via um update numa
     * transação separada (Queueable), em vez de preenchê-la já no before insert
     * ou num update dentro do mesmo insert. Existe um Flow em Repasse__c
     * (recordTriggerType=Update) que cria um Item de Fila quando o campo muda
     * para "Montagem Repasse" — mas Flows de Update não disparam quando o
     * update acontece na MESMA transação do insert do registro (só reagem a
     * updates sobre registros já commitados de transações anteriores).
     */
    public static void aplicarSinteseInicial(List<SObject> repasses) {
        if (pularMontagemAutomatica) return;

        List<Id> repasseIds = new List<Id>();
        for (SObject r : repasses) {
            Boolean semSintese = r.get(SFConfig.REP_SINTESE_FORMULARIO) == null;
            Boolean semDuplicidadeCpf = r.get(SFConfig.REP_MENSAGEM_ERRO) == null;
            if (semSintese && semDuplicidadeCpf) {
                repasseIds.add((Id) r.get('Id'));
            }
        }
        if (!repasseIds.isEmpty()) {
            System.enqueueJob(new RepasseSinteseInicialJob(repasseIds));
        }
    }

    /**
     * Contrapartida visível do checkCpfDuplicado: além do aviso em texto
     * (Mensagem_Erro__c), marca Poss_vel_Venda_Duplicada__c para que o Flow
     * "Projetos Verificar Venda Duplicada" gere o card de conferência na fila
     * Projeto — antes disso a duplicidade só existia como texto no registro e
     * ninguém era acionado.
     *
     * Usa o mesmo desvio do aplicarSinteseInicial (update numa transação
     * separada via Queueable): o Flow filtra o campo por "Is Changed", operador
     * avaliado só em updates, então marcá-lo no before insert não o dispararia.
     */
    public static void marcarVendaDuplicada(List<SObject> repasses) {
        List<Id> repasseIds = new List<Id>();
        for (SObject r : repasses) {
            if (r.get(SFConfig.REP_MENSAGEM_ERRO) != null) {
                repasseIds.add((Id) r.get('Id'));
            }
        }
        if (!repasseIds.isEmpty()) {
            System.enqueueJob(new RepasseVendaDuplicadaJob(repasseIds));
        }
    }

    public static void resolveOportunidade(List<SObject> repasses) {
        List<SObject> elegiveis = new List<SObject>();
        Set<Id> construtoraIds = new Set<Id>();
        for (SObject r : repasses) {
            if (!isElegivelParaVinculo(r)) continue;
            elegiveis.add(r);
            Id construtoraId = (Id) r.get(SFConfig.REP_CONSTRUTORA);
            if (construtoraId != null) construtoraIds.add(construtoraId);
        }
        if (elegiveis.isEmpty()) return;

        Map<Id, SObject> construtoraById = new Map<Id, SObject>();
        if (!construtoraIds.isEmpty()) {
            String accQ = 'SELECT Id, Name FROM ' + SFConfig.OBJ_INCORPORADORA + ' WHERE Id IN :construtoraIds';
            for (SObject acc : Database.query(accQ)) {
                construtoraById.put((Id) acc.get('Id'), acc);
            }
        }

        for (SObject r : elegiveis) {
            Id construtoraId = (Id) r.get(SFConfig.REP_CONSTRUTORA);
            SObject construtora = construtoraId == null ? null : construtoraById.get(construtoraId);
            if (construtora == null) {
                r.addError('Não foi possível vincular a Oportunidade automaticamente: informe uma Construtora válida.');
                continue;
            }

            List<Id> proponenteIds = collectProponenteIds(r);
            if (proponenteIds.isEmpty()) {
                r.addError('Não foi possível vincular a Oportunidade automaticamente: informe ao menos um Cliente/Proponente.');
                continue;
            }

            SObject oportunidade = OportunidadeMatcher.findExistingOportunidadeRepasse(proponenteIds, construtoraId);
            if (oportunidade == null) {
                String idIncorporadora = (String) r.get(SFConfig.REP_ID_INCORPORADORA);
                String empresa = (String) r.get(SFConfig.REP_EMPRESA);
                oportunidade = OportunidadeMatcher.createOportunidadeRepasse(
                    proponenteIds, construtora, idIncorporadora, empresa, null
                );
            }

            r.put(SFConfig.REP_OPORTUNIDADE, oportunidade.get('Id'));
        }
    }

    /**
     * Dispara, de forma assíncrona, a criação da pasta de documentos (Drive)
     * associada à Oportunidade de cada Repasse__c recém-criado, quando essa
     * Oportunidade ainda não tiver uma pasta (Pasta_com_Documentos__c em
     * branco). Roda para qualquer origem de criação (API ou manual):
     * diferente do Case, o request de Repasse não chega com a pasta já
     * pronta, então os dois caminhos passam pelo mesmo after insert e
     * precisam do mesmo gatilho para garantir que toda Oportunidade
     * originada de um Repasse acabe com uma pasta vinculada.
     */
    public static void triggerCreditFolderCallout(List<SObject> repasses) {
        Set<Id> oppIds = new Set<Id>();
        for (SObject r : repasses) {
            Id oppId = (Id) r.get(SFConfig.REP_OPORTUNIDADE);
            if (oppId != null) oppIds.add(oppId);
        }
        if (oppIds.isEmpty()) return;

        Set<Id> oppsComPasta = new Set<Id>();
        String oppQ = 'SELECT Id FROM ' + SFConfig.OBJ_OPORTUNIDADE +
                      ' WHERE Id IN :oppIds AND ' + SFConfig.OPP_PASTA_DOCS + ' != null';
        for (SObject opp : Database.query(oppQ)) {
            oppsComPasta.add((Id) opp.get('Id'));
        }

        List<Id> repasseIds = new List<Id>();
        for (SObject r : repasses) {
            Id oppId = (Id) r.get(SFConfig.REP_OPORTUNIDADE);
            if (oppId != null && !oppsComPasta.contains(oppId)) {
                repasseIds.add((Id) r.get('Id'));
            }
        }
        if (!repasseIds.isEmpty()) {
            CreditFolderCalloutService.createFolders(repasseIds, 'repasse');
        }
    }

    private static Boolean isElegivelParaVinculo(SObject r) {
        Boolean isManual = String.isBlank((String) r.get(SFConfig.REP_ORIGEM_CRIACAO));
        Boolean semOportunidade = r.get(SFConfig.REP_OPORTUNIDADE) == null;
        return isManual && semOportunidade;
    }

    private static List<Id> collectProponenteIds(SObject r) {
        List<Id> ids = new List<Id>();
        for (String field : new List<String>{
            SFConfig.REP_CLIENTE1, SFConfig.REP_CLIENTE2,
            SFConfig.REP_CLIENTE3, SFConfig.REP_CLIENTE4
        }) {
            Id pid = (Id) r.get(field);
            if (pid != null) ids.add(pid);
        }
        return ids;
    }
}