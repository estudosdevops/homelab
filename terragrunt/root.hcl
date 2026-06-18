# Root Terragrunt configuration
# Location: terragrunt/root.hcl

generate "provider" {
  path      = "providers.tf"
  if_exists = "overwrite"

  contents = <<-EOT
    provider "proxmox" {
      endpoint  = "${get_env("PROXMOX_VE_ENDPOINT", "")}"
      api_token = "${get_env("PROXMOX_VE_API_TOKEN", "")}"
      insecure  = true

      ssh {
        agent    = false
        username = "${get_env("PROXMOX_SSH_USERNAME", "root")}"
        password = "${get_env("PROXMOX_SSH_PASSWORD", "")}"
      }
    }
  EOT
}
