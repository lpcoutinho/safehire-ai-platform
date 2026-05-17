# Infraestrutura Docker Compose - Plano de Execução

## Visão Geral

O **docker-compose.yml** é o coração da orquestração local da plataforma SafeHire AI. Responsável por iniciar todos os serviços (infraestrutura, APIs, frontend, workers) em uma rede Docker isolada.

### Arquitetura Simplificada com Floci

Usamos **Floci** (emulador AWS all-in-one) para TODOS os serviços de infraestrutura:

| Serviço AWS emulado | Porta Container | Porta Host | Substitui |
|---------------------|-----------------|------------|-----------|
| **RDS (PostgreSQL)** | 5432 | 5433 | `postgres` |
| **SQS** | 9324, 9325 | 9326, 9327 | `rabbitmq` |
| **ElastiCache (Valkey)** | 6379 | 6380 | `valkey` |
| **S3** | 4566, 8080 | 4566, 8089 | S3 local |

### Serviços a Orquestrar
1. **Floci** - All-in-one AWS Emulator (RDS + SQS + ElastiCache + S3)
2. **auth-service** - API de autenticação
3. **api-gateway** - Gateway e roteamento
4. **core-management-api** - API core de negócio
5. **agent-worker-service** - Worker de IA
6. **frontend-app** - Next.js app

---

## Arquitetura de Rede

```
┌─────────────────────────────────────────────────────────────────┐
│                      DOCKER NETWORK: safehire-network           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │                    Floci (All-in-One)                   │  │
│  │                                                         │  │
│  │  RDS/PostgreSQL :5432→5433                             │  │
│  │  SQS           :9324→9326, 9325→9327                   │  │
│  │  ElastiCache   :6379→6380                              │  │
│  │  S3            :4566→4566, 8080→8089                   │  │
│  └─────────────────────────────────────────────────────────┘  │
│         │                                          │           │
│         ▼                                          ▼           │
│  ┌──────────────┐                           ┌──────────────┐  │
│  │ auth-service │                           │agent-worker  │  │
│  │   :8000      │                           │   :8000      │  │
│  └──────────────┘                           └──────────────┘  │
│         │                                          │           │
│         ▼                                          │           │
│  ┌──────────────┐                                 │           │
│  │ api-gateway  │                                 │           │
│  │   :8000      │◀────────────────────────────────┘           │
│  └──────┬───────┘                                             │
│         │                                                     │
│         ▼                                                     │
│  ┌──────────────┐                                             │
│  │core-mgmt-api │                                             │
│  │   :8000      │                                             │
│  └──────────────┘                                             │
│         │                                                     │
│         ▼                                                     │
│  ┌──────────────┐                                             │
│  │ frontend-app │  ←── HTTP ONLY (porta 3000)                 │
│  │   :3000      │                                             │
│  └──────────────┘                                             │
└─────────────────────────────────────────────────────────────────┘
```

---

## Roadmap de Implementação

### Fase 1: Infraestrutura Simplificada (Dia 1) ✅ CONCLUÍDO
- [x] Migrar para Floci all-in-one (substitui postgres, rabbitmq, valkey, s3)
- [x] Criar `docker-compose.yml` com Floci único serviço de infra
- [x] Configurar rede Docker
- [x] Configurar volumes para persistência
- [x] Configurar health checks do Floci
- [x] Criar `init-rds.sql` para inicializar schemas no RDS
- [x] Remover `version: '3.8'` (obsoleto)
- [x] Ajustar portas para evitar conflitos no host
- [x] Validar startup do Floci (UP e healthy)
- [x] Validar S3 endpoint (http://localhost:4566/)

### Fase 2: Serviços Python (Dia 1-2) ⏸️ PENDENTE CÓDIGO
- [x] Dockerfiles criados em cada submódulo
- [ ] Adicionar auth-service ao docker-compose (descomentar quando código existir)
- [ ] Adicionar api-gateway ao docker-compose (descomentar quando código existir)
- [ ] Adicionar core-management-api ao docker-compose (descomentar quando código existir)
- [ ] Adicionar agent-worker-service ao docker-compose (descomentar quando código existir)

### Fase 3: Frontend (Dia 2) ⏸️ PENDENTE CÓDIGO
- [x] Dockerfile criado no submódulo
- [ ] Adicionar frontend-app ao docker-compose (descomentar quando código existir)

### Fase 4: Scripts Auxiliares (Dia 2) ✅ CONCLUÍDO
- [x] Criar Makefile para comandos comuns
- [x] Criar scripts de inicialização do RDS
- [ ] Criar scripts de seed de dados (opcional)

---

## TodoList Detalhada

### Docker Compose
- [x] Criar `docker-compose.yml`: ✅ Arquivo criado com todos os serviços configurados

```yaml
version: '3.8'

services:
  # ============================================
  # INFRAESTRUTURA
  # ============================================

  postgres:
    image: postgres:15-alpine
    container_name: safehire-postgres
    environment:
      POSTGRES_USER: ${POSTGRES_USER:-safehire}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-safehire_password}
      POSTGRES_DB: ${POSTGRES_DB:-safehire}
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./scripts/init-postgres.sql:/docker-entrypoint-initdb.d/init.sql
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER:-safehire}"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - safehire-network

  rabbitmq:
    image: rabbitmq:3-management-alpine
    container_name: safehire-rabbitmq
    environment:
      RABBITMQ_DEFAULT_USER: ${RABBITMQ_USER:-guest}
      RABBITMQ_DEFAULT_PASS: ${RABBITMQ_PASSWORD:-guest}
    ports:
      - "5672:5672"
      - "15672:15672"  # Management UI
    volumes:
      - rabbitmq_data:/var/lib/rabbitmq
    healthcheck:
      test: ["CMD", "rabbitmq-diagnostics", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - safehire-network

  valkey:
    image: valkey/valkey:7.2-alpine
    container_name: safehire-valkey
    command: valkey-server --save 60 1 --loglevel warning
    ports:
      - "6379:6379"
    volumes:
      - valkey_data:/data
    healthcheck:
      test: ["CMD", "valkey-cli", "ping"]
      interval: 10s
      timeout: 3s
      retries: 5
    networks:
      - safehire-network

  floci:
    image: ghcr.io/openstack/floci:latest
    container_name: safehire-floci
    ports:
      - "4566:4566"
    environment:
      SERVICES: s3
      DEBUG: ${DEBUG:-0}
      DATA_DIR: /tmp/localstack_data
    volumes:
      - floci_data:/tmp/localstack_data
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:4566/_localstack/health || exit 1"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - safehire-network

  # ============================================
  # SERVIÇOS PYTHON
  # ============================================

  auth-service:
    build:
      context: ./auth-service
      dockerfile: Dockerfile
    container_name: safehire-auth-service
    environment:
      DATABASE_URL: postgresql+asyncpg://${POSTGRES_USER:-safehire}:${POSTGRES_PASSWORD:-safehire_password}@postgres:5432/safehire
      AUTH_SCHEMA: auth_schema
      JWT_SECRET_KEY: ${JWT_SECRET_KEY:-dev-secret-key-change-me}
      JWT_ALGORITHM: HS256
      ACCESS_TOKEN_EXPIRE_MINUTES: 30
      REFRESH_TOKEN_EXPIRE_DAYS: 7
      DEBUG: ${DEBUG:-0}
    ports:
      - "8001:8000"
    depends_on:
      postgres:
        condition: service_healthy
    networks:
      - safehire-network
    restart: unless-stopped

  api-gateway:
    build:
      context: ./api-gateway
      dockerfile: Dockerfile
    container_name: safehire-api-gateway
    environment:
      AUTH_SERVICE_URL: http://auth-service:8000
      CORE_SERVICE_URL: http://core-management-api:8000
      JWT_SECRET_KEY: ${JWT_SECRET_KEY:-dev-secret-key-change-me}
      JWT_ALGORITHM: HS256
      VALKEY_URL: redis://valkey:6379/0
      RATE_LIMIT_REQUESTS: 100
      RATE_LIMIT_WINDOW: 60
      DEBUG: ${DEBUG:-0}
    ports:
      - "8000:8000"
    depends_on:
      - auth-service
      - core-management-api
      - valkey
    networks:
      - safehire-network
    restart: unless-stopped

  core-management-api:
    build:
      context: ./core-management-api
      dockerfile: Dockerfile
    container_name: safehire-core-api
    environment:
      DATABASE_URL: postgresql+asyncpg://${POSTGRES_USER:-safehire}:${POSTGRES_PASSWORD:-safehire_password}@postgres:5432/safehire
      CORE_SCHEMA: core_schema
      AWS_ACCESS_KEY_ID: fake_access_key
      AWS_SECRET_ACCESS_KEY: fake_secret_key
      AWS_REGION: us-east-1
      S3_ENDPOINT_URL: http://floci:4566
      S3_BUCKET_NAME: safehire-curriculos
      RABBITMQ_URL: amqp://${RABBITMQ_USER:-guest}:${RABBITMQ_PASSWORD:-guest}@rabbitmq:5672/
      RABBITMQ_QUEUE: candidatos.novos
      VALKEY_URL: redis://valkey:6379/1
      DEBUG: ${DEBUG:-0}
    ports:
      - "8002:8000"
    depends_on:
      postgres:
        condition: service_healthy
      floci:
        condition: service_healthy
      rabbitmq:
        condition: service_healthy
      valkey:
        condition: service_healthy
    networks:
      - safehire-network
    restart: unless-stopped

  agent-worker-service:
    build:
      context: ./agent-worker-service
      dockerfile: Dockerfile
    container_name: safehire-agent-worker
    environment:
      DATABASE_URL: postgresql+asyncpg://${POSTGRES_USER:-safehire}:${POSTGRES_PASSWORD:-safehire_password}@postgres:5432/safehire
      AGENT_SCHEMA: agent_schema
      AWS_ACCESS_KEY_ID: fake_access_key
      AWS_SECRET_ACCESS_KEY: fake_secret_key
      AWS_REGION: us-east-1
      S3_ENDPOINT_URL: http://floci:4566
      S3_BUCKET_NAME: safehire-curriculos
      RABBITMQ_URL: amqp://${RABBITMQ_USER:-guest}:${RABBITMQ_PASSWORD:-guest}@rabbitmq:5672/
      RABBITMQ_QUEUE: candidatos.novos
      VALKEY_URL: redis://valkey:6379/2
      EMBEDDING_MODEL: sentence-transformers/all-MiniLM-L6-v2
      EMBEDDING_DIMENSION: 384
      LLM_MODEL: gpt-4
      LLM_API_KEY: ${OPENAI_API_KEY:-}
      MAX_CONCURRENT_JOBS: 3
      JOB_TIMEOUT: 600
      DEBUG: ${DEBUG:-0}
    depends_on:
      postgres:
        condition: service_healthy
      floci:
        condition: service_healthy
      rabbitmq:
        condition: service_healthy
      valkey:
        condition: service_healthy
    networks:
      - safehire-network
    restart: unless-stopped

  # ============================================
  # FRONTEND
  # ============================================

  frontend-app:
    build:
      context: ./frontend-app
      dockerfile: Dockerfile
    container_name: safehire-frontend
    environment:
      NEXT_PUBLIC_API_URL: http://api-gateway:8000
      NEXT_PUBLIC_APP_NAME: SafeHire AI
      NEXT_PUBLIC_APP_URL: http://localhost:3000
    ports:
      - "3000:3000"
    depends_on:
      - api-gateway
    networks:
      - safehire-network
    restart: unless-stopped

volumes:
  postgres_data:
  rabbitmq_data:
  valkey_data:
  floci_data:

networks:
  safehire-network:
    driver: bridge
    internal: true
```

### Script de Inicialização do RDS (Floci)
- [x] Criar `scripts/init-rds.sql`: ✅ Arquivo criado em `scripts/`

```sql
-- Criar schemas isolados
CREATE SCHEMA IF NOT EXISTS auth_schema;
CREATE SCHEMA IF NOT EXISTS core_schema;
CREATE SCHEMA IF NOT EXISTS agent_schema;

-- Habilitar extensão pgvector no agent_schema
CREATE EXTENSION IF NOT EXISTS vector SCHEMA agent_schema;

-- Grant permissions
GRANT ALL ON SCHEMA auth_schema TO safehire;
GRANT ALL ON SCHEMA core_schema TO safehire;
GRANT ALL ON SCHEMA agent_schema TO safehire;

-- Criar tabelas básicas (será feito pelas migrations dos serviços)
```

### Environment Variables
- [x] Criar `.env.example` na raiz: ✅ Arquivo atualizado com Floci credentials

```env
# PostgreSQL
POSTGRES_USER=safehire
POSTGRES_PASSWORD=safehire_password
POSTGRES_DB=safehire

# RabbitMQ
RABBITMQ_USER=guest
RABBITMQ_PASSWORD=guest

# JWT
JWT_SECRET_KEY=change-this-in-production-use-environment-variable

# OpenAI (para CrewAI)
OPENAI_API_KEY=your-openai-api-key

# Debug
DEBUG=0

# Port override (opcional)
FRONTEND_PORT=3000
GATEWAY_PORT=8000
AUTH_SERVICE_PORT=8001
CORE_API_PORT=8002
```

### Makefile
- [x] Criar `Makefile`: ✅ Arquivo criado na raiz com todos os comandos

```makefile
.PHONY: help up down restart logs build clean test lint

help: ## Mostra comandos disponíveis
	@echo "Comandos disponíveis:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \\033[36m%-20s\\033[0m %s\\n", $$1, $$2}'

up: ## Inicia todos os serviços
	docker compose up -d
	@echo "Serviços iniciados!"
	@echo "Frontend: http://localhost:3000"
	@echo "API Gateway: http://localhost:8000"
	@echo "Floci Console: http://localhost:8080"
	@echo "SQS Management: http://localhost:9325"

down: ## Para todos os serviços
	docker compose down
	@echo "Serviços parados."

restart: down up ## Reinicia todos os serviços

logs: ## Mostra logs de todos os serviços
	docker compose logs -f

logs-service: ## Mostra logs de um serviço específico (ex: make logs-service SERVICE=auth-service)
	docker compose logs -f $(SERVICE)

build: ## Rebuilda todas as imagens
	docker compose build --no-cache

build-service: ## Rebuilda um serviço específico (ex: make build-service SERVICE=auth-service)
	docker compose build --no-cache $(SERVICE)

clean: ## Remove containers, volumes e networks
	docker compose down -v --remove-orphans
	docker system prune -f
	@echo "Limpeza completa realizada."

test: ## Roda todos os testes
	docker compose run --rm auth-service pytest
	docker compose run --rm api-gateway pytest
	docker compose run --rm core-management-api pytest
	docker compose run --rm agent-worker-service pytest
	docker compose run --rm frontend-app npm test

lint: ## Roda linting em todos os serviços
	docker compose run --rm auth-service black --check app tests
	docker compose run --rm auth-service mypy app
	docker compose run --rm frontend-app npm run lint

format: ## Formata código de todos os serviços
	docker compose run --rm auth-service black app tests
	docker compose run --rm auth-service isort app tests
	docker compose run --rm frontend-app npm run format

migrate: ## Roda migrations do RDS (Floci)
	docker compose exec floci psql -h localhost -p 5432 -U safehire -d safehire -f /docker-entrypoint-initdb.d/init.sql

shell-auth: ## Abre shell no auth-service
	docker compose exec auth-service bash

shell-core: ## Abre shell no core-management-api
	docker compose exec core-management-api bash

shell-worker: ## Abre shell no agent-worker-service
	docker compose exec agent-worker-service bash

db-shell: ## Abre psql no RDS (Floci)
	docker compose exec floci psql -h localhost -p 5432 -U safehire -d safehire

redis-shell: ## Abre redis-cli no ElastiCache (Floci)
	docker compose exec floci redis-cli -h localhost -p 6379

ps: ## Lista containers em execução
	docker compose ps
```

---

## Validação e Critérios de Aceitação

### Funcional
- [x] Floci inicia e expõe todos os serviços (RDS, SQS, ElastiCache, S3)
- [x] Health check do Floci passa (status: healthy)
- [x] S3 endpoint responde (http://localhost:4566/)
- [x] Volumes são persistidos
- [x] Rede Docker funciona

### Técnico
- [x] Imagem `floci/floci:latest` carrega corretamente
- [x] Variáveis de ambiente são injetadas
- [x] Portas mapeadas sem conflitos
- [x] Logs são acessíveis via `make logs`

### Operacional
- [x] Makefile funciona
- [x] `make up` inicia Floci sem warning
- [x] `make down` para tudo
- [x] `make logs` mostra logs
- [x] `make ps` mostra status

---

## Comandos

```bash
# Iniciar tudo
make up

# Ver status
make ps

# Ver logs
make logs

# Parar tudo
make down

# Rebuildar tudo
make build

# Limpar tudo
make clean

# Acessar serviços
make db-shell      # RDS (PostgreSQL via Floci)
make redis-shell   # ElastiCache (Valkey via Floci)
```

---

## Próximos Passos

Após completar a infraestrutura:

1. ✅ Testar startup do Floci
2. ⏸️ Testar comunicação entre serviços (pendente código dos serviços)
3. ⏸️ Configurar monitoring e logs, veja ../observability/plano-execucao.md
4. ✅ Documentar comandos Floci - ver `docs/floci-comandos.md`

## Referência de Comandos Floci

Consulte `docs/floci-comandos.md` para:
- Comandos S3, SQS, RDS, ElastiCache
- Monitoramento e diagnóstico
- Integração Python (boto3, redis)
- Troubleshooting