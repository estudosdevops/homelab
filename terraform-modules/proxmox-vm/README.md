# terraform-proxmox-vm

Módulo Terraform/OpenTofu para provisionamento de VMs no Proxmox VE. Suporta boot via ISO ou clone de template, distribuição entre nodes do cluster, UEFI/BIOS, cloud-init e GPU passthrough.

---

## Requirements

| Name | Version |
|------|---------|
| [opentofu](https://opentofu.org) | >= 1.14 |
| [terraform](https://terraform.io) | >= 1.14 |

## Providers

| Name | Version |
|------|---------|
| [bpg/proxmox](https://registry.terraform.io/providers/bpg/proxmox/latest) | ~> 0.106 |

## Autenticação

O módulo não gerencia credenciais diretamente. Configure via variáveis de ambiente antes de executar:

```bash
export PROXMOX_VE_ENDPOINT="https://192.168.1.1:8006"
export PROXMOX_VE_API_TOKEN="terraform@pve!iac=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

> **Importante:** O token deve ser criado com **Privilege Separation desabilitado** e o usuário deve ter role com permissões de VM no path `/` com **Propagate habilitado**.

---

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `proxmox_node_name` | Node padrão onde as VMs serão criadas. Pode ser sobrescrito por VM via `node_name`. | `string` | — | ✅ |
| `vms` | Mapa de VMs a criar. A chave é o nome da VM. Ver [objeto `vms`](#objeto-vms) abaixo. | `map(object)` | — | ✅ |
| `iso_image` | Configuração de boot via ISO. Mutuamente exclusivo com `clone_from_template`. | `object` | `{ enabled = false }` | ❌ |
| `clone_from_template` | Configuração de clone a partir de template. Mutuamente exclusivo com `iso_image`. | `object` | `{ enabled = false }` | ❌ |
| `scsi_hardware` | Tipo do controlador SCSI. Ver [valores aceitos](#scsi_hardware). | `string` | `"virtio-scsi-pci"` | ❌ |

### Objeto `vms`

Cada entrada no mapa `vms` aceita os seguintes atributos:

#### Computação

| Atributo | Description | Type | Default | Required |
|----------|-------------|------|---------|:--------:|
| `node_name` | Node Proxmox para esta VM. Sobrescreve `proxmox_node_name`. | `string` | `null` | ❌ |
| `cpu` | Total de vCPUs (cores × sockets). | `number` | — | ✅ |
| `cores` | Número de cores por socket. | `number` | — | ✅ |
| `sockets` | Número de sockets de CPU. | `number` | `1` | ❌ |
| `memory` | Memória RAM em MB. | `number` | — | ✅ |

#### Disco — `disks` (lista)

| Atributo | Description | Type | Default | Required |
|----------|-------------|------|---------|:--------:|
| `size` | Tamanho do disco em GB. | `number` | — | ✅ |
| `storage` | Nome do datastore no Proxmox (ex: `local-lvm`, `rbd`). | `string` | — | ✅ |
| `ssd` | Emula disco SSD. | `bool` | `false` | ❌ |
| `cache` | Modo de cache do disco. | `string` | `"writethrough"` | ❌ |
| `discard` | Habilita TRIM/discard. | `bool` | `true` | ❌ |
| `iothread` | Habilita IOthread para melhor performance. Desabilitar para storage RBD/Ceph. | `bool` | `true` | ❌ |

#### Rede — `network.interfaces` (lista)

| Atributo | Description | Type | Default | Required |
|----------|-------------|------|---------|:--------:|
| `bridge` | Bridge de rede (ex: `vmbr0`). | `string` | — | ✅ |
| `mac` | Endereço MAC. Omitir para geração automática pelo Proxmox. | `string` | `null` | ❌ |
| `vlan_id` | ID da VLAN. | `number` | `null` | ❌ |
| `mtu` | MTU da interface. | `number` | `null` | ❌ |
| `rate` | Limite de banda em MB/s. | `number` | `null` | ❌ |

#### Boot — `boot` (opcional)

| Atributo | Description | Type | Default | Required |
|----------|-------------|------|---------|:--------:|
| `type` | Tipo de boot: `uefi` ou `bios`. | `string` | `"uefi"` | ❌ |
| `machine` | Tipo de máquina virtual: `q35` ou `i440fx`. | `string` | `"q35"` | ❌ |

#### Features — `features` (opcional)

| Atributo | Description | Type | Default | Required |
|----------|-------------|------|---------|:--------:|
| `bios` | Firmware: `ovmf` (UEFI) ou `seabios` (legado). | `string` | `"ovmf"` | ❌ |
| `cpu_type` | Modelo de CPU exposto à VM (ex: `host`, `kvm64`, `x86-64-v2-AES`). | `string` | `"host"` | ❌ |
| `hotplug_cpu` | Habilita hotplug de CPU. | `bool` | `true` | ❌ |
| `hotplug_memory` | Habilita hotplug de memória. | `bool` | `true` | ❌ |
| `startup_order` | Ordem de inicialização automática da VM. | `number` | `null` | ❌ |
| `startup_delay` | Delay em segundos após iniciar antes de passar para a próxima VM. | `number` | `null` | ❌ |
| `tags` | Lista de tags para organização no Proxmox. | `list(string)` | `[]` | ❌ |

#### Cloud-Init — `cloud_init` (opcional)

| Atributo | Description | Type | Default | Required |
|----------|-------------|------|---------|:--------:|
| `enabled` | Habilita suporte a Cloud-Init. | `bool` | — | ✅ |
| `user_data` | Conteúdo do user-data em base64. | `string` | `""` | ❌ |
| `meta_data` | Conteúdo do meta-data em base64. | `string` | `""` | ❌ |
| `network_config` | Conteúdo da network-config em base64. | `string` | `""` | ❌ |

#### GPU Passthrough — `gpu_passthrough` (opcional)

| Atributo | Description | Type | Default | Required |
|----------|-------------|------|---------|:--------:|
| `enabled` | Habilita passthrough de GPU. | `bool` | `false` | ❌ |
| `device_ids` | Lista de IDs dos dispositivos PCI a fazer passthrough. | `list(string)` | `[]` | ❌ |

### `iso_image`

| Atributo | Description | Type | Default | Required |
|----------|-------------|------|---------|:--------:|
| `enabled` | Habilita boot via ISO. | `bool` | `false` | ❌ |
| `iso_path` | Caminho do ISO no Proxmox (ex: `local:iso/talos.iso`). | `string` | `""` | ❌ |

### `clone_from_template`

| Atributo | Description | Type | Default | Required |
|----------|-------------|------|---------|:--------:|
| `enabled` | Habilita clone a partir de template. | `bool` | `false` | ❌ |
| `template_vm` | ID da VM template no Proxmox. | `string` | `""` | ❌ |

### `scsi_hardware`

Valores aceitos para o controlador SCSI:

| Valor | Caso de uso |
|-------|-------------|
| `virtio-scsi-pci` | **Padrão.** Linux moderno, Talos, performance máxima |
| `virtio-scsi-single` | Linux com suporte a IOthread por controlador |
| `lsi` | Windows, sistemas legados |
| `lsi53c810` | Sistemas legados |
| `megasas` | Compatibilidade com alguns hypervisors |
| `pvscsi` | VMware-compatible workloads |

---

## Outputs

| Name | Description |
|------|-------------|
| `vms` | Mapa com detalhes de todas as VMs criadas: `id`, `name`, `node`. |
| `vm_ids` | Mapa de nome da VM para o ID numérico no Proxmox. |
| `vm_names` | Lista com os nomes de todas as VMs criadas. |

---

## Exemplos completos

### Cluster Kubernetes com Talos Linux — 3 nodes em 3 hosts diferentes

```hcl
module "k8s_cluster" {
  source = "./terraform-modules/proxmox-vm"

  proxmox_node_name = "pve-01" # fallback — cada VM define seu node abaixo

  iso_image = {
    enabled  = true
    iso_path = "local:iso/talos-linux-metal-amd64.iso"
  }

  vms = {
    "kubeprod-cp-0" = {
      node_name = "pve-01"
      cpu       = 4
      memory    = 8192
      cores     = 2
      sockets   = 2

      disks = [{
        size     = 100
        storage  = "rbd"
        iothread = false
      }]

      network = {
        interfaces = [{
          bridge  = "vmbr0"
          vlan_id = 100
          mac     = "BC:24:11:AA:BB:01" # IP reservado via DHCP
        }]
      }

      features = {
        tags          = ["kubernetes", "controlplane", "talos"]
        startup_order = 1
      }
    }

    "kubeprod-cp-1" = {
      node_name = "pve-02"
      cpu       = 4
      memory    = 8192
      cores     = 2
      sockets   = 2

      disks = [{
        size     = 100
        storage  = "rbd"
        iothread = false
      }]

      network = {
        interfaces = [{
          bridge  = "vmbr0"
          vlan_id = 100
          mac     = "BC:24:11:AA:BB:02"
        }]
      }

      features = {
        tags          = ["kubernetes", "controlplane", "talos"]
        startup_order = 2
        startup_delay = 10
      }
    }

    "kubeprod-cp-2" = {
      node_name = "pve-03"
      cpu       = 4
      memory    = 8192
      cores     = 2
      sockets   = 2

      disks = [{
        size     = 100
        storage  = "rbd"
        iothread = false
      }]

      network = {
        interfaces = [{
          bridge  = "vmbr0"
          vlan_id = 100
          mac     = "BC:24:11:AA:BB:03"
        }]
      }

      features = {
        tags          = ["kubernetes", "controlplane", "talos"]
        startup_order = 3
        startup_delay = 20
      }
    }
  }
}
```

### Ubuntu com Cloud-Init

```hcl
module "ubuntu_vms" {
  source = "./terraform-modules/proxmox-vm"

  proxmox_node_name  = "pve-01"
  snippets_datastore = "local" # precisa ter Snippets habilitado

  clone_from_template = {
    enabled     = true
    template_vm = "9001"
  }

  vms = {
    "app-01" = {
      cpu    = 2
      memory = 4096
      cores  = 2

      disks = [{
        size    = 50
        storage = "local-lvm"
        ssd     = true
      }]

      network = {
        interfaces = [{
          bridge = "vmbr0"
          mac    = "BC:24:11:AA:CC:01"
        }]
      }

      features = {
        tags = ["ubuntu", "app"]
      }

      cloud_init = {
        enabled  = true
        username = "ubuntu"
        ip_config = {
          ipv4 = {
            address = "dhcp"
          }
        }
        # Inline — ideal para configurações simples
        user_data = <<-YAML
          #cloud-config
          manage_etc_hosts: true

          users:
            - name: ubuntu
              sudo: ALL=(ALL) NOPASSWD:ALL
              shell: /bin/bash
              ssh_authorized_keys:
                - ssh-rsa AAAA... seu@email

          packages:
            - curl
            - qemu-guest-agent

          runcmd:
            - systemctl enable qemu-guest-agent
            - systemctl start qemu-guest-agent
        YAML
        # Hostname dinâmico por instância via meta_data
        meta_data = <<-YAML
          instance-id: app-01
          local-hostname: app-01
        YAML
      }
    }
  }
}
```
---

## Notas

- **UEFI + OVMF:** quando `bios = "ovmf"`, o módulo cria automaticamente um disco EFI (`4m`) no mesmo datastore do primeiro disco da VM.
- **RBD/Ceph:** defina `iothread = false` nos discos — o Ceph não suporta IOthread.
- **QEMU Guest Agent:** habilitado por padrão em todas as VMs. O agente precisa estar rodando dentro da VM para o Terraform aguardar o boot completo antes de liberar o terminal.
- **MAC address:** omitir o campo `mac` faz o Proxmox gerar automaticamente. Defina explicitamente quando precisar de IP reservado via DHCP.
- **`cpu_type = "host"`:** expõe as instruções reais do processador físico à VM. Recomendado para Talos e workloads que precisam de performance máxima. Impede live migration entre hosts com CPUs diferentes.
