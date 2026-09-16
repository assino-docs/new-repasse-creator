"""CLI para consultar e atualizar objetos no Salesforce usando SalesforceClient.

Exemplos:
    python consultar.py "SELECT Id, Name FROM Empreendimento__c LIMIT 10"
    python consultar.py "SELECT Id, Name FROM Empreendimento__c" --out empreendimentos.xlsx
    python consultar.py --atualizar Empreendimento__c 001XXXXXXXXXXXXXX '{"Name": "Novo Nome"}'
"""
import argparse
import json
import sys

import pandas as pd

from salesforce_client import SalesforceClient


def consultar(cliente: SalesforceClient, soql: str, saida: str | None):
    registros = cliente.consultar_soql(soql)
    for registro in registros:
        registro.pop("attributes", None)

    if not registros:
        print("Nenhum registro encontrado.")
        return

    df = pd.DataFrame(registros)

    if saida:
        if saida.endswith(".csv"):
            df.to_csv(saida, index=False, encoding="utf-8-sig")
        else:
            df.to_excel(saida, index=False)
        print(f"{len(df)} registro(s) salvo(s) em {saida}")
    else:
        with pd.option_context("display.max_columns", None, "display.width", None):
            print(df)
        print(f"\n{len(df)} registro(s) encontrado(s)")


def atualizar(cliente: SalesforceClient, objeto: str, id_registro: str, campos_json: str):
    campos = json.loads(campos_json)
    cliente.atualizar_campos(objeto, id_registro, campos)
    print(f"{objeto} {id_registro} atualizado com sucesso: {campos}")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("soql", nargs="?", help="Query SOQL a executar")
    parser.add_argument("--out", help="Caminho de saída (.xlsx ou .csv). Sem isso, imprime no terminal.")
    parser.add_argument(
        "--atualizar",
        nargs=3,
        metavar=("OBJETO", "ID", "CAMPOS_JSON"),
        help='Atualiza um registro, ex: --atualizar Empreendimento__c 001... \'{"Name": "Novo Nome"}\'',
    )
    args = parser.parse_args()

    if not args.soql and not args.atualizar:
        parser.print_help()
        sys.exit(1)

    cliente = SalesforceClient()
    cliente.login()

    if args.atualizar:
        objeto, id_registro, campos_json = args.atualizar
        atualizar(cliente, objeto, id_registro, campos_json)
    else:
        consultar(cliente, args.soql, args.out)


if __name__ == "__main__":
    main()
