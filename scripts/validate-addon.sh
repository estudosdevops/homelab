#!/bin/bash

# scripts/validate-addon.sh
# Script for external addon validation

set -euo pipefail

# Configuration
ADDONS_DIR="addons"

usage() {
    cat << EOF
🔧 VALIDADOR DE ADDONS HOMELAB

Uso: $0 [OPÇÕES] NOME_DO_ADDON

DESCRIÇÃO:
    Valida configuração e estrutura de addons

OPÇÕES:
    -h, --help      Mostra esta mensagem de ajuda
    -v, --verbose   Habilita saída detalhada
    -q, --quiet     Habilita modo silencioso
    --dry-run       Valida sem fazer alterações

EXEMPLOS:
    $0 vault                    # Valida addon vault
    $0 --verbose cert-manager   # Valida com saída detalhada
    $0 --dry-run nginx-test     # Execução de teste (dry run)

EOF
}

# Default options
VERBOSE=false
QUIET=false
DRY_RUN=false
ADDON_NAME=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -q|--quiet)
            QUIET=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -*)
            error_exit "Opção desconhecida: $1"
            ;;
        *)
            if [[ -z "$ADDON_NAME" ]]; then
                ADDON_NAME="$1"
            else
                error_exit "Múltiplos nomes de addon fornecidos. Apenas um é permitido."
            fi
            shift
            ;;
    esac
done

# Validate inputs
if [[ -z "$ADDON_NAME" ]]; then
    error_exit "❌ Nome do addon é obrigatório"
fi

if [[ "$VERBOSE" == true && "$QUIET" == true ]]; then
    error_exit "❌ Não é possível usar as opções --verbose e --quiet simultaneamente"
fi

# Logging functions
log_info() {
    if [[ "$QUIET" != true ]]; then
        echo "ℹ️  $*"
    fi
}

log_verbose() {
    if [[ "$VERBOSE" == true ]]; then
        echo "🔍 $*"
    fi
}

log_success() {
    if [[ "$QUIET" != true ]]; then
        echo "✅ $*"
    fi
}

log_warning() {
    echo "⚠️  $*" >&2
}

log_error() {
    echo "❌ $*" >&2
}

# Validation functions
validate_addon_exists() {
    local addon_name="$1"
    local addon_dir="${ADDONS_DIR}/${addon_name}"
    local values_file="${addon_dir}/values.yaml"

    log_verbose "Verificando se o diretório do addon existe: $addon_dir"

    if [[ ! -d "$addon_dir" ]]; then
        log_error "Diretório do addon '$addon_dir' não existe"
        return 1
    fi

    log_verbose "Verificando se values.yaml existe: $values_file"

    if [[ ! -f "$values_file" ]]; then
        log_error "Arquivo values '$values_file' não existe"
        return 1
    fi

    log_success "Addon '$addon_name' existe"
    return 0
}

validate_yaml_syntax() {
    local values_file="$1"

    log_verbose "Validando sintaxe YAML: $values_file"

    if ! yq eval '.' "$values_file" > /dev/null 2>&1; then
        log_error "Sintaxe YAML inválida em '$values_file'"
        return 1
    fi

    log_success "Sintaxe YAML é válida"
    return 0
}

validate_required_fields() {
    local values_file="$1"
    local errors=0

    log_verbose "Validando campos obrigatórios em: $values_file"

    # Check for chart configuration
    if ! yq eval '.chart' "$values_file" > /dev/null 2>&1 || [[ "$(yq eval '.chart' "$values_file")" == "null" ]]; then
        log_error "Campo obrigatório ausente: chart"
        ((errors++))
    else
        # Check chart subfields
        if ! yq eval '.chart.repository' "$values_file" > /dev/null 2>&1 || [[ "$(yq eval '.chart.repository' "$values_file")" == "null" ]]; then
            log_error "Campo obrigatório ausente: chart.repository"
            ((errors++))
        fi

        if ! yq eval '.chart.name' "$values_file" > /dev/null 2>&1 || [[ "$(yq eval '.chart.name' "$values_file")" == "null" ]]; then
            log_error "Campo obrigatório ausente: chart.name"
            ((errors++))
        fi

        if ! yq eval '.chart.version' "$values_file" > /dev/null 2>&1 || [[ "$(yq eval '.chart.version' "$values_file")" == "null" ]]; then
            log_error "Campo obrigatório ausente: chart.version"
            ((errors++))
        fi
    fi

    # Check for destination configuration
    if ! yq eval '.destination' "$values_file" > /dev/null 2>&1 || [[ "$(yq eval '.destination' "$values_file")" == "null" ]]; then
        log_warning "Campo opcional ausente: destination (será usado o nome do addon como namespace)"
    fi

    if [[ $errors -eq 0 ]]; then
        log_success "Todos os campos obrigatórios estão presentes"
        return 0
    else
        log_error "Encontrados $errors erros de validação"
        return 1
    fi
}

validate_helm_repository() {
    local values_file="$1"

    log_verbose "Validando acessibilidade do repositório Helm"

    local repository
    repository=$(yq eval '.chart.repository' "$values_file")

    if [[ "$repository" == "null" ]]; then
        log_warning "Nenhum repositório especificado, pulando validação de repositório"
        return 0
    fi

    if [[ "$DRY_RUN" == true ]]; then
        log_info "DRY RUN: Validaria repositório: $repository"
        return 0
    fi

    # Try to add and update the repository
    local repo_name
    repo_name="validate-$(basename "$repository")"

    if helm repo add "$repo_name" "$repository" > /dev/null 2>&1; then
        if helm repo update "$repo_name" > /dev/null 2>&1; then
            log_success "Repositório '$repository' está acessível"
            helm repo remove "$repo_name" > /dev/null 2>&1 || true
            return 0
        else
            log_error "Repositório '$repository' existe mas atualização falhou"
            helm repo remove "$repo_name" > /dev/null 2>&1 || true
            return 1
        fi
    else
        log_error "Repositório '$repository' não está acessível"
        return 1
    fi
}

validate_helm_chart() {
    local values_file="$1"

    log_verbose "Validando se o chart Helm existe no repositório"

    local repository chart_name chart_version
    repository=$(yq eval '.chart.repository' "$values_file")
    chart_name=$(yq eval '.chart.name' "$values_file")
    chart_version=$(yq eval '.chart.version' "$values_file")

    if [[ "$repository" == "null" || "$chart_name" == "null" || "$chart_version" == "null" ]]; then
        log_warning "Informações do chart incompletas, pulando validação do chart"
        return 0
    fi

    if [[ "$DRY_RUN" == true ]]; then
        log_info "DRY RUN: Validaria chart: $chart_name:$chart_version de $repository"
        return 0
    fi

    # Try to show chart information
    local repo_name
    repo_name="validate-$(basename "$repository")"

    if helm repo add "$repo_name" "$repository" > /dev/null 2>&1; then
        helm repo update "$repo_name" > /dev/null 2>&1

        if helm show chart "$repo_name/$chart_name" --version "$chart_version" > /dev/null 2>&1; then
            log_success "Chart '$chart_name:$chart_version' existe no repositório"
            helm repo remove "$repo_name" > /dev/null 2>&1 || true
            return 0
        else
            log_error "Chart '$chart_name:$chart_version' não encontrado no repositório"
            helm repo remove "$repo_name" > /dev/null 2>&1 || true
            return 1
        fi
    else
        log_error "Não é possível acessar repositório '$repository'"
        return 1
    fi
}

validate_namespace_conflicts() {
    local addon_name="$1"
    local values_file="$2"

    log_verbose "Validando conflitos de namespace com outros addons"

    local namespace
    namespace=$(yq eval '.destination.namespace' "$values_file")

    if [[ "$namespace" == "null" ]]; then
        namespace="$addon_name"
        log_verbose "Usando nome do addon como namespace: $namespace"
    fi

    local conflicts=0

    # Check all other addon configurations
    for other_addon_dir in "${ADDONS_DIR}"/*; do
        if [[ -d "$other_addon_dir" ]]; then
            local other_addon_name
            other_addon_name=$(basename "$other_addon_dir")

            if [[ "$other_addon_name" != "$addon_name" ]]; then
                local other_values_file="${other_addon_dir}/values.yaml"

                if [[ -f "$other_values_file" ]]; then
                    local other_namespace
                    other_namespace=$(yq eval '.destination.namespace' "$other_values_file" 2>/dev/null || echo "$other_addon_name")

                    if [[ "$other_namespace" == "null" ]]; then
                        other_namespace="$other_addon_name"
                    fi

                    if [[ "$namespace" == "$other_namespace" ]]; then
                        log_error "Conflito de namespace: '$namespace' usado por '$addon_name' e '$other_addon_name'"
                        ((conflicts++))
                    fi
                fi
            fi
        fi
    done

    if [[ $conflicts -eq 0 ]]; then
        log_success "Nenhum conflito de namespace encontrado"
        return 0
    else
        log_error "Encontrados $conflicts conflitos de namespace"
        return 1
    fi
}

validate_template_generation() {
    local addon_name="$1"

    log_verbose "Validando geração de template com Helm"

    if [[ "$DRY_RUN" == true ]]; then
        log_info "DRY RUN: Validaria geração de template para addon: $addon_name"
        return 0
    fi

    # Create temporary values file with only this addon
    local temp_values
    temp_values=$(mktemp)

    cat > "$temp_values" << EOF
global:
  domain: homelab.tech
  argoNamespace: argocd
  storageClass: longhorn
  project: homelab
  tls:
    secretName: wildcard-tls
    clusterIssuer: homelab-ca-issuer

createProject: true

enabledAddons:
  - $addon_name
EOF

    # Try to generate template
    if helm template homelab . --values "$temp_values" --dry-run > /dev/null 2>&1; then
        log_success "Geração de template bem-sucedida"
        rm -f "$temp_values"
        return 0
    else
        log_error "Geração de template falhou"
        rm -f "$temp_values"
        return 1
    fi
}

# Main validation function
main() {
    local addon_dir="${ADDONS_DIR}/${ADDON_NAME}"
    local values_file="${addon_dir}/values.yaml"
    local validation_errors=0

    log_info "🔍 Validando addon: $ADDON_NAME"

    # Check if addon exists
    if ! validate_addon_exists "$ADDON_NAME"; then
        exit 1
    fi

    # Validate YAML syntax
    if ! validate_yaml_syntax "$values_file"; then
        ((validation_errors++))
    fi

    # Validate required fields
    if ! validate_required_fields "$values_file"; then
        ((validation_errors++))
    fi

    # Validate Helm repository (if helm is available)
    if command -v helm > /dev/null 2>&1; then
        if ! validate_helm_repository "$values_file"; then
            ((validation_errors++))
        fi

        if ! validate_helm_chart "$values_file"; then
            ((validation_errors++))
        fi

        if ! validate_template_generation "$ADDON_NAME"; then
            ((validation_errors++))
        fi
    else
        log_warning "Helm não encontrado, pulando validações específicas do Helm"
    fi

    # Validate namespace conflicts
    if ! validate_namespace_conflicts "$ADDON_NAME" "$values_file"; then
        ((validation_errors++))
    fi

    # Summary
    if [[ $validation_errors -eq 0 ]]; then
        log_success "🎉 Validação do addon '$ADDON_NAME' concluída com sucesso!"
        exit 0
    else
        log_error "💥 Validação do addon '$ADDON_NAME' falhou com $validation_errors erros"
        exit 1
    fi
}

# Check dependencies
if ! command -v yq > /dev/null 2>&1; then
    error_exit "❌ yq é obrigatório mas não está instalado. Por favor instale o yq primeiro."
fi

# Run main function
main "$@"
