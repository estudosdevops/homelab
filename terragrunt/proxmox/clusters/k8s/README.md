# Kubernetes Cluster with Talos on Proxmox

Esta stack provisiona uma infraestrutura Kubernetes completa usando Talos Linux no Proxmox.

## 📋 Estrutura

```
terragrunt/proxmox/clusters/k8s/
├── terragrunt.stack.hcl      # Configuração principal
├── cluster.values.hcl         # Definição de VMs
├── QUICKSTART.sh              # Script de início rápido
└── README.md                  # Este arquivo
```

## 🔧 Prerequisitos

1. **Proxmox VE** instalado e funcionando
2. **Terragrunt** instalado (`>= 0.60.0`)
3. **OpenTofu** ou **Terraform** instalado
4. **Talos ISO** uploaded no Proxmox (`local:iso/talos-v1.7.0-amd64.iso`)
5. **Token API** do Proxmox configurado

## 🚀 Quick Start

### 1. Configurar credenciais

```bash
export PROXMOX_VE_ENDPOINT="https://proxmox.homelab.tech/api2/json"
export PROXMOX_VE_API_TOKEN="terraform@pve!iac=YOUR_TOKEN"
export PROXMOX_NODE="pve-node-01"
```

### 2. Navegar para o diretório

```bash
cd terragrunt/proxmox/clusters/k8s
```

### 3. Planejar e criar

```bash
# Visualizar mudanças
terragrunt plan

# Criar infraestrutura
terragrunt apply
```

### 4. Bootstrap do cluster

```bash
# Obter IPs das VMs criadas (do output de apply)
export TALOS_ENDPOINT=<ip-controlplane-0>
export TALOS_NODES=<ip-controlplane-0>

# Aplicar configuração Talos
talosctl apply-config --insecure --nodes $TALOS_NODES \
  --file ../../talos/clusters/prod/clusterconfig/kubeprod-cp-0.yaml

# Bootstrap
talosctl bootstrap --nodes $TALOS_NODES

# Kubeconfig
talosctl kubeconfig -d ~/.kube --nodes $TALOS_NODES
```

## 🎯 O que é criado?

### Controlplanes (3x)
- **Nome:** `kubeprod-cp-0`, `kubeprod-cp-1`, `kubeprod-cp-2`
- **CPU:** 4 vCPUs
- **Memory:** 8GB
- **Disk:** 100GB SSD
- **Pool:** `k8s-controlplane`
- **Boot Order:** 10 (primeiro)
- **VLAN:** 100

### Workers (2x)
- **Nome:** `kubeprod-w-0`, `kubeprod-w-1`
- **CPU:** 8 vCPUs
- **Memory:** 16GB
- **Disk:** 100GB SSD
- **Pool:** `k8s-worker`
- **Boot Order:** 20 (depois dos CPs)
- **VLAN:** 100

## 🔄 Customizações

### Aumentar número de VMs

Editar `cluster.values.hcl`:

```hcl
# De: for i in range(3)  ← 3 controlplanes
# Para: for i in range(5)  ← 5 controlplanes
controlplanes = {
  for i in range(5) : "${local.cluster_name}-cp-${i}" => local.controlplane_base_config
}
```

### Recursos diferentes por nó

```hcl
workers = {
  for i in range(3) : "${local.cluster_name}-w-${i}" => merge(
    local.worker_base_config,
    {
      memory = 4096 * (i + 1)  # 4GB, 8GB, 12GB progressivamente
      cpu    = 2 + (i * 2)      # 2, 4, 6 vCPUs progressivamente
    }
  )
}
```

### GPU Passthrough

```hcl
gpu_workers = {
  for i in range(2) : "${local.cluster_name}-gpu-${i}" => merge(
    local.worker_base_config,
    {
      features = {
        pool = "k8s-gpu"
        tags = ["gpu"]
      }
      gpu_passthrough = {
        enabled    = true
        device_ids = ["0000:21:00.0"]  # Device ID do GPU
      }
    }
  )
}
```

### VLANs diferentes

```hcl
workers = {
  for i in range(3) : "${local.cluster_name}-w-${i}" => merge(
    local.worker_base_config,
    {
      network = {
        interfaces = [
          {
            bridge  = "vmbr0"
            vlan_id = 100 + i  # VLAN 100, 101, 102
          }
        ]
      }
    }
  )
}
```

## 📚 Arquivos Relacionados

- **Módulo:** `terraform-modules/proxmox-vm/`
- **Configuração Talos:** `talos/clusters/prod/`
- **Helm/Kubernetes:** `kubernetes/`

## 🔍 Verificar Criação

```bash
# Proxmox Web UI
# Ou via CLI:

# Listar VMs no node
pvesh get /nodes/pve-node-01/qemu

# Listar pools
pvesh get /pools

# Listar VMs no pool
pvesh get /pools/k8s-controlplane/guests
```

## 🛠️ Troubleshooting

### ISO não encontrada

```
Error: ISO file 'local:iso/talos-v1.7.0-amd64.iso' not found
```

**Solução:** Upload Talos ISO no Proxmox:
```bash
scp talos-v1.7.0-amd64.iso root@proxmox:/var/lib/vz/template/iso/
```

### Erro de autenticação

```
Error: Unauthorized (401)
```

**Solução:** Verificar token API:
```bash
echo $PROXMOX_VE_API_TOKEN
echo $PROXMOX_VE_ENDPOINT
```

### VMs não iniciam

- Verificar se template existe (se usando clone)
- Verificar disponibilidade de recursos (CPU, Memory)
- Verificar se BIOS está configurado corretamente (UEFI/Q35)

## ✅ Próximos Passos

1. ✅ Deploy infraestrutura (VMs)
2. ⏳ Bootstrap Talos
3. ⏳ Deploy Kubernetes
4. ⏳ Deploy Ingress/CNI
5. ⏳ Deploy aplicações

## 📖 Documentação

- [Terragrunt](https://terragrunt.gruntwork.io/)
- [Talos Linux](https://www.talos.dev/)
- [Kubernetes](https://kubernetes.io/)
- [Proxmox Provider](https://github.com/bpg/terraform-provider-proxmox)
