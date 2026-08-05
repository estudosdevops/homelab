#!/usr/bin/env python3
import os, sys, socket, ssl, requests
from datetime import datetime, timezone
from cryptography import x509
from cryptography.hazmat.backends import default_backend

# --- Configurações via Variáveis de Ambiente ---
VAULT_ADDR = os.getenv("VAULT_ADDR")
VAULT_TOKEN = os.getenv("VAULT_TOKEN")
PKI_MOUNT = os.getenv("PKI_MOUNT", "pki_int")
PKI_ROLE = os.getenv("PKI_ROLE", "homelab-dot-tech")
PKI_TTL = os.getenv("PKI_TTL", "2160h")

NPM_ADDR = os.getenv("NPM_ADDR")
NPM_IDENTITY = os.getenv("NPM_IDENTITY")
NPM_SECRET = os.getenv("NPM_SECRET")

RENEW_DAYS = int(os.getenv("RENEW_DAYS_BEFORE", "14"))


def req(method, url, headers=None, **kwargs):
    """Auxiliar HTTP centralizado (DRY) com tratamento de erros."""
    r = requests.request(method, url, headers=headers, timeout=10, **kwargs)
    if not r.ok:
        err_msg = r.json().get("error", {}).get("message") if "json" in r.headers.get("content-type", "") else r.text
        raise RuntimeError(f"HTTP {r.status_code}: {err_msg or r.text[:80]}")
    return r.json() if "application/json" in r.headers.get("Content-Type", "") else r


def check_env():
    required = ["VAULT_ADDR", "VAULT_TOKEN", "NPM_ADDR", "NPM_IDENTITY", "NPM_SECRET"]
    if missing := [v for v in required if not os.getenv(v)]:
        sys.exit(f"ERRO: Variaveis ausentes: {', '.join(missing)}")


def get_npm_certificates(headers):
    certs = req("GET", f"{NPM_ADDR.rstrip('/')}/api/nginx/certificates", headers=headers)
    mapping = {}
    for c in certs:
        cid = c["id"]
        domains = c.get("domain_names", []) + (c.get("nice_name") or c.get("name") or "").split()
        for d in domains:
            if "." in d:
                mapping[d.lower().strip()] = cid
    return mapping


def check_tls_expiration(domain, port=443):
    try:
        ctx = ssl.create_default_context()
        ctx.check_hostname, ctx.verify_mode = False, ssl.CERT_NONE
        with socket.create_connection((domain, port), timeout=5) as s, ctx.wrap_socket(s, server_hostname=domain) as ss:
            cert = x509.load_der_x509_certificate(ss.getpeercert(True), default_backend())
            exp = getattr(cert, "not_valid_after_utc", cert.not_valid_after.replace(tzinfo=timezone.utc))
            return (exp - datetime.now(timezone.utc)).days
    except Exception:
        return None


def issue_vault_fullchain(domain):
    url = f"{VAULT_ADDR.rstrip('/')}/v1/{PKI_MOUNT}/issue/{PKI_ROLE}"
    res = req("POST", url, headers={"X-Vault-Token": VAULT_TOKEN}, json={"common_name": domain, "ttl": PKI_TTL})["data"]
    certs = [res.get("certificate", "").strip()]
    if ca := res.get("issuing_ca", "").strip():
        certs.append(ca)
    elif chain := res.get("ca_chain", []):
        certs.extend(c.strip() for c in chain if c.strip())
    return "\n".join(certs) + "\n", res.get("private_key", "").strip() + "\n"


def upload_or_create_npm_cert(headers, domain, cert_id, full_chain, key):
    files = {
        "certificate": ("certificate.pem", full_chain.encode(), "text/plain"),
        "certificate_key": ("certificate_key.pem", key.encode(), "text/plain"),
    }
    if cert_id:
        req("POST", f"{NPM_ADDR.rstrip('/')}/api/nginx/certificates/{cert_id}/upload", headers=headers, files=files)
        return cert_id, "Cert. Atualizado"
    res = req("POST", f"{NPM_ADDR.rstrip('/')}/api/nginx/certificates", headers=headers, data={"provider": "other", "nice_name": domain}, files=files)
    return res["id"], "Cert. Criado"


def bind_cert_to_proxy_host(headers, domain, cert_id):
    hosts = req("GET", f"{NPM_ADDR.rstrip('/')}/api/nginx/proxy-hosts", headers=headers)
    host = next((h for h in hosts if domain.lower() in [d.lower() for d in h.get("domain_names", [])]), None)
    if not host:
        return "Sem Proxy Host"

    if host.get("certificate_id") == cert_id and host.get("ssl_forced"):
        return "Proxy OK"

    payload = {
        **{k: host[k] for k in ["domain_names", "forward_scheme", "forward_host", "forward_port",
                                "hsts_enabled", "hsts_subdomains", "http2_support", "block_exploits",
                                "caching_enabled", "allow_websocket_upgrade", "access_list_id",
                                "advanced_config", "meta"] if k in host},
        "certificate_id": cert_id,
        "ssl_forced": True
    }
    req("PUT", f"{NPM_ADDR.rstrip('/')}/api/nginx/proxy-hosts/{host['id']}", headers=headers, json=payload)
    return "Proxy Vinculado"


def print_table(rows):
    """Imprime a tabela com bordas estilo Box Grid (estilo imagem)."""
    widths = [30, 8, 12, 12, 35]
    headers = ["DOMINIO", "ID NPM", "EXPIRA EM", "STATUS", "RESULTADO DA OPERACAO"]

    top    = "┌" + "┬".join("─" * (w + 2) for w in widths) + "┐"
    header = "│ " + " │ ".join(f"{h:<{w}}" for h, w in zip(headers, widths)) + " │"
    middle = "├" + "┼".join("─" * (w + 2) for w in widths) + "┤"
    bottom = "└" + "┴".join("─" * (w + 2) for w in widths) + "┘"

    print("\n" + top)
    print(header)
    print(middle)
    for row in rows:
        print("│ " + " │ ".join(f"{str(val):<{w}}" for val, w in zip(row, widths)) + " │")
    print(bottom + "\n")


def main():
    check_env()
    check_only = "--check" in sys.argv
    args = [a for a in sys.argv[1:] if a != "--check"]

    token = req("POST", f"{NPM_ADDR.rstrip('/')}/api/tokens", json={"identity": NPM_IDENTITY, "secret": NPM_SECRET})["token"]
    headers = {"Authorization": f"Bearer {token}"}
    npm_map = get_npm_certificates(headers)

    domains = args if args else list(npm_map.keys())
    if not domains:
        sys.exit("Nenhum dominio informado ou encontrado no NPM.")

    table_data = []

    for domain in domains:
        key = domain.lower().strip()
        cert_id = npm_map.get(key)
        days = check_tls_expiration(domain) if cert_id else None

        if not cert_id:
            status = "NOVO"
            expire_str = "Novo"
        elif days is None or days < 0:
            status = "EXPIRADO"
            expire_str = f"{days} dias" if days is not None else "Inacessivel"
        elif days <= RENEW_DAYS:
            status = "EXPIRANDO"
            expire_str = f"{days} dias"
        else:
            status = "OK"
            expire_str = f"{days} dias"

        id_str = str(cert_id) if cert_id else "Novo"

        if status == "OK" or check_only:
            result = "Modo Check (--check)" if check_only and status != "OK" else "Validade OK (Sem Acao)"
            table_data.append([domain, id_str, expire_str, status, result])
            continue

        try:
            full_chain, key_pem = issue_vault_fullchain(domain)
            final_id, cert_act = upload_or_create_npm_cert(headers, domain, cert_id, full_chain, key_pem)
            proxy_act = bind_cert_to_proxy_host(headers, domain, final_id)
            result = f"{cert_act} | {proxy_act}"
            table_data.append([domain, str(final_id), expire_str, status, result])
        except Exception as e:
            table_data.append([domain, id_str, expire_str, status, f"ERRO: {str(e)[:28]}"])

    print_table(table_data)


if __name__ == "__main__":
    main()
