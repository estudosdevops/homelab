generate "provider" {
  path      = "providers.tf"
  if_exists = "overwrite"

  contents = <<-EOT
    provider "proxmox" {
      endpoint  = "${get_env("PROXMOX_VE_ENDPOINT", "https://192.168.1.1:8006")}"
      api_token = "${get_env("PROXMOX_VE_API_TOKEN", "")}"
      insecure  = true
    }
  EOT
}
