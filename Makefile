# Makefile — comandos de conveniência para o ambiente Podman
# Uso: make <target>   (execute na raiz do repositório)

COMPOSE = podman compose -f podman/compose.yml --env-file podman/.env
COMPOSE_TG = podman compose -f podman/compose.yml -f podman/compose.telegram.yml --env-file podman/.env

.PHONY: help deploy up down build build-ergo build-webircgateway build-thelounge build-nginx restart \
        logs logs-ergo logs-webircgateway logs-thelounge logs-nginx \
        ergo-shell webircgateway-shell thelounge-shell nginx-shell \
        ergo-restart webircgateway-restart thelounge-restart nginx-restart \
        up-telegram down-telegram build-matterbridge logs-matterbridge \
        matterbridge-shell matterbridge-restart \
        ps

# ── Ajuda ────────────────────────────────────────────────────────────────────

help: ## Mostra esta ajuda
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
	  awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}'

# ── Deploy local ─────────────────────────────────────────────────────────────
# Um único comando para subir o ambiente do zero (primeira vez) ou depois de
# atualizar o código — idempotente, pode rodar quantas vezes quiser. Ambiente
# local é sempre plaintext (sem TLS), então não há certificados a gerar.

deploy: ## Sobe (ou atualiza) o ambiente local inteiro: .env + build + up
	@echo "🚀 Deploy local..."
	@[ -f podman/.env ] || (cp podman/.env.example podman/.env && echo "  → podman/.env criado")
	@$(MAKE) build
	@$(MAKE) up
	@echo ""
	@echo "✅ Ambiente disponível:"
	@echo "   KiwiIRC:    http://localhost:9080"
	@echo "   Gamja:      http://localhost:9081"
	@echo "   The Lounge: http://localhost:9082"
	@echo "   IRC:        localhost:6667"

# ── Ciclo de vida ────────────────────────────────────────────────────────────

up: ## Sobe todos os serviços em background
	$(COMPOSE) up -d

down: ## Para e remove todos os containers
	$(COMPOSE) down

build: ## Reconstrói todas as imagens
	$(COMPOSE) build

build-ergo: ## Reconstrói apenas a imagem do Ergo (servidor IRC) e reinicia o container
	$(COMPOSE) build ergo
	$(COMPOSE) up -d --no-deps ergo

build-webircgateway: ## Reconstrói apenas a imagem do webircgateway (KiwiIRC/Gamja) e reinicia o container
	$(COMPOSE) build webircgateway
	$(COMPOSE) up -d --no-deps webircgateway

build-thelounge: ## Reconstrói apenas a imagem do The Lounge e reinicia o container
	$(COMPOSE) build thelounge
	$(COMPOSE) up -d --no-deps thelounge

build-nginx: ## Reconstrói apenas a imagem do Nginx e reinicia o container
	$(COMPOSE) build nginx
	$(COMPOSE) up -d --no-deps nginx

restart: ## Reinicia todos os serviços
	$(COMPOSE) restart

ps: ## Lista containers em execução
	$(COMPOSE) ps

# ── Ponte IRC <-> Telegram (Matterbridge, opcional) ──────────────────────────
# Não sobe junto com `make up` — precisa de podman/.env com TELEGRAM_BOT_TOKEN
# e TELEGRAM_CHAT_ID preenchidos (veja podman/.env.example).

up-telegram: ## Sobe a ponte Telegram (requer a stack principal já rodando)
	$(COMPOSE_TG) up -d --build matterbridge

down-telegram: ## Para e remove o container da ponte Telegram
	$(COMPOSE_TG) rm -sf matterbridge

build-matterbridge: ## Reconstrói apenas a imagem do Matterbridge
	$(COMPOSE_TG) build matterbridge
	$(COMPOSE_TG) up -d --no-deps matterbridge

logs-matterbridge: ## Logs do container matterbridge
	$(COMPOSE_TG) logs -f matterbridge

matterbridge-shell: ## Shell no container matterbridge
	$(COMPOSE_TG) exec matterbridge sh

matterbridge-restart: ## Reinicia apenas o container matterbridge
	$(COMPOSE_TG) restart matterbridge

# ── Logs ─────────────────────────────────────────────────────────────────────

logs: ## Logs de todos os serviços (segue)
	$(COMPOSE) logs -f

logs-ergo: ## Logs do container ergo (servidor IRC)
	$(COMPOSE) logs -f ergo

logs-webircgateway: ## Logs do container webircgateway (KiwiIRC/Gamja)
	$(COMPOSE) logs -f webircgateway

logs-thelounge: ## Logs do container thelounge
	$(COMPOSE) logs -f thelounge

logs-nginx: ## Logs do container nginx
	$(COMPOSE) logs -f nginx

# ── Shells ────────────────────────────────────────────────────────────────────

ergo-shell: ## Shell no container ergo
	$(COMPOSE) exec ergo sh

webircgateway-shell: ## Shell no container webircgateway
	$(COMPOSE) exec webircgateway sh

thelounge-shell: ## Shell no container thelounge
	$(COMPOSE) exec thelounge sh

nginx-shell: ## Shell no container nginx
	$(COMPOSE) exec nginx sh

# ── Restart individual ────────────────────────────────────────────────────────

ergo-restart: ## Reinicia apenas o container ergo
	$(COMPOSE) restart ergo

webircgateway-restart: ## Reinicia apenas o container webircgateway
	$(COMPOSE) restart webircgateway

thelounge-restart: ## Reinicia apenas o container thelounge
	$(COMPOSE) restart thelounge

nginx-restart: ## Reinicia apenas o container nginx
	$(COMPOSE) restart nginx
