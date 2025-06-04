# Homelab K3s

Este repositório contém a infraestrutura como código (IaC) e configurações para um homelab baseado em K3s, uma distribuição Kubernetes leve e otimizada para ambientes edge computing e IoT.

## Sobre o K3s

K3s é uma distribuição Kubernetes certificada pela CNCF, projetada para ser:
- Leve e eficiente
- Fácil de instalar e manter
- Ideal para ambientes com recursos limitados
- Perfeito para homelabs e ambientes de desenvolvimento

## Hardware

### Control Plane (Master)
- **Modelo**: Dell OptiPlex 3070
- **CPU**: Intel Core i5
- **Memória**: 16GB RAM
- **Armazenamento**: SSD 120GB
- **Sistema Operacional**: Ubuntu Server 22.04 LTS

### Worker Node
- **Modelo**: Lenovo Mini PC
- **CPU**: Intel Core i5
- **Memória**: 16GB RAM
- **Armazenamento**: SSD 256GB
- **Sistema Operacional**: Ubuntu Server 22.04 LTS

## Estrutura do Projeto

```
.
├── ansible/            # Playbooks e roles do Ansible
│   ├── inventories/   # Inventários para diferentes ambientes
│   ├── roles/        # Roles reutilizáveis
│   └── playbooks/    # Playbooks principais
├── scripts/           # Scripts úteis (bash, python, etc)
├── terraform/         # Códigos Terraform (se necessário)
├── docker/           # Compose files e configurações Docker
├── docs/             # Documentação
└── monitoring/       # Configurações de monitoramento
```

## Ferramentas Utilizadas

Este homelab utiliza um cluster K3s com as seguintes ferramentas:

| Ferramenta | Descrição | Link |
|------------|-----------|------|
| ArgoCD | Ferramenta de GitOps para Kubernetes que automatiza o deploy de aplicações | [ArgoCD](https://argoproj.github.io/cd/) |
| Pi-hole | Bloqueador de anúncios e DNS sinkhole que funciona como um servidor DNS | [Pi-hole](https://pi-hole.net/) |
| Cilium | CNI (Container Network Interface) que fornece rede, segurança e observabilidade | [Cilium](https://cilium.io/) |
| NGINX Ingress Controller | Controlador de ingress para gerenciar o tráfego HTTP/HTTPS | [NGINX Ingress](https://kubernetes.github.io/ingress-nginx/) |
| MetalLB | Balanceador de carga para clusters Kubernetes bare metal | [MetalLB](https://metallb.universe.tf/) |

### Stack de Monitoramento

| Ferramenta | Descrição | Link |
|------------|-----------|------|
| Prometheus | Sistema de monitoramento e alerta | [Prometheus](https://prometheus.io/) |
| Grafana | Plataforma de visualização e análise | [Grafana](https://grafana.com/) |
| AlertManager | Gerenciamento de alertas do Prometheus | [AlertManager](https://prometheus.io/docs/alerting/latest/alertmanager/) |

### Stack de Logging

| Ferramenta | Descrição | Link |
|------------|-----------|------|
| Loki | Sistema de agregação de logs | [Loki](https://grafana.com/oss/loki/) |
| Promtail | Coletor de logs para Loki | [Promtail](https://grafana.com/docs/loki/latest/clients/promtail/) |

## Uso Básico

```bash
# Listar todos os playbooks disponíveis
./homelab list

# Executar um playbook em modo check (dry-run)
./homelab check k3s

# Executar um playbook em modo apply
./homelab apply k3s

# Executar um playbook com variáveis extras
./homelab apply k3s --extra-vars 'var1=value1 var2=value2'

# Executar um playbook solicitando senhas SSH e sudo
./homelab apply k3s -k -K

# Executar um playbook apenas com tags específicas
./homelab apply k3s --tags 'tag1,tag2'
```

## Documentação

Para informações detalhadas sobre:
- Instalação e configuração
- Uso de tags e roles
- Troubleshooting
- Novas funcionalidades
- Estrutura detalhada do projeto

Consulte o [Guia de Início Rápido](docs/getting_started.md).

## Contribuindo

1. Faça um fork do repositório
2. Crie uma branch para sua feature
3. Faça commit das suas alterações
4. Faça push para a branch
5. Abra um Pull Request

## Licença

Este projeto está licenciado sob a Licença MIT - veja o arquivo LICENSE para detalhes.
