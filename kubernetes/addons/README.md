# Kubernetes Addons GitOps

Este documento descreve como os addons do Kubernetes são gerenciados através de GitOps utilizando ArgoCD, ApplicationSet e Renovate.

## Visão Geral

O repositório é a única fonte de verdade (Source of Truth) para toda a configuração do cluster. Nenhuma alteração deve ser aplicada manualmente diretamente no Kubernetes. Todo o ciclo de vida dos addons ocorre através de Pull Requests e sincronização automática realizada pelo ArgoCD.

### Estrutura dos Addons

```text
kubernetes/
└── addons/
    ├── cert-manager/
    │   ├── Chart.yaml
    │   ├── config.yaml
    │   ├── values/
    │   │   ├── common.yaml
    │   │   ├── dev.yaml
    │   │   ├── stg.yaml
    │   │   └── prod.yaml
    │   └── appset.yaml (gerado)
```

### ApplicationSet

Cada addon possui um ApplicationSet gerado automaticamente por script Python.

```bash
# Geração do appset
task addon:plan addon=cert-manager

# Aplicação no cluster
task addon:apply addon=cert-manager
```

Benefícios:

* Evita duplicação de manifests.
* Escala facilmente para novos clusters.
* Mantém padronização entre addons.
* Reduz manutenção operacional.


<details>
  <summary>Fluxo GitOps</summary>

```mermaid
flowchart TD

    DevPlan["👨‍💻 task addon:plan addon=<addon>"] --> Py["🐍 Python Generator
    (dry-run + render)"]
    Py --> AppSet["📄 appset.yaml gerado"]

    AppSet --> Kubectl["👨‍💻 task addon:apply addon=<addon>
    (bootstrap ApplicationSet)"]
    Kubectl --> ArgoBootstrap["🚀 Argo CD Bootstrap (Controller ativo)"]

    %% Git fica abaixo do AppSet gerado (como você pediu)
    AppSet --> Git[("📂 Git Repository")]
    DevCommit["👨‍💻 Commit / Push"] --> Git

    Git --> Argo["🚀 Argo CD Controller"]
    ArgoBootstrap --> Argo

    Argo --> Controller["ApplicationSet Controller"]
    Controller --> Apps["Argo CD Applications"]

    Apps --> Diff{"Cluster está sincronizado?"}

    Diff -->|"✅ Sim"| Idle["Sem ação"]
    Diff -->|"❌ Não"| Sync["Argo CD Sync"]

    Sync --> K8S["☸️ Kubernetes"]
    K8S --> Diff

    Drift["⚠️ Drift manual no cluster"] -.-> Diff


    %% ===== STYLES (cores) =====
    classDef git fill:#6e40c9,stroke:#4a2d8c,color:#fff;
    classDef argo fill:#f04e23,stroke:#c63c16,color:#fff;
    classDef k8s fill:#326ce5,stroke:#1e4db3,color:#fff;
    classDef user fill:#2ea44f,stroke:#1a7036,color:#fff;
    classDef gen fill:#9C27B0,stroke:#6A1B9A,color:#fff;
    classDef warn fill:#FFE082,stroke:#F57C00,color:#000;

    class DevPlan,DevCommit,Kubectl user;
    class Py,AppSet gen;
    class Git git;
    class Argo,Controller,Apps,Sync,ArgoBootstrap argo;
    class K8S k8s;
    class Drift warn;
```
</details>

---

### Atualização de Versões

As versões dos charts Helm são monitoradas automaticamente pelo Renovate, quando uma nova versão é disponibilizada:

1. Renovate identifica a atualização.
2. Renovate cria um Pull Request.
3. Os manifests são validados.
4. O Pull Request é revisado.
5. O merge é realizado.
6. Argo CD sincroniza automaticamente.

<details>
  <summary>Fluxo Renovate → Argo CD</summary>

```mermaid
flowchart TD
    Helm["📦 Novo Release Helm"] --> Renovate["🤖 Renovate"]

    Renovate --> PR["Pull Request"]

    PR --> Validate["🔍 Validações"]

    Validate --> Decision{"Aprovado?"}

    Decision -->|"❌ Não"| Fix["Correções"]

    Fix --> PR

    Decision -->|"✅ Sim"| Merge["Merge"]

    Merge --> Git[("📂 Git Repository")]

    Git --> Argo["🚀 Argo CD"]

    Argo --> Cluster["☸️ Kubernetes"]

    classDef renovate fill:#4CAF50,stroke:#2E7D32,color:#fff
    classDef pr fill:#FF9800,stroke:#E65100,color:#fff
    classDef argo fill:#f04e23,stroke:#c63c16,color:#fff
    classDef k8s fill:#326ce5,stroke:#1e4db3,color:#fff
    classDef git fill:#6e40c9,stroke:#4a2d8c,color:#fff

    class Renovate renovate
    class PR,Validate,Decision,Fix,Merge pr
    class Argo argo
    class Cluster k8s
    class Git git
```
</details>

### Validações

Antes de qualquer alteração ser aplicada ao cluster, os manifests passam por validações automáticas.

Validações:

* Helm template
* Kubeconform (schema validation)
* Kubepug (API deprecation checks)
* ArgoCD Diff Preview

Objetivos:

* Validar manifests Kubernetes
* Detectar APIs depreciadas
* Detectar APIs removidas na versão alvo do cluster
* Visualizar mudanças antes do merge

### Benefícios da Arquitetura

* Git como fonte única de verdade.
* Deploys reproduzíveis.
* Recuperação automática de drift.
* Atualizações controladas via Pull Request.
* Padronização entre clusters.
* Menor esforço operacional.
* Facilidade para auditoria e troubleshooting.
