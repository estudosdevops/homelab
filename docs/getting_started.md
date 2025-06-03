# Guia de Início Rápido

Este guia ajudará você a começar a usar este repositório de homelab.

## Pré-requisitos

1. Instale as ferramentas necessárias:
   ```bash
   # Para Ubuntu/Debian
   sudo apt update
   sudo apt install -y ansible git python3-pip

   # Para configurar o Ansible
   pip3 install --user ansible-lint yamllint
   ```

2. Clone este repositório:
   ```bash
   git clone <seu-repositorio>
   cd homelab
   ```

3. Torne o script homelab executável:
   ```bash
   chmod +x homelab
   ```

## CLI Homelab

O projeto inclui um CLI (Command Line Interface) para facilitar a execução dos playbooks Ansible.

### Comandos Disponíveis

1. Listar playbooks disponíveis:
   ```bash
   ./homelab list
   ```

2. Ver ajuda:
   ```bash
   ./homelab --help
   # ou
   ./homelab -h
   ```

3. Executar playbooks:
   ```bash
   # Modo check (dry-run)
   ./homelab check k3s

   # Modo create
   ./homelab create k3s

   # Com variáveis extras
   ./homelab create k3s --extra-vars 'var1=value1 var2=value2'

   # Solicitando senhas SSH e sudo
   ./homelab create k3s -k -K

   # Executando apenas tags específicas
   ./homelab create k3s --tags 'tag1,tag2'

   # Combinando múltiplas opções
   ./homelab create k3s --tags 'tag1,tag2' --extra-vars 'var1=value1' -k -K
   ```

## Configuração Inicial

1. Configure seu inventário:
   - Edite `ansible/inventories/k3s.yml`
   - Adicione seus servidores e suas configurações

2. Teste a conectividade:
   ```bash
   ansible all -m ping -i ansible/inventories/k3s.yml
   ```

3. Execute o playbook inicial usando o CLI:
   ```bash
   ./homelab check k3s
   ./homelab create k3s
   ```

## Estrutura de Diretórios

```
homelab/
├── ansible/
│   ├── inventories/
│   │   └── k3s.yml
│   ├── playbooks/
│   │   ├── setup.yml
│   │   ├── k3s.yml
│   │   └── addons.yml
│   ├── roles/
│   │   ├── setup/
│   │   ├── k3s/
│   │   └── addons/
│   └── group_vars/
│       └── all.yml
├── scripts/
│   └── helmfile-releases.sh
└── homelab
```

## Usando Tags

Os playbooks usam tags do Ansible para fornecer controle mais granular sobre quais tarefas são executadas. Cada role tem sua própria tag correspondente ao seu nome, e todas as tarefas têm a tag `all`. Veja como usá-las:

### Tags Disponíveis

- `all`: Inclui todas as tarefas
- `setup`: Tarefas para configuração inicial do sistema
- `k3s`: Tarefas para instalação do K3s
- `addons`: Tarefas para instalação de addons

### Exemplos

1. Executar apenas a role setup:
   ```bash
   ./homelab create setup --tags setup
   ```

2. Executar apenas a instalação do K3s:
   ```bash
   ./homelab create k3s --tags k3s
   ```

3. Executar apenas a instalação de addons:
   ```bash
   ./homelab create addons --tags addons
   ```

4. Executar múltiplas roles:
   ```bash
   ./homelab create k3s --tags "k3s,addons"
   ```

5. Executar todas as roles:
   ```bash
   ./homelab create k3s --tags all
   ```

## Novas Funcionalidades

### Detecção de Mudanças Aprimorada

O script `helmfile-releases.sh` agora possui uma lógica de detecção de mudanças aprimorada que captura mais casos de alterações nos releases do Helm. Isso garante que as atualizações sejam detectadas e aplicadas corretamente.

### Logging Aprimorado

O script agora fornece mensagens de status mais claras para cada release, facilitando o acompanhamento do progresso e status das instalações e atualizações.

### Execução Baseada em Roles

As tarefas agora estão organizadas em roles com tags específicas, permitindo uma execução mais direcionada das tarefas. Isso facilita:
- Executar partes específicas da configuração
- Debugar problemas em componentes particulares
- Atualizar apenas o necessário

### Dependências Python Automáticas

Os playbooks agora instalam automaticamente os pacotes Python necessários quando preciso, garantindo que todas as dependências estejam disponíveis para a execução das tarefas.

## Troubleshooting

### Problemas Comuns

1. **Pacote Python Faltando**
   - O playbook instalará automaticamente os pacotes Python necessários
   - Se você ver um aviso sobre um pacote faltando, o playbook cuidará disso

2. **Cluster Kubernetes Não Pronto**
   - O playbook inclui verificações robustas para prontidão do cluster
   - Informações de debug estão disponíveis com verbosidade aumentada: `./homelab create k3s -vv`

3. **Script Helmfile Não Encontrado**
   - Certifique-se de que o script está no local correto: `scripts/helmfile-releases.sh`
   - O script deve ser executável: `chmod +x scripts/helmfile-releases.sh`

### Debugging

Para obter uma saída mais detalhada, adicione flags de verbosidade:
```bash
./homelab create k3s -vv
```

Para ainda mais detalhes:
```bash
./homelab create k3s -vvv
```

## Boas Práticas

1. Sempre use o modo `check` antes de executar em modo `create`
2. Mantenha seus inventários atualizados
3. Documente todas as alterações significativas
4. Faça backup regularmente usando o script em `scripts/backup.sh`

## Contribuindo

1. Faça um fork do repositório
2. Crie uma branch para sua feature
3. Faça commit das suas alterações
4. Faça push para a branch
5. Abra um Pull Request

## Licença

Este projeto está licenciado sob a Licença MIT - veja o arquivo LICENSE para detalhes.
