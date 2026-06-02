terraform {
  required_version = ">= 1.14"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.106"
    }
  }
}
