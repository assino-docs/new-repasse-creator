"""Cliente HTTP para o Salesforce: login, cadastro de venda, consulta e atualização."""
import json
import os
import re
import threading

import requests

import config

_LOOKUP_CACHE_PATH = "data/child_lookup_fields.json"


class SalesforceClient:
    def __init__(self):
        self.access_token: str | None = None
        self.instance_url: str | None = None
        self._lookup_field_cache: dict[str, str] = self._carregar_lookup_cache()
        self._nome_id_cache: dict[str, dict[str, str | None]] = {}
        # Protege os dois caches acima e o arquivo de lookup — com vários
        # cards em paralelo (ver CONCORRENCIA em salesforce_sync.py), threads
        # diferentes podem descobrir/gravar no cache ao mesmo tempo.
        self._cache_lock = threading.Lock()

    # ------------------------------------------------------------------
    # Autenticação
    # ------------------------------------------------------------------
    def login(self):
        url = f"{config.SF_LOGIN_URL}/services/oauth2/token"
        payload = {
            "grant_type": "client_credentials",
            "client_id": config.SF_CLIENT_ID,
            "client_secret": config.SF_CLIENT_SECRET,
        }
        resp = requests.post(
            url,
            data=payload,
            headers={"Content-Type": "application/x-www-form-urlencoded"},
            timeout=60,
        )
        if resp.status_code >= 400:
            raise RuntimeError(f"Falha no login Salesforce: HTTP {resp.status_code} - {resp.text}")
        data = resp.json()
        self.access_token = data["access_token"]
        self.instance_url = data.get("instance_url", config.SF_LOGIN_URL)

    def _headers(self) -> dict:
        return {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {self.access_token}",
        }

    # ------------------------------------------------------------------
    # Cadastro de venda (endpoint Apex REST customizado)
    # ------------------------------------------------------------------
    def criar_venda(self, payload: dict) -> dict:
        url = f"{self.instance_url}/services/apexrest/repasse"
        resp = requests.post(url, json=payload, headers=self._headers(), timeout=60)
        try:
            data = resp.json()
        except ValueError:
            resp.raise_for_status()
            raise RuntimeError("Resposta inesperada (não-JSON) do endpoint de cadastro de venda")
        if resp.status_code >= 400 or data.get("success") is False:
            raise RuntimeError(f"HTTP {resp.status_code} - {data}")
        return data

    # ------------------------------------------------------------------
    # Consulta e atualização de objetos (Repasse__c e filhos)
    # ------------------------------------------------------------------
    def consultar_filho(self, objeto: str, id_repasse: str) -> str | None:
        campo_lookup = self._lookup_field_cache.get(objeto, "Repasse__c")
        soql = f"SELECT Id FROM {objeto} WHERE {campo_lookup} = '{id_repasse}'"
        url = f"{self.instance_url}/services/data/{config.SF_API_VERSION}/query"
        resp = requests.get(url, params={"q": soql}, headers=self._headers(), timeout=60)

        if resp.status_code == 400:
            erros = resp.json()
            if isinstance(erros, list) and any(e.get("errorCode") == "INVALID_FIELD" for e in erros):
                campo_lookup = self._descobrir_campo_lookup(objeto)
                with self._cache_lock:
                    self._lookup_field_cache[objeto] = campo_lookup
                    self._salvar_lookup_cache()
                soql = f"SELECT Id FROM {objeto} WHERE {campo_lookup} = '{id_repasse}'"
                resp = requests.get(url, params={"q": soql}, headers=self._headers(), timeout=60)

        resp.raise_for_status()
        data = resp.json()
        registros = data.get("records", [])
        return registros[0]["Id"] if registros else None

    def consultar_soql(self, soql: str) -> list[dict]:
        """SOQL arbitrária, paginando todos os resultados (nextRecordsUrl).
        Usado quando o filtro não é um simples lookup por Repasse__c (ver
        consultar_filho) — ex. Item_de_Fila__c filtrado por Atividades_Sistemas__c."""
        url = f"{self.instance_url}/services/data/{config.SF_API_VERSION}/query"
        resp = requests.get(url, params={"q": soql}, headers=self._headers(), timeout=60)
        resp.raise_for_status()
        data = resp.json()
        registros = list(data.get("records", []))
        while not data.get("done", True):
            resp = requests.get(f"{self.instance_url}{data['nextRecordsUrl']}", headers=self._headers(), timeout=60)
            resp.raise_for_status()
            data = resp.json()
            registros.extend(data.get("records", []))
        return registros

    def resolver_id_por_nome(self, objeto: str, nome: str) -> str | None:
        """Resolve o Id de um registro pelo campo Name, comparação
        case-insensitive (padrão do SOQL para texto). Usado para lookups
        (Empreendimento__c, Account/Construtora, SIOPI__c) que passam o nome
        em vez de um Id fixo, já que o Id muda entre ambientes (QA/produção)."""
        chave = nome.strip()
        with self._cache_lock:
            cache = self._nome_id_cache.setdefault(objeto, {})
            if chave in cache:
                return cache[chave]

        nome_escapado = chave.replace("\\", "\\\\").replace("'", "\\'")
        soql = f"SELECT Id FROM {objeto} WHERE Name = '{nome_escapado}'"
        url = f"{self.instance_url}/services/data/{config.SF_API_VERSION}/query"
        resp = requests.get(url, params={"q": soql}, headers=self._headers(), timeout=60)
        if resp.status_code == 400:
            # Objeto inacessível pra esse usuário (ex.: Account/Contact com
            # licença "Salesforce Integration", que nunca permite CRM padrão —
            # ver conversa com Anna, 2026-09-02). Trata como "não encontrado"
            # em vez de derrubar o PATCH inteiro do objeto que chamou aqui
            # (ver resolver_nomes_para_id): só esse campo de lookup fica de
            # fora, registrado em pendencias_nome pelo chamador.
            print(f"  [aviso] resolver_id_por_nome({objeto}, '{chave}'): HTTP 400 - {resp.text}")
            with self._cache_lock:
                cache[chave] = None
            return None
        resp.raise_for_status()
        registros = resp.json().get("records", [])
        resultado = registros[0]["Id"] if registros else None
        with self._cache_lock:
            cache[chave] = resultado
        return resultado

    def _descobrir_campo_lookup(self, objeto: str) -> str:
        url = f"{self.instance_url}/services/data/{config.SF_API_VERSION}/sobjects/{objeto}/describe"
        resp = requests.get(url, headers=self._headers(), timeout=60)
        resp.raise_for_status()
        data = resp.json()
        for campo in data.get("fields", []):
            if campo.get("type") == "reference" and config.OBJETO_PAI in (campo.get("referenceTo") or []):
                return campo["name"]
        raise RuntimeError(f"Não encontrei campo de lookup para {config.OBJETO_PAI} em {objeto}")

    def atualizar_campos(self, objeto: str, id_registro: str, campos: dict, campos_removidos: list | None = None):
        """PATCH em `campos`. Um campo que existe no mapping.csv mas não no
        ambiente de destino (ex.: diferença de schema entre QA e produção —
        ver conversa com Anna, 2026-09-02) derruba o PATCH inteiro com
        INVALID_FIELD; em vez de falhar o objeto todo por causa de 1 campo,
        remove só o campo acusado e tenta de novo. `campos_removidos`, se
        passado, recebe os nomes removidos (pra registrar como pendência)."""
        url = f"{self.instance_url}/services/data/{config.SF_API_VERSION}/sobjects/{objeto}/{id_registro}"
        while True:
            resp = requests.patch(url, json=campos, headers=self._headers(), timeout=60)
            if resp.status_code < 300:
                return
            if resp.status_code == 400 and campos:
                try:
                    erros = resp.json()
                except ValueError:
                    erros = None
                if isinstance(erros, list):
                    campo_invalido = None
                    for e in erros:
                        if e.get("errorCode") != "INVALID_FIELD":
                            continue
                        msg = e.get("message", "")
                        m = re.search(r"No such column '(\w+)'", msg)
                        if m and m.group(1) in campos:
                            campo_invalido = m.group(1)
                            break
                    if campo_invalido:
                        print(f"  [aviso] {objeto}.{campo_invalido} não existe neste ambiente — campo ignorado")
                        del campos[campo_invalido]
                        if campos_removidos is not None:
                            campos_removidos.append(campo_invalido)
                        if campos:
                            continue
                        return
            raise RuntimeError(f"HTTP {resp.status_code} - {resp.text}")

    def excluir(self, objeto: str, id_registro: str):
        url = f"{self.instance_url}/services/data/{config.SF_API_VERSION}/sobjects/{objeto}/{id_registro}"
        resp = requests.delete(url, headers=self._headers(), timeout=60)
        if resp.status_code >= 300:
            raise RuntimeError(f"HTTP {resp.status_code} - {resp.text}")

    # ------------------------------------------------------------------
    # Cache do nome do campo de lookup de cada filho para o Repasse__c pai
    # ------------------------------------------------------------------
    def _carregar_lookup_cache(self) -> dict[str, str]:
        if not os.path.exists(_LOOKUP_CACHE_PATH):
            return {}
        with open(_LOOKUP_CACHE_PATH, encoding="utf-8") as f:
            return json.load(f)

    def _salvar_lookup_cache(self):
        os.makedirs(os.path.dirname(_LOOKUP_CACHE_PATH), exist_ok=True)
        with open(_LOOKUP_CACHE_PATH, "w", encoding="utf-8") as f:
            json.dump(self._lookup_field_cache, f, indent=2, ensure_ascii=False)
