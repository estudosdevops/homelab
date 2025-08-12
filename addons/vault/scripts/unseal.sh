#!/usr/bin/env bash

set -e

kubens="vault"

vault_status=$(kubectl exec -n $kubens vault-0 -- vault status -format "json" | jq --raw-output '.sealed')
sleep 5s

if [[ $vault_status == "false" ]]; then
  echo "Vault has been successfully unlocked."
else
  echo "Initializing Vault with one key share and one key threshold."
  kubectl exec -n $kubens -it vault-0 -- vault operator init \
    -key-shares=1 \
    -key-threshold=1 \
    -format=json >cluster-keys.json

  # Unseal Vault running on the vault-0 pod.
  unseal_key=$(jq -r ".unseal_keys_b64[]" cluster-keys.json)
  kubectl exec -n $kubens -it vault-0 -- vault operator unseal "$unseal_key"

  # Verify all the Vault pods are running and ready.
  sleep 10s
  kubectl get pods -n $kubens
  echo ""

  echo "Root token found in cluster-keys.json."
  jq -r ".root_token" cluster-keys.json
fi
