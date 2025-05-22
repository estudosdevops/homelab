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
   ./homelab nome_playbook check

   # Modo create
   ./homelab nome_playbook create

   # Com inventário personalizado
   ./homelab nome_playbook check inventario_personalizado
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
   ./homelab setup check
   ./homelab setup create
   ```

## Estrutura de Diretórios

- `ansible/`: Contém todos os playbooks e roles do Ansible
  - `playbooks/`: Playbooks principais
  - `roles/`: Roles reutilizáveis
  - `inventories/`: Arquivos de inventário
- `scripts/`: Scripts úteis para administração
- `docker/`: Arquivos docker-compose e configurações
- `docs/`: Documentação adicional
- `monitoring/`: Configurações de monitoramento

## Boas Práticas

1. Sempre use o modo `check` antes de executar em modo `create`
2. Mantenha seus inventários atualizados
3. Documente todas as alterações significativas
4. Faça backup regularmente usando o script em `scripts/backup.sh`

## Troubleshooting

Se encontrar problemas:

1. Verifique a conectividade com os hosts
2. Confirme as permissões de usuário
3. Verifique os logs do Ansible
4. Use o modo `check` para testar alterações
5. Consulte a documentação específica em `docs/` 