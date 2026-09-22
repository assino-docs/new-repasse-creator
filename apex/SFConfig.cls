public class SFConfig {
    // ── Objetos ──────────────────────────────────────────────
    public static final String OBJ_INCORPORADORA   = 'Account';
    public static final String OBJ_OPORTUNIDADE    = 'Opportunity';
    public static final String OBJ_PROPONENTE      = 'Contact';
    public static final String OBJ_EMPREENDIMENTO  = 'Empreendimento__c';
    public static final String OBJ_ANALISE_CREDITO = 'Case';

    // ── Incorporadora ─────────────────────────────────────────
    public static final String INC_NOME            = 'Name';
    public static final String INC_SLA             = 'SLA__c';
    public static final String INC_DEFIN_DIA_UTIL  = 'Definicao_Dia_util__c';

    // ── Lead (objeto padrão SF) ───────────────────────────────
    // CPF no objeto Lead — alterar para o campo real
    public static final String LEAD_CPF            = 'MobilePhone';

    // ── Oportunidade ──────────────────────────────────────────
    public static final String OPP_NAME            = 'Name';
    public static final String OPP_INCORPORADORA   = 'AccountId';
    public static final String OPP_STAGE_NAME      = 'StageName';
    public static final String OPP_CLOSE_DATE      = 'CloseDate';
    public static final String OPP_PROPONENTE1     = 'Cliente__c';
    public static final String OPP_PROPONENTE2     = 'Cliente_2__c';
    public static final String OPP_PROPONENTE3     = 'Cliente_3__c';
    public static final String OPP_PROPONENTE4     = 'Cliente_4__c';
    public static final String OPP_EMPRESA         = 'Empresa__c';
    public static final String OPP_PASTA_DOCS      = 'Pasta_com_Documentos__c';

    // ── Proponente ────────────────────────────────────────────
    public static final String PROP_CPF            = 'CPF__c';
    public static final String PROP_NOME           = 'Name';

    // ── Empreendimento ────────────────────────────────────────
    public static final String EMP_NOME            = 'Name';
    public static final String EMP_INCORPORADORA   = 'Incorporadora__c';
    public static final String EMP_REGRA_ALOCACAO  = 'Regra_Alocacao_Agencia__c';

    // ── Agência ───────────────────────────────────────────────
    public static final String OBJ_AGENCIA         = 'Agencia__c';
    public static final String AGE_CODIGO          = 'C_digo_da_ag_ncia__c';

    // ── Analise de Credito ────────────────────────────────────
    public static final String AC_OPORTUNIDADE          = 'Oportunidade__c';
    public static final String AC_EMPREENDIMENTO        = 'Empreendimento__c';
    public static final String AC_PROPONENTE1           = 'Proponente_1__c';
    public static final String AC_PROPONENTE2           = 'Proponente_2__c';
    public static final String AC_PROPONENTE3           = 'Proponente_3__c';
    public static final String AC_PROPONENTE4           = 'Proponente_4__c';
    public static final String AC_FASE                  = 'Fase_Analise_de_Credito__c';
    public static final String AC_ENTRADA_FILA_DATA     = 'Data_Hora_Entrada_Fila_Data__c';
    public static final String AC_ENTRADA_FILA_HORA     = 'Data_Hora_Entrada_Fila_Hora__c';
    public static final String AC_FECHAMENTO_DATA       = 'Data_fechamento_Data__c';
    public static final String AC_FECHAMENTO_HORA       = 'Data_fechamento_Hora__c';
    public static final String AC_DEMANDAS              = 'Demandas_solicitadas__c';
    public static final String AC_INCORPORADORA         = 'ID_Incorporadora__c';
    public static final String AC_PRIORIDADE            = 'Prioridade__c';
    public static final String AC_SLA_DATA              = 'Data_Hora_Limite_SLA_Data__c';
    public static final String AC_SLA_HORA              = 'Data_Hora_Limite_SLA_Hora__c';
    public static final String AC_AGENCIA               = 'Agencia__c';
    public static final String AC_RESPONSAVEL           = 'Responsavel__c';
    public static final String AC_RESPONSAVEL_REL       = 'Responsavel__r';
    public static final String AC_RESPONSAVEL_NOME      = 'Responsavel__r.Name';
    public static final String AC_ULTIMO_ANALISTA       = 'Ltimo_Analista__c';
    public static final String AC_ORIGEM_CRIACAO        = 'Origem_de_Criacao__c';
    public static final String AC_REGISTRO_DUPLICADO    = 'Registro_Duplicado__c';

    // Fases do Case ainda "em andamento" (não conclusivas) — usadas para
    // restringir a verificação de duplicidade por CPF a análises que ainda
    // não foram encerradas.
    public static final List<String> AC_FASES_EM_ANDAMENTO = new List<String>{
        'Triagem', 'Alocar', 'Alocado', 'Fazendo', 'Pausado'
    };

    // ── Equipe de Vendas (vinculada como Contato) ─────────────
    // O objeto Equipe_de_Vendas__c saiu do projeto (importação manual).
    // Agora cada função (Diretor/Superintendente/Gerente/Corretor) é um Contact
    // vinculado ao Case nestes lookups (todos -> Contact):
    public static final String AC_DIRETOR               = 'Diretor_c__c';
    public static final String AC_SUPERINTENDENTE       = 'Superintendente_c__c';
    public static final String AC_GERENTE               = 'Gerente_c__c';
    public static final String AC_CORRETOR              = 'Corretor_c__c';

    // ── Contato da Equipe de Vendas (objeto Contact) ──────────
    public static final String CON_FIRSTNAME            = 'FirstName';
    public static final String CON_LASTNAME             = 'LastName';
    public static final String CON_IDENTIFICADOR        = 'Identificador__c';
    public static final String CON_ID_INCORPORADORA     = 'Identifica_o_Incorporadora__c';
    public static final String CON_TELEFONE             = 'Phone';
    public static final String CON_MOBILE                = 'MobilePhone';
    public static final String CON_EMAIL                = 'Email';
    public static final String CON_CATEGORIA            = 'Categoria__c';

    // Vínculo hierárquico entre os papéis da equipe de vendas (Contact → Contact).
    // Corretor pode ter Gerente/Superintendente/Diretor; Gerente pode ter
    // Superintendente/Diretor; Superintendente pode ter Diretor.
    public static final String CON_GERENTE               = 'Gerente__c';
    public static final String CON_SUPERINTENDENTE       = 'Superintendente__c';
    public static final String CON_DIRETOR               = 'Diretor__c';

    // Valores do picklist Categoria__c (função na equipe de vendas)
    public static final String FUNCAO_DIRETOR           = 'Diretor';
    public static final String FUNCAO_SUPERINTENDENTE   = 'Superintendente';
    public static final String FUNCAO_GERENTE           = 'Gerente';
    public static final String FUNCAO_CORRETOR          = 'Corretor';
    public static final String FUNCAO_CLIENTE           = 'Cliente';

    // ── Origem de criação (API vs manual) ─────────────────────
    public static final String ORIGEM_API               = 'API';

    // ── Repasse ───────────────────────────────────────────────
    public static final String OBJ_REPASSE             = 'Repasse__c';
    public static final String REP_OPORTUNIDADE        = 'Oportunidade__c';
    public static final String REP_EMPREENDIMENTO      = 'Empreendimento__c';
    public static final String REP_CONSTRUTORA         = 'Construtora__c';
    public static final String REP_UNIDADE_HAB         = 'Unidade_Habitacional__c';
    public static final String REP_EMPRESA             = 'Empresa__c';
    public static final String REP_TORRE               = 'Torre__c';
    public static final String REP_UNIDADE             = 'Unidade__c';
    public static final String REP_UNIDADE_INCORP      = 'Unidade_Incorporadora__c';
    public static final String REP_ID_INCORPORADORA    = 'ID_da_Incorporadora__c';
    public static final String REP_DATA_INPUT          = 'Data_Input__c';
    public static final String REP_CLIENTE1            = 'Cliente_1__c';
    public static final String REP_CLIENTE2            = 'Cliente_2__c';
    public static final String REP_CLIENTE3            = 'Cliente_3__c';
    public static final String REP_CLIENTE4            = 'Cliente_4__c';
    public static final String REP_RESP_ITBI           = 'Responsavel_Pagamento_ITBI__c';
    public static final String REP_RESP_CUSTAS         = 'RESPONSAVEL_PELO_PAGAMENTO_CUSTAS__c';
    public static final String REP_ENQUADRAMENTO_UNID  = 'Enquadramento_da_Unidade__c';
    public static final String REP_PIPEFY_ID           = 'PipefyId__c';
    public static final String REP_NOME_FIADOR1        = 'NOME_FIADOR_1__c';
    public static final String REP_NOME_FIADOR2        = 'NOME_FIADOR_2__c';
    public static final String REP_CPF_FIADOR1         = 'CPF_FIADOR_1__c';
    public static final String REP_NOME_PROP1          = 'Nome_Proponente_1__c';
    public static final String REP_NOME_PROP2          = 'Nome_Proponente_2__c';
    public static final String REP_NOME_PROP3          = 'Nome_Proponente_3__c';
    public static final String REP_NOME_PROP4          = 'Nome_Proponente_4__c';
    public static final String REP_CPF_PROP1           = 'CPF_Proponente_1__c';
    public static final String REP_CPF_PROP2           = 'CPF_Proponente_2__c';
    public static final String REP_CPF_PROP3           = 'CPF_Proponente_3__c';
    public static final String REP_CPF_PROP4           = 'CPF_Proponente_4__c';
    public static final String REP_ORIGEM_CRIACAO      = 'Origem_de_Criacao__c';
    public static final String REP_STATUS_REPASSE      = 'Status_do_Repasse__c';
    public static final String REP_SINTESE_FORMULARIO  = 'Sintese_Formulario__c';
    public static final String REP_SINTESE_CONTRATO    = 'Sintese_Contrato__c';
    public static final String REP_TIPO_PROCESSO       = 'Tipo_de_Processo__c';
    public static final String REP_LIDER               = 'Lider__c';
    public static final String REP_MENSAGEM_ERRO       = 'Mensagem_Erro__c';
    public static final String REP_VENDA_DUPLICADA     = 'Poss_vel_Venda_Duplicada__c';

    // Valores padrão aplicados a todo novo Repasse__c (API ou manual)
    public static final String STATUS_REPASSE_FORMULARIO       = 'Formulário';
    public static final String SINTESE_FORMULARIO_MONTAGEM_REP = 'Montagem Repasse';
    public static final String STATUS_REPASSE_CONCLUIDO        = 'Concluído';

    // Valores de Sintese_Formulario__c/Sintese_Contrato__c que identificam um
    // Repasse__c com agendamento pendente ou já marcado — usados pelo endpoint
    // GET /repasse/agendamento (consumido pela Octa) para filtrar a fila.
    public static final String SINTESE_FORMULARIO_AGENDAMENTO = 'Agendamento Formulários';
    public static final String SINTESE_FORMULARIO_AGENDADO    = 'Formulário Agendado';
    public static final String SINTESE_CONTRATO_AGENDAMENTO   = 'Agendamento de contrato';
    public static final String SINTESE_CONTRATO_AGENDADO      = 'Contrato Agendado';

    // Mensagem gravada em Mensagem_Erro__c quando um novo Repasse colide (por CPF) com
    // outro Repasse__c ainda não concluído — porta do bug/regra aceita do
    // ProcessQueueCreateCardDuplicated.cs (Pipefy): qualquer colisão de CPF já basta,
    // sem exigir que todos os proponentes batam. Sem acentuação — medido para caber
    // em 255 chars (limite de Mensagem_Erro__c) junto com o link (~81 chars).
    public static final String REP_MSG_CPF_DUPLICADO =
        'Outro card {link} na fila de repasse tem os mesmos dados. Revise antes de avancar em paralelo. Depois mude a etapa p/ Formulario e Sintese p/ Montagem Repasse.';

    // ── Unidade Habitacional ──────────────────────────────────
    public static final String OBJ_UNIDADE_HAB         = 'HousingUnit__c';
    public static final String UH_TORRE                = 'Tower__c';
    public static final String UH_UNIDADE              = 'UnitNumber__c';
    public static final String UH_EMPREENDIMENTO       = 'Development__c';
    public static final String UH_INCORPORADORA        = 'Developer__c';
}