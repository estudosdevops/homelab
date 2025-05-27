#!/usr/bin/env bash
# Description: Gerencia helmfile releases

# shellcheck disable=SC1091
source "scripts/lib/common.sh"

# =============================================================================
# Configurações
# =============================================================================
readonly SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
readonly RELEASES_DIR="${PROJECT_ROOT}/addons/releases"
readonly KUBECONFIG_FILE="${PROJECT_ROOT}/kubeconfig.yaml"

# =============================================================================
# Funções de Utilidade
# =============================================================================

# Verifica dependências necessárias
check_helmfile_deps() {
    check_dependency "helmfile" "helm" "helm-diff"
}

# Verifica configurações do ambiente
check_config() {
    if [ ! -f "$KUBECONFIG_FILE" ]; then
        log_warn "Arquivo kubeconfig não encontrado: $KUBECONFIG_FILE"
        exit 1
    fi

    if [ ! -r "$KUBECONFIG_FILE" ]; then
        log_warn "Arquivo kubeconfig sem permissão de leitura: $KUBECONFIG_FILE"
        exit 1
    fi

    if [ ! -d "$RELEASES_DIR" ]; then
        log_warn "Diretório de releases não encontrado: $RELEASES_DIR"
        exit 1
    fi
}

# Mostra mensagem de ajuda
show_help() {
    echo "Uso: $0 [release] [--auto-apply]"
    echo
    echo "Argumentos:"
    echo "  release       (Opcional) Nome da release específica para instalar ou atualizar"
    echo "  --auto-apply  (Opcional) Aplica mudanças automaticamente sem pedir confirmação"
    echo
    echo "Exemplos:"
    echo "  $0              # Instalar ou Atualizar todas as releases"
    echo "  $0 argocd       # Instalar ou Atualizar uma release especifica"
    echo "  $0 --auto-apply # Instalar ou Atualizar todas releases sem pedir confirmação"
    echo "  $0 argocd --auto-apply # Instalar ou Atualizar uma release especifica sem pedir confirmaçã"
}

# =============================================================================
# Funções de Processamento
# =============================================================================

# Verifica se há mudanças na release
check_changes() {
    local release_dir=$1
    local output
    
    [[ "$release_dir" != */ ]] && release_dir="${release_dir}/"
    
    cd "$release_dir" || return 1
    
    output=$(helmfile --kubeconfig "$KUBECONFIG_FILE" --color diff 2>&1)
    local diff_status=$?
    
    echo -e "$output"
    
    cd - > /dev/null || exit 1
    
    # Verifica se há mudanças no output
    if echo "$output" | grep -q "^[+-]" || \
       echo "$output" | grep -q "helm.sh/chart:" || \
       echo "$output" | grep -q "alteração detectada:"; then
        return 0
    fi
    
    # Se não encontrou mudanças no output, verifica o status do comando
    if [ $diff_status -eq 2 ]; then
        return 0
    fi
    
    # Se chegou aqui, não há mudanças
    return 1
}

# Executa comandos helmfile
run_helmfile() {
    local release_dir=$1
    local command=$2
    local output

    [[ "$release_dir" != */ ]] && release_dir="${release_dir}/"
    
    if [ ! -d "$release_dir" ]; then
        log_error "Diretório não existe: $release_dir"
        return 1
    fi
    
    local current_dir
    current_dir=$(pwd)
    
    if ! cd "$release_dir"; then
        log_error "Erro ao mudar para o diretório $release_dir"
        return 1
    fi
    
    # Executa o comando helmfile
    if [ "$command" = "diff" ]; then
        output=$(helmfile --kubeconfig "$KUBECONFIG_FILE" --color diff --detailed-exitcode 2>&1)
    else
        output=$(helmfile --kubeconfig "$KUBECONFIG_FILE" --color "$command" 2>&1)
    fi
    local status=$?
    
    echo -e "$output"
    
    cd "$current_dir" || {
        log_error "Erro ao voltar para o diretório original"
        return 1
    }
    
    if [ $status -ne 0 ] && [ $status -ne 2 ]; then
        log_error "Erro ao executar helmfile $command (status: $status)"
        return 1
    fi
    
    return 0
}

# Solicita confirmação do usuário
confirm_action() {
    local message=$1
    local auto_apply=${2:-false}
    local response
    
    if [ "$auto_apply" = "true" ]; then
        return 0
    fi
    
    while true; do
        read -r -p "$message [N/s]: " response
        case "$response" in
            [Ss]* ) return 0;;
            [Nn]*|"" ) return 1;;
            * ) echo "Por favor, responda 's' para sim ou 'n' para não (ou Enter para não).";;
        esac
    done
}

# Processa uma release específica
process_release() {
    local release_dir=$1
    local auto_apply=${2:-false}
    local release_name
    release_name=$(basename "$release_dir")
    
    [[ "$release_dir" != */ ]] && release_dir="${release_dir}/"
    local helmfile_path="${release_dir}helmfile.yaml"
    
    log_info "Instalando ou Atualizando release: $release_name"
    
    if [ ! -f "$helmfile_path" ]; then
        log_warn "Arquivo helmfile.yaml não encontrado em: $release_dir"
        return 1
    fi
    
    if ! run_helmfile "$release_dir" "lint"; then
        log_error "Falha no lint da release $release_name"
        return 1
    fi
    
    if check_changes "$release_dir"; then
        log_info "Mudanças detectadas na release $release_name"
        
        if confirm_action "Deseja aplicar as mudanças em $release_name? (Enter ou 'n' para não, 's' para sim)" "$auto_apply"; then
            if ! run_helmfile "$release_dir" "apply"; then
                log_error "Falha no apply da release $release_name"
                return 1
            fi
            log_info "Release $release_name atualizada com sucesso"
            return 0
        else
            log_warn "Apply cancelado pelo usuário"
            return 0
        fi
    else
        log_warn "Nenhuma mudança detectada na release $release_name"
        return 0
    fi
}

# =============================================================================
# Função Principal
# =============================================================================

main() {
    # Inicialização
    check_helmfile_deps
    check_config

    # Contadores
    local total_releases=0
    local changed_releases=0
    local failed_releases=0
    local auto_apply=false
    local specific_release=""

    # Processa argumentos
    if [ $# -gt 0 ]; then
        if [ "$1" = "--auto-apply" ]; then
            auto_apply=true
        else
            specific_release="$1"
            if [ "$2" = "--auto-apply" ]; then
                auto_apply=true
            fi
        fi
    fi

    # Processa releases
    if [ -z "$specific_release" ]; then
        releases=("$RELEASES_DIR"/*/)
    else
        specific_release="$RELEASES_DIR/$specific_release"
        
        if [ ! -d "$specific_release" ]; then
            log_error "Release não encontrada: $specific_release"
            show_help
            exit 1
        fi
        
        releases=("$specific_release")
    fi

    # Processa cada release
    for release_dir in "${releases[@]}"; do
        total_releases=$((total_releases + 1))
        
        if process_release "$release_dir" "$auto_apply"; then
            changed_releases=$((changed_releases + 1))
        else
            failed_releases=$((failed_releases + 1))
        fi
    done

    if [ $failed_releases -gt 0 ]; then
        exit 1
    fi

    exit 0
}

# Executa o script
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_help
    exit 0
fi

main "$@"