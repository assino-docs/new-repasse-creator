public class RepasseRequest {
    public ProponenteData proponente1;
    public ProponenteData proponente2;
    public ProponenteData proponente3;
    public ProponenteData proponente4;
    public FiadorData fiador1;
    public FiadorData fiador2;
    public EmpreendimentoData empreendimento;
    public ConstutoraData construtora;
    public String empresa;
    public String torre;
    /**
     * Unidade como a incorporadora a identifica, podendo ter letras e símbolos
     * (ex.: "101-A"). Vai íntegra para Unidade_Incorporadora__c (cadastro na Una
     * Incorporadora) e, só com os dígitos, para Unidade__c (cadastro na Caixa).
     */
    public String unidade;
    public String idIncorporadora;
    public String responsavelItbi;
    public String responsavelCustas;
    public String dataInput;
    public String linkDrive;
    /** Quando true, evita a movimentação automática do card para "Montagem Repasse" — usado em importações manuais de processos antigos, que serão criados e atualizados fora do fluxo padrão de venda nova. */
    public Boolean importacaoManual;
    /** Opcional. Quando informado, preenche Enquadramento_da_Unidade__c no Repasse. */
    public String enquadramento;
    /** Opcional. Quando informado, preenche PipefyId__c no Repasse. */
    public String pipefyId;

    public class ProponenteData {
        public String cpf;
        public String nome;
        public String telefone;
        public String email;
    }

    public class FiadorData {
        public String cpf;
        public String nome;
    }

    public class EmpreendimentoData {
        public String nome;
    }

    public class ConstutoraData {
        public String nome;
    }

    /** Retorna proponentes não-nulos (com CPF) na ordem do payload. */
    public List<ProponenteData> proponentes() {
        List<ProponenteData> result = new List<ProponenteData>();
        if (proponente1 != null && String.isNotBlank(proponente1.cpf)) result.add(proponente1);
        if (proponente2 != null && String.isNotBlank(proponente2.cpf)) result.add(proponente2);
        if (proponente3 != null && String.isNotBlank(proponente3.cpf)) result.add(proponente3);
        if (proponente4 != null && String.isNotBlank(proponente4.cpf)) result.add(proponente4);
        return result;
    }

    public void validate() {
        if (proponente1 == null || String.isBlank(proponente1.cpf)) {
            throw new ApiException(400, 'proponente1.cpf é obrigatório');
        }
        if (String.isBlank(proponente1.nome)) {
            throw new ApiException(400, 'proponente1.nome é obrigatório');
        }
        if (empreendimento == null || String.isBlank(empreendimento.nome)) {
            throw new ApiException(400, 'empreendimento.nome é obrigatório');
        }
        if (construtora == null || String.isBlank(construtora.nome)) {
            throw new ApiException(400, 'construtora.nome é obrigatório');
        }
        if (String.isBlank(empresa)) {
            throw new ApiException(400, 'empresa é obrigatório');
        }
        if (String.isBlank(idIncorporadora)) {
            throw new ApiException(400, 'idIncorporadora é obrigatório');
        }
        // Unidade_Incorporadora__c é Text(10): falha aqui com mensagem clara em
        // vez de estourar STRING_TOO_LONG no insert do Repasse.
        if (String.isNotBlank(unidade) && unidade.trim().length() > 10) {
            throw new ApiException(400, 'unidade excede o limite de 10 caracteres');
        }
        dataInputAsDate();
    }

    /** Converte dataInput (yyyy-MM-dd, tolera prefixo de datetime) para Date. Campo opcional. */
    public Date dataInputAsDate() {
        if (String.isBlank(dataInput)) return null;
        String raw = dataInput.trim();
        try {
            return Date.valueOf(raw.length() >= 10 ? raw.substring(0, 10) : raw);
        } catch (Exception e) {
            throw new ApiException(400, 'dataInput inválido: use o formato yyyy-MM-dd');
        }
    }
}