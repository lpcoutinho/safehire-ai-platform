.PHONY: help up down restart logs build clean test lint

help: ## Mostra comandos disponíveis
	@echo "Comandos disponíveis:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

up: ## Inicia todos os serviços
	docker-compose up -d
	@echo "Serviços iniciados!"
	@echo "Frontend: http://localhost:3000"
	@echo "API Gateway: http://localhost:8000"
	@echo "RabbitMQ Management: http://localhost:15672 (guest/guest)"

down: ## Para todos os serviços
	docker-compose down
	@echo "Serviços parados."

restart: down up ## Reinicia todos os serviços

logs: ## Mostra logs de todos os serviços
	docker-compose logs -f

logs-service: ## Mostra logs de um serviço específico (ex: make logs-service SERVICE=auth-service)
	docker-compose logs -f $(SERVICE)

build: ## Rebuilda todas as imagens
	docker-compose build --no-cache

build-service: ## Rebuilda um serviço específico (ex: make build-service SERVICE=auth-service)
	docker-compose build --no-cache $(SERVICE)

clean: ## Remove containers, volumes e networks
	docker-compose down -v --remove-orphans
	docker system prune -f
	@echo "Limpeza completa realizada."

test: ## Roda todos os testes
	docker-compose run --rm auth-service pytest
	docker-compose run --rm api-gateway pytest
	docker-compose run --rm core-management-api pytest
	docker-compose run --rm agent-worker-service pytest
	docker-compose run --rm frontend-app npm test

lint: ## Roda linting em todos os serviços
	docker-compose run --rm auth-service black --check app tests
	docker-compose run --rm auth-service mypy app
	docker-compose run --rm frontend-app npm run lint

format: ## Formata código de todos os serviços
	docker-compose run --rm auth-service black app tests
	docker-compose run --rm auth-service isort app tests
	docker-compose run --rm frontend-app npm run format

migrate: ## Roda migrations do PostgreSQL
	docker-compose exec postgres psql -U safehire -d safehire -f /docker-entrypoint-initdb.d/init.sql

shell-auth: ## Abre shell no auth-service
	docker-compose exec auth-service bash

shell-core: ## Abre shell no core-management-api
	docker-compose exec core-management-api bash

shell-worker: ## Abre shell no agent-worker-service
	docker-compose exec agent-worker-service bash

db-shell: ## Abre psql no PostgreSQL
	docker-compose exec postgres psql -U safehire -d safehire

rabbitmq-shell: ## Abre shell no RabbitMQ
	docker-compose exec rabbitmq rabbitmq-plugins enable rabbitmq_management

valkey-shell: ## Abre valkey-cli
	docker-compose exec valkey valkey-cli

ps: ## Lista containers em execução
	docker-compose ps