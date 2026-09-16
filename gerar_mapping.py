"""Script único, usado para gerar mapping.csv a partir da análise dos objetos
Repasse__c e Contact. Pode ser apagado depois de revisado — não faz parte do
fluxo de importação em si."""
import csv

linhas = []

def add(coluna, objeto, campo, campo_api, confianca, obs):
    linhas.append([coluna, objeto, campo, campo_api, confianca, obs])

# ── Nível Repasse__c ──────────────────────────────────────────────
add("Data Inclusão", "Repasse__c", "Data_Cria_o_de_Repasse__c", "-", "média",
    "Não é setado pela API hoje (RepasseService não usa esse campo). Teria que ser um PATCH pós-criação.")
add("Assessoria", "Repasse__c", "Empresa__c", "empresa", "média",
    "Payload exige 'empresa' (picklist). Confirmar se 'ASSINO CRÉDITO IMOBILIÁRIO' é um valor válido do picklist Empresa__c.")
add("Número", "Repasse__c", "ID_da_Incorporadora__c", "idIncorporadora", "média",
    "Campo usado para detectar duplicidade de Repasse (findRepasseExistente). Confirmar se 'Número' da planilha é de fato o identificador do processo na incorporadora.")
add("Regional", "-", "-", "-", "baixa", "Sem campo correspondente em Repasse__c.")
add("Cidade do Empreendimento", "Empreendimento__c", "(fora do escopo)", "-", "baixa",
    "Pertenceria ao cadastro de Empreendimento__c, não ao Repasse__c/Contact analisados.")
add("Empreendimento", "Repasse__c", "Empreendimento__c (lookup)", "empreendimento.nome", "alta",
    "API cria/encontra o Empreendimento pelo nome (findOrCreateEmpreendimento).")
add("Bloco", "Repasse__c", "Torre__c", "torre", "alta", "-")
add("Dt habite-se bloco", "-", "-", "-", "baixa", "Sem campo correspondente em Repasse__c.")
add("Vagas Garagem", "-", "-", "-", "baixa", "Sem campo correspondente em Repasse__c.")
add("Unidade", "Repasse__c", "Unidade_Incorporadora__c / Unidade__c", "unidade", "alta",
    "API grava o valor completo em Unidade_Incorporadora__c (texto, máx 10 caracteres) e só os dígitos em Unidade__c (numérico, cadastro Caixa/SIOPI).")

add("Grupo de Etapa", "-", "-", "-", "baixa",
    "Não há picklist genérico em Repasse__c; etapas ficam nos objetos filhos (Formularios__c/Juridico__c/Contrato__c/Registro__c), fora do escopo pedido.")
add("Etapa do Processo", "-", "-", "-", "baixa", "Mesmo caso acima.")
add("Motivo", "-", "-", "-", "baixa",
    "Repasse__c tem vários picklists de motivo específicos (Motivo_Distrato__c, Motivo_Pausado_Repasse__c etc.) mas nenhum campo genérico 'Motivo'.")

# demais colunas de processo/financeiro — nenhuma bate em Repasse__c ou Contact
_sem_campo = [
    "Dt. inclusão etapa", "Prazo da etapa", "Prazo da Etapa (Dias)", "Progresso", "Inadimplente",
    "Banco Empreend.", "Data retorno cliente", "Associativo", "Lote Associativo", "Banco",
    "Restrição cadastral?", "Utilização FGTS?", "Tipo Renda", "Data da Venda",
    "Data emissão do contrato", "Previsão Assinatura", "Data Assinatura Cliente",
    "Data Congelamento", "Data Envio Banco", "Data Pgto. VMD",
    "Valor original contrato (VGV - Valor Geral da Venda)", "Valor atualizado do contrato",
    "Saldo Devedor", "Total pago contratual", "Total pago não contratual", "Total pago contrato",
    "Percentual pro soluto", "Valor juros", "Valor multa", "Valor avaliação", "Valor terreno",
    "Valor Subsídio", "Valor FGTS", "Financiamento", "Valor Recurso Próprio",
    "Valor subsídio negociado", "Valor FGTS negociado", "Financiamento negociado",
    "Vlr. recurso próprio negociado", "Valor Total negociado", "Valor Renda Bruta",
    "Financ. creditado pelo banco", "Num. contrato ag. financ.", "Taxa banco", "Taxa VMD",
    "Valor outras taxas", "Valor CRI", "Valor ITBI", "Nº da prenotação", "Senha", "RGI",
    "Nº do protocolo", "Data do start repasse", "Data de Entrada", "Data de qualificação",
    "Data de vencimento", "Data de liberação das chaves", "Data de validade",
    "Responsáveis pela pasta", "Responsável pela última alteração", "Corretor",
    "Data histórico", "Observação",
]
for col in _sem_campo:
    add(col, "-", "-", "-", "baixa",
        "Sem campo correspondente em Repasse__c ou Contact — provavelmente vive em outro objeto (Formularios__c/Contrato__c/Juridico__c/Registro__c) ou não é suportado hoje.")

# ── Nível Proponente (Contact), repetido para os 4 slots ──────────
_campos_prop = [
    ("Proponente", "LastName", "nome", "alta",
     "RepasseService grava o nome completo inteiro em LastName (não separa First/Last)."),
    ("CPF / CNPJ Prop", "CPF__c / CNPJ__c", "cpf", "alta",
     "API só aceita 'cpf' no payload; CNPJ (proponente pessoa jurídica) não é tratado hoje pela RepasseAPI."),
    ("RG (Prop)", "RG__c", "-", "média", "Não vem no payload da API — precisaria de PATCH pós-criação."),
    ("Dt. emissão RG (Prop)", "-", "-", "baixa", "Sem campo correspondente em Contact."),
    ("Sexo (Prop)", "-", "-", "baixa",
     "Contact tem GenderIdentity (picklist), mas é um campo de identidade de gênero, não 'sexo' no sentido de documento — não recomendo usar sem confirmar com a Anna."),
    ("Nacionalidade (Prop)", "-", "-", "baixa", "Sem campo correspondente em Contact."),
    ("Local de nascimento (Prop)", "-", "-", "baixa", "Sem campo correspondente em Contact."),
    ("Dt. Nasc (Prop)", "Data_de_Nascimento__c", "-", "média",
     "Existem DOIS campos de nascimento: Birthdate (padrão) e Data_de_Nascimento__c (custom). Confirmar qual está em uso real nos processos antes de popular os dois."),
    ("Profissão (Prop)", "Profiss_o__c", "-", "média", "Não vem no payload da API — precisaria de PATCH pós-criação."),
    ("Estado Civil (Prop)", "Estado_Civil__c", "-", "média",
     "Existem DOIS campos com o mesmo label 'Estado Civil' (Estado_Civil__c e Estado__c) — parece haver um campo legado duplicado. Confirmar qual usar."),
    ("Regime Matrimônio (Prop)", "Regime__c", "-", "média", "-"),
    ("Logradouro (Prop)", "Logradouro__c", "-", "média", "-"),
    ("Cidade (Prop)", "MailingCity", "-", "baixa",
     "Não há campo custom 'Cidade'; só o padrão MailingCity/OtherCity."),
    ("Bairro (Prop)", "Bairro__c", "-", "média", "-"),
    ("CEP (Prop)", "CEP__c", "-", "média",
     "Existe também o padrão MailingPostalCode — CEP__c parece ser o campo custom em uso nos outros processos (Logradouro__c/Bairro__c também são custom)."),
    ("Nome do Pai (Prop)", "-", "-", "baixa", "Sem campo correspondente em Contact."),
    ("Nome da Mãe (Prop)", "-", "-", "baixa", "Sem campo correspondente em Contact."),
    ("E-mail (Prop)", "Email", "email", "alta", "-"),
    ("E-mail 2 (Prop)", "-", "-", "baixa", "Contact só tem um campo de e-mail."),
    ("Tel. celular (Prop)", "MobilePhone", "telefone", "alta",
     "API grava o mesmo valor de 'telefone' em MobilePhone e Phone simultaneamente (ver findOrCreateProponente)."),
    ("Tel. residencial (Prop)", "HomePhone", "-", "média", "Não vem no payload da API — precisaria de PATCH pós-criação."),
    ("Tel. comercial (Prop)", "Phone", "-", "média",
     "Cuidado: a API já usa Phone para o valor de 'telefone' (celular). Um PATCH posterior com o tel. comercial sobrescreveria isso."),
    ("Tel. recado (Prop)", "Telefone_2__c", "-", "baixa", "Melhor campo disponível, mas não é semanticamente 'recado'."),
]

for slot in (1, 2, 3, 4):
    ordinal = f"{slot}º"
    for label, campo_contact, campo_api, confianca, obs in _campos_prop:
        coluna = f"{label} ({ordinal} Prop)" if "(" not in label else label.replace("Prop", f"{ordinal} Prop")
        if label == "Proponente":
            coluna = f"{ordinal} Proponente"
        campo_api_full = f"proponente{slot}.{campo_api}" if campo_api != "-" else "-"
        add(coluna, "Contact", campo_contact, campo_api_full, confianca, obs)
    # campos-espelho que já existem também em Repasse__c (texto, não lookup)
    add(f"{ordinal} Proponente (espelho)", "Repasse__c",
        f"Nome_Proponente_{slot}__c / CPF_Proponente_{slot}__c / Cliente_{slot}__c (lookup)",
        f"proponente{slot}.nome / proponente{slot}.cpf", "alta",
        "A API grava o nome/CPF também como texto direto no Repasse__c, além do lookup para o Contact.")

with open("mapping.csv", "w", newline="", encoding="utf-8-sig") as f:
    w = csv.writer(f, delimiter=";")
    w.writerow(["coluna_planilha", "objeto_destino", "campo_destino", "campo_api_repasse", "confianca", "observacao"])
    w.writerows(linhas)

print(f"{len(linhas)} linhas gravadas em mapping.csv")
