# SafeHire AI Platform

🤖 **Plataforma de Recrutamento Técnico impulsionada por Inteligência Artificial Agêntica**

---

## 📋 Visão Geral

O **SafeHire AI** é uma plataforma corporativa distribuída, baseada em microsserviços e orientada a eventos, projetada para automatizar o pipeline completo de recrutamento técnico (*Tech Recruiting*). O sistema combina:

- **Inteligência Artificial Agêntica** (CrewAI) para análise automática de currículos
- **Busca Vetorial** (pgvector) para matching semântico entre candidatos e vagas
- **Arquitetura de Eventos** (RabbitMQ) para processamento assíncrono
- **Renderização Híbrida** (Next.js SSR/ISR) para performance e SEO
- **Observabilidade Dual-Stack** (Prometheus/Grafana local + AWS CloudWatch produção)

### 🎯 Valor Proposto

| Para Candidatos | Para Recrutadores |
|-----------------|-------------------|
| Processo transparente com feedback instantâneo | Screening automatizado com IA |
| Roteiro personalizado de estudos | Dossiês estruturados com gaps e pontos fortes |
| Status em tempo real do processo | Roteiro de entrevista personalizado |
| Privacidade e segurança de dados (LGPD) | Métricas de risco e compatibilidade |

---

## 🏗️ Arquitetura

### Microsserviços

```
┌─────────────────────────────────────────────────────────────────────┐
│                        EXTERNAL WORLD                               │
└──────────────────────────────┬──────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    Next.js Frontend App                             │
│  - SSR/ISR: /vagas, /vagas/[id], /vagas/[id]/aplicar                │
│  - CSR: /admin, /admin/vagas/nova, /admin/candidatos/[id]           │
└──────────────────────────────┬──────────────────────────────────────┘
                               │ (HttpOnly JWT Cookie)
                               ▼
┌────────────────────────────────────────────────────────────────────┐
│                       API Gateway (FastAPI)                        │
│  - Validação JWT                                                   │
│  - Decodificação de metadados                                      │
│  - Injeção de headers (X-User-Id, X-User-Role)                     │
│  - Rate limiting                                                   │
└──────────┬────────────────────────────┬────────────────────────────┘
           │                            │
           ▼                            ▼
┌──────────────────────┐    ┌───────────────────────────────────┐
│   Auth Service       │    │   Core Management API             │
│   (FastAPI)          │    │   (FastAPI)                       │
│   - User CRUD        │    │   - Vagas CRUD                    │
│   - JWT Emission     │    │   - Upload PDF → S3               │
│   - PostgreSQL       │    │   - Publish RabbitMQ              │
└──────────────────────┘    └─────────┬─────────────────────────┘
                                    │ (upload)
                                    ▼
                         ┌───────────────────────┐
                         │  AWS Emulator (Floci) │
                         │  - S3 Bucket Storage  │
                         └───────────────────────┘
                                    │ (event)
                                    ▼
                         ┌──────────────────────────────┐
                         │   Agent Worker Service       │
                         │   (Python + CrewAI)          │
                         │   - Consume RabbitMQ         │
                         │   - Download PDF from S3     │
                         │   - Vector Search (pgvector) │
                         │   - CrewAI Orchestration     │
                         │   - Save Status to Valkey    │
                         └──────────────────────────────┘
```

### Stack Tecnológica

| Componente | Tecnologia | Motivo da Escolha |
|------------|-----------|-------------------|
| **APIs Backend** | Python 3.11+ / FastAPI | Assíncrono, Pydantic v2, ecossistema maduro |
| **Frontend** | Next.js v14+ (App Router) | SSR/ISR híbrido, performance, SEO |
| **IA & Agentes** | CrewAI | Orquestração de agents LLM, toolkit completo |
| **Banco Dados** | PostgreSQL + pgvector | Relacional + busca vetorial em único banco |
| **Mensageria** | RabbitMQ | Event-driven, confiável, apropriado para processamento assíncrono |
| **Cache** | Valkey (Redis) | Persistência de status, alta performance |
| **Storage** | AWS S3 (Floci local em desenvolvimento, AWS S3 em produção) | Armazenamento escalável de arquivos |
| **Observabilidade Local** | Prometheus + Grafana + Loki | Stack open-source madura, zero custo local |
| **Observabilidade AWS** | CloudWatch + X-Ray | Nativo AWS, integração completa com infraestrutura |

---

## 🔐 Segurança & LGPD

### Privacy by Design

O sistema foi projetado com **conformidade LGPD desde o início**:

1. **Anonimização e Higienização**
   - Dados de currículos são descaracterizados antes do processamento por LLMs
   - Remoção de CPFs, e-mails e nomes brutos do contexto enviado à IA

2. **Criptografia em Repouso (Crypto-at-Rest)**
   - Dados PII salvos no PostgreSQL são criptografados a nível de coluna
   - Uso de AES-256 para criptografia simétrica

3. **Envelope Encryption**
   - Chaves de criptografia de dados (DEKs) exclusivas por candidato
   - DEKs cifradas por Chave Mestra (KEK) gerenciada via AWS KMS
   - Chaves nunca expostas em logs ou persistidas com dados

4. **Isolamento de Rede**
   - Apenas API Gateway e Frontend expostos externamente
   - Serviços internos em rede Docker privada
   - Tokens JWT como HttpOnly cookies

---

## 📊 Observabilidade

### Estratégia Dual-Stack

```
DESENVOLVIMENTO (Local)              PRODUÇÃO (AWS)
┌──────────────────────┐              ┌───────────────────────┐
│   Prometheus         │              │  CloudWatch Metrics   │
│   Grafana            │              │  CloudWatch Logs      │
│   Loki               │              │  AWS X-Ray            │
│   Tempo/Jaeger       │              │  CloudWatch Alarms    │
│   Uptime Kuma        │              │  CloudWatch Synthetics│
└──────────────────────┘              └───────────────────────┘
```

| Aspecto | Desenvolvimento | Produção |
|---------|----------------|-----------|
| Métricas | Prometheus | CloudWatch Metrics |
| Logs | Loki | CloudWatch Logs |
| Tracing | Tempo/Jaeger | AWS X-Ray |
| Dashboards | Grafana | CloudWatch Dashboards |
| Alertas | Alertmanager | CloudWatch Alarms |
| Uptime | Uptime Kuma | CloudWatch Synthetics |
| Frontend | Web Vitals | CloudWatch RUM |

**Métricas de IA (CrewAI) Específicas:**
- Tempo de execução por agent
- Consumo de tokens por modelo
- Taxa de sucesso/falha por agent
- Tempo de processamento de PDF
- Latência de busca vetorial
- Profundidade da fila RabbitMQ

---

## 🗂️ Estrutura do Projeto

```
safehire-ai-platform/
├── plans/                          # Planos de execução
│   ├── plano-geral-execucao.md     # Roadmap global do projeto
│   ├── docker-compose/             # Plano da infraestrutura Docker
│   └── observability/              # Plano de observabilidade
├── auth-service/                   # Microsserviço de autenticação
│   ├── plans/
│   ├── app/
│   ├── tests/
│   ├── Dockerfile
│   └── requirements.txt
├── api-gateway/                    # Gateway e roteamento
│   ├── plans/
│   ├── app/
│   ├── tests/
│   ├── Dockerfile
│   └── requirements.txt
├── core-management-api/            # API core de negócio
│   ├── plans/
│   ├── app/
│   ├── tests/
│   ├── Dockerfile
│   └── requirements.txt
├── agent-worker-service/           # Worker de IA (CrewAI)
│   ├── plans/
│   ├── app/
│   ├── tests/
│   ├── Dockerfile
│   └── requirements.txt
├── frontend-app/                   # Aplicação Next.js
│   ├── plans/
│   ├── app/
│   ├── components/
│   ├── tests/
│   ├── Dockerfile
│   └── package.json
├── docker-compose.yml              # Orquestração local
├── Makefile                        # Comandos úteis
├── .env.example                    # Variáveis de ambiente
├── CLAUDE.md                       # Regras de código (Git submodule)
├── PROJECT_CONTEXT.md              # Especificações de arquitetura
└── README.md                       # Este arquivo
```

---

## 🚀 Quick Start

### Pré-requisitos

- Docker e Docker Compose
- Python 3.11+ (para desenvolvimento local)
- Node.js 20+ (para desenvolvimento local)
- Git

> ⚙️ **Ambiente**: em desenvolvimento utilizamos o **Floci** como emulador local de todos os serviços AWS (S3, RDS, SQS, ElastiCache). Em produção, os mesmos serviços apontam para a AWS real via os endpoints padrão.

### Iniciar Localmente

```bash
# Clonar o projeto
git clone git@github.com:lpcoutinho/safehire-ai-platform.git
cd safehire-ai-platform

# Inicializar submódulos
git submodule update --init --recursive

# Copiar variáveis de ambiente
cp .env.example .env

# Iniciar infraestrutura completa
make up

# Acessar serviços
make help  # Ver todos os comandos disponíveis
```

### Serviços Disponíveis

| Serviço | URL | Credenciais |
|---------|-----|-------------|
| Frontend | http://localhost:3000 | - |
| API Gateway | http://localhost:8000 | - |
| Auth Service | http://localhost:8001 | - |
| Core API | http://localhost:8002 | - |
| RabbitMQ Management | http://localhost:15672 | guest/guest |
| Grafana | http://localhost:3001 | admin/admin |
| Prometheus | http://localhost:9090 | - |
| Uptime Kuma | http://localhost:3002 | admin/admin |

---

## 🔄 Fluxo de Candidatura

```
1. Candidato acessa /vagas
   ↓
2. Escolhe vaga e clica em "Aplicar"
   ↓
3. Preenche formulário e faz upload de PDF
   ↓
4. Core API salva no S3 e publica evento RabbitMQ
   ↓
5. Agent Worker consome evento e processa:
   ├─ Baixa PDF do S3
   ├─ Extrai texto e gera embeddings
   ├─ Gatekeeper Agent: valida segurança
   ├─ RAG Specialist: busca vetorial de requisitos
   └─ Artifact Writer: consolida resultado
   ↓
6. Status atualizado no Valkey (frontend poll)
   ↓
7. Candidato acessa /processo/[id]/guia
   ↓
8. Recrutador acessa /admin/candidatos/[id]
   ↓
9. Visualiza dossiê completo com gaps e roteiro de entrevista
```

---

## 🤖 Agents CrewAI

### Pipeline de Processamento

O `agent-worker-service` orquestra três agents especializados:

#### 1. Gatekeeper Agent
- **Objetivo:** Sanitizar input e detectar *Indirect Prompt Injection*
- **Ação:** Isola contexto em tags XML `<curriculo>`
- **Output:** Flag de injeção + justificativa

#### 2. RAG Specialist Agent
- **Objetivo:** Mapear requisitos da vaga contra currículo
- **Ação:** Usa pgvector para busca semântica com similaridade de cosseno
- **Output:** Análise de compatibilidade e gaps identificados

#### 3. Artifact Writer Agent
- **Objetivo:** Consolidar insights em formato estruturado
- **Ação:** Valida contra schema Pydantic
- **Output:** `ResultadoProcessoSeletivo` completo

### Métricas dos Agents

```python
# Métricas coletadas via OpenTelemetry
- crewai_agent_execution_seconds{agent_name, task_name, status}
- crewai_agent_tokens_total{agent_name, model}
- crewai_agent_success_rate{agent_name}
- crewai_pdf_processing_seconds
- crewai_embedding_generation_seconds{model}
- crewai_vector_search_seconds
```

---

## 🧪 Testes

### Executar Testes

```bash
# Testes de todos os serviços
make test

# Testes específicos por serviço
docker-compose run --rm auth-service pytest
docker-compose run --rm agent-worker-service pytest

# Testes E2E com Playwright
docker-compose run --rm frontend-app npm run test:e2e

# Coverage
make test  # Inclui relatório de coverage
```

### Estratégia de Testes (F.I.R.S.T)

- **Fast:** Testes rápidos (< 100ms)
- **Independent:** Sem dependências entre testes
- **Repeatable:** Determinísticos em qualquer ambiente
- **Self-validating:** Pass/fail claro
- **Timely:** Escritos juntamente com código

### Fakes para I/O Externo

- `FakeS3Service` - Mock para operações S3
- `FakeRabbitMQConsumer` - Mock para consumo RabbitMQ
- `FakeValkeyService` - Mock para cache
- `FakePostgresSession` - Mock para PostgreSQL
- `FakeCrewAIService` - Mock para agents CrewAI

---

## 📚 Documentação

- `PROJECT_CONTEXT.md` - Especificações completas de arquitetura
- `plans/plano-geral-execucao.md` - Roadmap global do projeto
- `plans/observability/plano-execucao.md` - Plano detalhado de observabilidade
- `[service]/plans/` - Planos específicos por serviço
- `CLAUDE.md` - Regras de desenvolvimento (em cada submódulo)

---

## 🛠️ Comandos Úteis

```bash
# Infraestrutura
make up                  # Iniciar todos os serviços
make down                # Parar todos os serviços
make ps                  # Ver status dos containers
make logs                # Ver logs de todos os serviços
make build               # Rebuildar imagens

# Observabilidade
make grafana             # Abrir Grafana
make prometheus          # Abrir Prometheus
make uptime-kuma         # Abrir Uptime Kuma

# Desenvolvimento
make shell-auth          # Shell no auth-service
make shell-core          # Shell no core-management-api
make shell-worker        # Shell no agent-worker-service
make db-shell            # Shell no PostgreSQL
make valkey-shell        # Shell no Valkey

# Código
make lint                # Rodar linting
make format              # Formatar código
make test                # Rodar testes
```

---

## 🔑 Variáveis de Ambiente

```env
# PostgreSQL
POSTGRES_USER=safehire
POSTGRES_PASSWORD=safehire_password
POSTGRES_DB=safehire

# RabbitMQ
RABBITMQ_USER=guest
RABBITMQ_PASSWORD=guest

# JWT
JWT_SECRET_KEY=change-in-production

# OpenAI (CrewAI)
OPENAI_API_KEY=sk-...

# AWS (Produção)
AWS_ACCESS_KEY_ID=...
AWS_SECRET_ACCESS_KEY=...
AWS_REGION=us-east-1

# Observabilidade
OBSERVABILITY_STACK=local|aws|hybrid
ENV=development|staging|production
```

---

## 🤝 Contribuindo

1. Fork o projeto
2. Crie branch para sua feature (`git checkout -b feature/NovaFeature`)
3. Commit suas mudanças (`git commit -m 'Add NovaFeature'`)
4. Push para o branch (`git push origin feature/NovaFeature`)
5. Abra um Pull Request

---

## 📞 Suporte

Para questões ou suporte, abra uma issue no GitHub ou contate o desenvolvedor no [Linkedin](https://www.linkedin.com/in/luizpaulocoutinho/).