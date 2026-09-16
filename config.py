"""Configurações do projeto, carregadas do arquivo .env."""
import os

from dotenv import load_dotenv

load_dotenv()

SF_LOGIN_URL = os.environ["SF_LOGIN_URL"].rstrip("/")
SF_CLIENT_ID = os.environ["SF_CLIENT_ID"]
SF_CLIENT_SECRET = os.environ["SF_CLIENT_SECRET"]
SF_API_VERSION = os.environ["SF_API_VERSION"]

# Objeto pai usado por SalesforceClient para descobrir o campo de lookup
# correto em objetos filhos (ver _descobrir_campo_lookup em salesforce_client.py).
OBJETO_PAI = "Repasse__c"
