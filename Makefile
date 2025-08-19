.PHONY: diff lint list help status status-detailed diagnose clean backup template validate remove new install uninstall health sync

# Cores para output
GREEN=\033[32m
BLUE=\033[34m
YELLOW=\033[33m
RED=\033[31m
PURPLE=\033[35m
CYAN=\033[36m
BOLD=\033[1m
NC=\033[0m

all: help

## ❓ Ajuda
help:
	@echo "$(CYAN)🏠 Homelab ArgoCD Applications Manager$(NC)"
	@echo ""
	@echo "$(BOLD)$(YELLOW)📖 Comandos principais:$(NC)"
	@echo "  $(GREEN)make install all=true$(NC)         # Instalar TODOS os addons"
	@echo "  $(GREEN)make install name=<addon>$(NC)     # Instalar addon específico (com validações)"
	@echo "  $(GREEN)make uninstall name=<addon>$(NC)   # Desinstalar addon (com confirmação)"
	@echo ""
	@echo "$(YELLOW)🔧 Comandos de operação:$(NC)"
	@echo "  $(GREEN)make health name=<addon>$(NC)      # Verificar saúde do addon"
	@echo "  $(GREEN)make sync name=<addon>$(NC)        # Forçar sincronização"
	@echo "  $(GREEN)make validate name=<addon>$(NC)    # Validar addon (completo)"
	@echo "  $(GREEN)make template [name=<addon>]$(NC)  # Ver template gerado"
	@echo ""
	@echo "$(YELLOW)🔧 Comandos de desenvolvimento:$(NC)"
	@echo "  $(GREEN)make new name=<addon>$(NC)         # Criar novo addon"
	@echo "  $(GREEN)make diff [name=<addon>]$(NC)      # Ver diferenças"
	@echo "  $(GREEN)make lint [name=<addon>]$(NC)      # Validar sintaxe"
	@echo ""
	@echo "$(YELLOW)📊 Comandos de monitoramento:$(NC)"
	@echo "  $(GREEN)make status$(NC)                   # Status básico"
	@echo "  $(GREEN)make status-detailed$(NC)          # Status detalhado"
	@echo "  $(GREEN)make diagnose name=<addon>$(NC)    # Diagnóstico completo"
	@echo "  $(GREEN)make list$(NC)                     # Listar addons"
	@echo ""
	@echo "$(YELLOW)🗑️ Comandos de manutenção:$(NC)"
	@echo "  $(GREEN)make remove name=<addon>$(NC)      # Remover addon (alias para uninstall)"
	@echo "  $(GREEN)make backup$(NC)                   # Backup das configurações"
	@echo "  $(GREEN)make clean$(NC)                    # Limpar temporários"
	@echo ""
	@echo "$(PURPLE)🎯 Addons disponíveis:$(NC)"
	@ls -1 addons/ 2>/dev/null | grep -v "^_" | sed 's/^/  📦 /' || echo "  $(RED)❌ Nenhum addon encontrado$(NC)"
	@echo ""
	@echo "$(BOLD)$(YELLOW)💡 Exemplos de uso:$(NC)"
	@echo "  $(CYAN)make install all=true$(NC)          # Instalar todos os addons"
	@echo "  $(CYAN)make install name=vault$(NC)        # Instalar vault com validações"
	@echo "  $(CYAN)make health name=cert-manager$(NC)  # Verificar saúde do cert-manager"
	@echo "  $(CYAN)make uninstall name=sample-app$(NC) # Remover sample-app"

## 🚀 Instalar todos os addons (alias)
all-install:
	@make install all=true

## 🚀 Instalar addons
install:
	@if [ -z "$(name)" ] && [ "$(all)" != "true" ]; then \
		echo "$(RED)❌ Uso: make install name=<addon> ou make install all=true$(NC)"; \
		echo "$(CYAN)📋 Addons disponíveis:$(NC)"; \
		make list; \
		exit 1; \
	fi
	@if [ "$(all)" = "true" ]; then \
		echo "$(BLUE)🚀 Instalando TODOS os addons do homelab...$(NC)"; \
		helm template . | kubectl apply -f -; \
		echo "$(GREEN)✅ Todos os addons aplicados com sucessomake(NC)"; \
	else \
		if [ ! -d "addons/$(name)" ]; then \
			echo "$(RED)❌ Addon '$(name)' não encontradomake(NC)"; \
			make list; \
			exit 1; \
		fi; \
		echo "$(BLUE)🔍 Validando addon '$(name)'...$(NC)"; \
		make validate name=$(name) || exit 1; \
		echo "$(BLUE)🚀 Instalando addon '$(name)'...$(NC)"; \
		helm template . --set-string enabledAddons='{$(name)}' | kubectl apply -f -; \
		echo "$(GREEN)✅ Addon '$(name)' instalado com sucessomake(NC)"; \
		make health name=$(name); \
	fi

## 🗑️ Desinstalar addon específico
uninstall:
	@if [ -z "$(name)" ]; then \
		echo "$(RED)❌ Uso: make uninstall name=<addon>$(NC)"; \
		make list; \
		exit 1; \
	fi
	@if [ ! -d "addons/$(name)" ]; then \
		echo "$(RED)❌ Addon '$(name)' não encontrado!$(NC)"; \
		make list; \
		exit 1; \
	fi
	@echo "$(YELLOW)⚠️ Você tem certeza que deseja remover o addon '$(name)'? [y/N]$(NC)" && \
	read -r confirmation && \
	if [ "$$confirmation" != "y" ] && [ "$$confirmation" != "Y" ]; then \
		echo "$(BLUE)ℹ️ Operação cancelada$(NC)"; \
		exit 0; \
	fi
	@echo "$(BLUE)🗑️ Removendo addon '$(name)'...$(NC)"
	@kubectl delete application $(name) -n argocd --ignore-not-found=true
	@echo "$(GREEN)✅ Addon '$(name)' removido com sucesso!$(NC)"

## 📊 Status das aplicações ArgoCD
status:
	@echo "$(BLUE)📊 Status das aplicações ArgoCD:$(NC)"
	@kubectl get applications -n argocd -o custom-columns=NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status 2>/dev/null || echo "$(RED)❌ Erro ao conectar com o cluster$(NC)"

## 📊 Status detalhado das aplicações
status-detailed:
	@echo "$(BLUE)📊 Status detalhado das aplicações ArgoCD:$(NC)"
	@kubectl get applications -n argocd -o wide 2>/dev/null || echo "$(RED)❌ Erro ao conectar com o cluster$(NC)"

## 🔍 Diagnóstico completo de um addon
diagnose:
	@if [ -z "$(name)" ]; then \
		echo "$(RED)❌ Uso: make diagnose name=<addon>$(NC)"; \
		make list; \
		exit 1; \
	fi
	@echo "$(BLUE)🔍 Diagnóstico completo do addon '$(name)'...$(NC)"
	@echo ""
	@echo "$(YELLOW)📂 Estrutura do addon:$(NC)"
	@ls -la addons/$(name)/ 2>/dev/null || echo "$(RED)❌ Diretório não encontrado$(NC)"
	@echo ""
	@echo "$(YELLOW)⚙️ Configuração do addon:$(NC)"
	@cat addons/$(name)/values.yaml 2>/dev/null || echo "$(RED)❌ Arquivo de configuração não encontrado$(NC)"
	@echo ""
	@echo "$(YELLOW)🏃 Status da aplicação ArgoCD:$(NC)"
	@kubectl get application $(name) -n argocd -o yaml 2>/dev/null || echo "$(RED)❌ Aplicação não encontrada no ArgoCD$(NC)"

## 🗑️ Remover addon (alias para uninstall)
remove:
	@make uninstall name=$(name)

## 🧹 Limpar arquivos temporários
clean:
	@echo "$(BLUE)🧹 Limpando arquivos temporários...$(NC)"
	@find . -name "*.tmp" -delete 2>/dev/null || true
	@find . -name ".DS_Store" -delete 2>/dev/null || true
	@echo "$(GREEN)✅ Limpeza concluída$(NC)"

## 💾 Backup das configurações
backup:
	@echo "$(BLUE)💾 Fazendo backup das configurações...$(NC)"
	@mkdir -p backups
	@tar -czf backups/homelab-backup-$(shell date +%Y%m%d-%H%M%S).tar.gz addons/ values.yaml Chart.yaml Makefile
	@echo "$(GREEN)✅ Backup criado em backups/$(NC)"
	@ls -la backups/ | tail -1

## 🆕 Criar novo addon
new:
	@if [ -z "$(name)" ]; then \
		echo "$(RED)❌ Uso: make new name=<nome-do-addon>$(NC)"; \
		echo "$(CYAN)💡 Exemplo: make new name=nginx$(NC)"; \
		exit 1; \
	fi
	@if [ -d "addons/$(name)" ]; then \
		echo "$(RED)❌ Addon '$(name)' já existe!$(NC)"; \
		exit 1; \
	fi
	@echo "$(BLUE)🆕 Criando novo addon: $(name)...$(NC)"
	@mkdir -p addons/$(name)
	@echo "# Addon: $(name)" > addons/$(name)/values.yaml
	@echo "metadata:" >> addons/$(name)/values.yaml
	@echo "  annotations:" >> addons/$(name)/values.yaml
	@echo "    app.kubernetes.io/description: \"Addon $(name)\"" >> addons/$(name)/values.yaml
	@echo "    argocd.argoproj.io/sync-wave: \"1\"" >> addons/$(name)/values.yaml
	@echo "" >> addons/$(name)/values.yaml
	@echo "# Projeto específico (opcional, senão usa global)" >> addons/$(name)/values.yaml
	@echo "# project: $(name)" >> addons/$(name)/values.yaml
	@echo "" >> addons/$(name)/values.yaml
	@echo "chart:" >> addons/$(name)/values.yaml
	@echo "  repository: https://charts.example.com  # OBRIGATÓRIO" >> addons/$(name)/values.yaml
	@echo "  name: $(name)                           # OBRIGATÓRIO" >> addons/$(name)/values.yaml
	@echo "  version: \"1.0.0\"                       # OBRIGATÓRIO" >> addons/$(name)/values.yaml
	@echo "" >> addons/$(name)/values.yaml
	@echo "destination:" >> addons/$(name)/values.yaml
	@echo "  namespace: $(name)  # Opcional (default: nome do addon)" >> addons/$(name)/values.yaml
	@echo "" >> addons/$(name)/values.yaml
	@echo "syncPolicy:" >> addons/$(name)/values.yaml
	@echo "  automated:" >> addons/$(name)/values.yaml
	@echo "    prune: true" >> addons/$(name)/values.yaml
	@echo "    selfHeal: true" >> addons/$(name)/values.yaml
	@echo "  syncOptions:" >> addons/$(name)/values.yaml
	@echo "    - CreateNamespace=true" >> addons/$(name)/values.yaml
	@echo "" >> addons/$(name)/values.yaml
	@echo "helm:" >> addons/$(name)/values.yaml
	@echo "  values:" >> addons/$(name)/values.yaml
	@echo "    # Configurações do chart aqui" >> addons/$(name)/values.yaml
	@echo "    nameOverride: $(name)" >> addons/$(name)/values.yaml
	@echo "$(GREEN)✅ Addon '$(name)' criado com sucesso!$(NC)"
	@echo ""
	@echo "$(YELLOW)📝 Próximos passos:$(NC)"
	@echo "  1. $(CYAN)Editar:$(NC) addons/$(name)/values.yaml"
	@echo "  2. $(CYAN)Configurar:$(NC) repository, name e version do chart"
	@echo "  3. $(CYAN)Validar:$(NC) make validate name=$(name)"
	@echo "  4. $(CYAN)Instalar:$(NC) make install name=$(name)"

## 🔍 Ver diferenças
diff:
	@if [ -z "$(name)" ]; then \
		echo "$(BLUE)🔍 Diferenças de todos os addons:$(NC)"; \
		helm diff upgrade homelab . --allow-unreleased || echo "$(BLUE)ℹ️ Plugin helm-diff não instalado$(NC)"; \
	else \
		echo "$(BLUE)🔍 Diferenças do addon '$(name)':$(NC)"; \
		helm diff upgrade $(name) . --set-string enabledAddons='{$(name)}' --allow-unreleased || echo "$(BLUE)ℹ️ Plugin helm-diff não instalado$(NC)"; \
	fi

## 🔍 Validar sintaxe
lint:
	@if [ -z "$(name)" ]; then \
		echo "$(BLUE)🔍 Validando sintaxe de todos os templates...$(NC)"; \
		helm lint .; \
	else \
		echo "$(BLUE)🔍 Validando sintaxe do addon '$(name)'...$(NC)"; \
		yq eval '.' addons/$(name)/values.yaml >/dev/null 2>&1 && echo "$(GREEN)✅ Sintaxe válida$(NC)" || echo "$(RED)❌ Sintaxe inválida$(NC)"; \
	fi

## 📋 Listar addons disponíveis
list:
	@echo "$(PURPLE)📦 Addons disponíveis:$(NC)"
	@ls -1 addons/ 2>/dev/null | grep -v "^_" | sed 's/^/  📦 /' || echo "  $(RED)❌ Nenhum addon encontrado$(NC)"

## ✅ Validar addon específico (completo)
validate:
	@if [ -z "$(name)" ]; then \
		echo "$(RED)❌ Uso: make validate name=<addon>$(NC)"; \
		make list; \
		exit 1; \
	fi
	@echo "$(BLUE)🔍 Validando addon '$(name)'...$(NC)"
	@if [ ! -d "addons/$(name)" ]; then \
		echo "$(RED)❌ Diretório do addon não encontrado$(NC)"; \
		exit 1; \
	fi
	@if [ ! -f "addons/$(name)/values.yaml" ]; then \
		echo "$(RED)❌ Arquivo values.yaml não encontrado$(NC)"; \
		exit 1; \
	fi
	@yq eval '.' addons/$(name)/values.yaml >/dev/null 2>&1 || \
	(echo "$(RED)❌ Arquivo values.yaml inválido$(NC)" && exit 1)
	@echo "$(GREEN)✅ Addon '$(name)' validado com sucesso$(NC)"

## 📄 Ver template gerado
template:
	@if [ -z "$(name)" ]; then \
		echo "$(BLUE)📄 Template completo do homelab:$(NC)"; \
		helm template .; \
	else \
		echo "$(BLUE)📄 Template do addon '$(name)':$(NC)"; \
		helm template . --set-string enabledAddons='{$(name)}'; \
	fi

## 🏥 Verificar saúde do addon
health:
	@if [ -z "$(name)" ]; then \
		echo "$(RED)❌ Uso: make health name=<addon>$(NC)"; \
		make list; \
		exit 1; \
	fi
	@echo "$(BLUE)🏥 Verificando saúde do addon '$(name)'...$(NC)"
	@if kubectl get application $(name) -n argocd >/dev/null 2>&1; then \
		HEALTH=$$(kubectl get application $(name) -n argocd -o jsonpath='{.status.health.status}' 2>/dev/null || echo "Unknown"); \
		SYNC=$$(kubectl get application $(name) -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown"); \
		echo "$(CYAN)📊 Status da Application:$(NC)"; \
		echo "  Health: $$HEALTH"; \
		echo "  Sync: $$SYNC"; \
		if [ "$$HEALTH" = "Healthy" ] && [ "$$SYNC" = "Synced" ]; then \
			echo "$(GREEN)✅ Addon '$(name)' está saudável!$(NC)"; \
		else \
			echo "$(YELLOW)⚠️ Addon '$(name)' pode ter problemas$(NC)"; \
			echo "$(CYAN)💡 Para mais detalhes: make diagnose name=$(name)$(NC)"; \
		fi; \
	else \
		echo "$(RED)❌ Application '$(name)' não encontrada no ArgoCD$(NC)"; \
		exit 1; \
	fi

## 🔄 Sincronizar addon específico
sync:
	@if [ -z "$(name)" ]; then \
		echo "$(RED)❌ Uso: make sync name=<addon>$(NC)"; \
		make list; \
		exit 1; \
	fi
	@echo "$(BLUE)🔄 Sincronizando addon '$(name)'...$(NC)"
	@if kubectl get application $(name) -n argocd >/dev/null 2>&1; then \
		kubectl patch application $(name) -n argocd --type merge -p '{"operation":{"sync":{"syncStrategy":{"hook":{},"apply":{"force":true}}}}}' || \
		kubectl patch application $(name) -n argocd --type merge -p '{"spec":{"syncPolicy":{"syncOptions":["CreateNamespace=true"]}}}'; \
		echo "$(GREEN)✅ Sincronização do addon '$(name)' iniciada$(NC)"; \
		echo "$(CYAN)💡 Para verificar o progresso: make health name=$(name)$(NC)"; \
	else \
		echo "$(RED)❌ Application '$(name)' não encontrada no ArgoCD$(NC)"; \
		exit 1; \
	fi
