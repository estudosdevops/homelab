# Terragrunt Configuration for Kubernetes Cluster
# Location: terragrunt/proxmox/clusters/k8s/terragrunt.hcl

terraform {
  source = "${get_repo_root()}/terraform-modules/proxmox-vm"
}

include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  cluster        = get_env("CLUSTER", "prod")
  cluster_config = read_terragrunt_config("${get_terragrunt_dir()}/${local.cluster}.values.hcl")
}

inputs = {
  proxmox_node_name   = local.cluster_config.locals.default_node
  vms                 = local.cluster_config.locals.all_vms
  iso_image           = local.cluster_config.locals.iso_config
  clone_from_template = { enabled = false }
}
