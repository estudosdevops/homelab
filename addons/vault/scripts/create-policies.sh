#!/usr/bin/env bash

set -eu

# Global Vars
export VAULT_ADDR='https://vault.homelab.tech'
export VAULT_TOKEN="hvs.S8wgFC6jnwbOq9gfD2Lh09zI"

# Create groups and policies administrators
vault write identity/group name="administrators" type="internal" \
    policies="administrators" \
    metadata=responsibility="Manage all K/V Secrets"

vault policy write administrators -<<EOF
    path "*" {
        capabilities = ["create", "read", "update", "delete", "list", "sudo"]
    }
EOF
