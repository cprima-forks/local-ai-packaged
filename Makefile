# Try to find the right python command
PYTHON := $(shell command -v python 2>/dev/null || command -v python3)

# Default profile if none is given
PROFILE ?= gpu-nvidia

# Compose files
COMPOSE_FILES = -f docker-compose.yml -f supabase/docker/docker-compose.yml
PROJECT = localai

.PHONY: help up down pull restart supabase localai logs sync pull-model

help: ## Show this help message
	@echo "Self-Hosted AI Makefile Commands:"
	@echo ""
	@echo "Usage:"
	@echo "  make <target> [PROFILE=cpu|gpu-nvidia|gpu-amd|none] [MODEL=model-name]"
	@echo ""
	@echo "Targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'
	@echo ""
	@echo "Examples:"
	@echo "  make up PROFILE=gpu-nvidia          # Start services with NVIDIA GPU profile"
	@echo "  make update PROFILE=cpu             # Pull latest images and restart everything"
	@echo "  make pull-model MODEL=llama3        # Pull a new Ollama model inside running container"

up: ## Start all services (Supabase + Local AI)
	$(PYTHON) start_services.py --profile $(PROFILE)

down: ## Stop all services
	docker compose -p $(PROJECT) --profile $(PROFILE) $(COMPOSE_FILES) down

pull: ## Pull latest images
	docker compose -p $(PROJECT) --profile $(PROFILE) $(COMPOSE_FILES) pull

restart: down up ## Restart all services

#supabase: ## Start only Supabase services
#	docker compose -p $(PROJECT) -f supabase/docker/docker-compose.yml up -d
#
#localai: ## Start only Local AI services
#	docker compose -p $(PROJECT) -f docker-compose.yml up -d

logs: ## Tail logs for all services
	docker compose -p $(PROJECT) logs -f

update: ## Pull the latest images and restart everything (full update)
	$(MAKE) down PROFILE=$(PROFILE)
	$(MAKE) pull PROFILE=$(PROFILE)
	@echo ""
	@echo "[INFO] If you see warnings about orphan containers after update:"
	@echo "[INFO] Run: docker compose -p $(PROJECT) $(COMPOSE_FILES) down --remove-orphans"
	@echo ""
	$(MAKE) up PROFILE=$(PROFILE)

sync:
	@echo "Detecting current Git branch..."
	@branch=$$(git rev-parse --abbrev-ref HEAD); \
	if [ "$$branch" = "main" ]; then \
		echo "⚠️  You are on 'main'. Exiting without making changes."; \
		exit 0; \
	fi; \
	echo "✅ Working on branch: $$branch"; \
	echo "Fetching all remotes..."; \
	git fetch --all; \
	echo "Resetting local main to upstream/main..."; \
	git checkout main; \
	git reset --hard upstream/main; \
	echo "Switching back to $$branch..."; \
	git checkout $$branch; \
	echo "Rebasing $$branch onto main..."; \
	git rebase main; \
	echo "🎯 Done! Branch $$branch is now rebased on latest main."


pull-model: ## Pull a specific model using the running Ollama container
	@if [ -z "$(MODEL)" ]; then \
		echo "❌ Error: No MODEL specified. Usage: make pull-model MODEL=llama3"; \
		exit 1; \
	fi
	docker exec -it ollama ollama pull $(MODEL)

