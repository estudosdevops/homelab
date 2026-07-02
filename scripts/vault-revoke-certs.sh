#!/usr/bin/env bash
# Detecta certificados duplicados (mesmo CN) no Vault PKI, mantém o mais
# recente de cada grupo e revoga os demais. Termina rodando tidy.
#
# Requisitos: vault CLI autenticado, jq, openssl, bash 4+ (arrays associativos)
#
# Uso:
#   ./revoke-duplicate-certs.sh                -> modo dry-run (só mostra o plano)
#   DRY_RUN=false ./revoke-duplicate-certs.sh   -> revoga de verdade

set -euo pipefail

PKI_MOUNT="${PKI_MOUNT:-pki_int}"
DRY_RUN="${DRY_RUN:-true}"

declare -A latest_epoch
declare -A latest_serial
declare -A cn_serials

echo "Lendo certificados do mount '${PKI_MOUNT}'..."
serials=$(vault list -format=json "${PKI_MOUNT}/certs" | jq -r '.[]')

if [[ -z "${serials}" ]]; then
  echo "Nenhum certificado encontrado em ${PKI_MOUNT}/certs."
  exit 0
fi

for serial in ${serials}; do
  cert_json=$(vault read -format=json "${PKI_MOUNT}/cert/${serial}")
  revocation_time=$(echo "${cert_json}" | jq -r '.data.revocation_time // 0')

  # já revogado: ignora, o tidy cuida dele
  if [[ "${revocation_time}" != "0" ]]; then
    continue
  fi

  cert_pem=$(echo "${cert_json}" | jq -r '.data.certificate')
  cn=$(echo "${cert_pem}" | openssl x509 -noout -subject | sed -n 's/.*CN *= *//p')
  not_before=$(echo "${cert_pem}" | openssl x509 -noout -startdate | cut -d= -f2)
  epoch=$(date -d "${not_before}" +%s)

  cn_serials["${cn}"]+="${serial} "

  if [[ -z "${latest_epoch[${cn}]:-}" || "${epoch}" -gt "${latest_epoch[${cn}]}" ]]; then
    latest_epoch["${cn}"]="${epoch}"
    latest_serial["${cn}"]="${serial}"
  fi
done

echo
echo "Resumo por CN:"
to_revoke=()
for cn in "${!cn_serials[@]}"; do
  count=$(wc -w <<< "${cn_serials[${cn}]}")
  if [[ "${count}" -gt 1 ]]; then
    echo "  ${cn}: ${count} certificados válidos, mantendo o mais recente (${latest_serial[${cn}]})"
    for serial in ${cn_serials[${cn}]}; do
      if [[ "${serial}" != "${latest_serial[${cn}]}" ]]; then
        to_revoke+=("${serial}")
        echo "    -> revogar: ${serial}"
      fi
    done
  fi
done

if [[ "${#to_revoke[@]}" -eq 0 ]]; then
  echo
  echo "Nenhum duplicado encontrado. Nada a fazer."
  exit 0
fi

echo
echo "Total a revogar: ${#to_revoke[@]}"

if [[ "${DRY_RUN}" == "true" ]]; then
  echo "DRY_RUN=true — nada foi revogado. Rode com DRY_RUN=false para aplicar de verdade."
  exit 0
fi

read -rp "Confirmar revogação de ${#to_revoke[@]} certificados? (digite 'sim') " confirm
[[ "${confirm}" == "sim" ]] || { echo "Abortado."; exit 1; }

for serial in "${to_revoke[@]}"; do
  echo "Revogando: ${serial}"
  vault write "${PKI_MOUNT}/revoke" serial_number="${serial}"
done

echo "Rodando tidy para limpar o storage..."
vault write "${PKI_MOUNT}/tidy" \
  tidy_cert_store=true \
  tidy_revoked_certs=true \
  safety_buffer=1h

echo "Concluído."
