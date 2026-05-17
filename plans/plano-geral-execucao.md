# SafeHire AI Platform - Plano de Execução Completo

## Visão Geral

O **SafeHire AI** é uma plataforma corporativa distribuída baseada em microsserviços para automação do pipeline de recrutamento técnico. O projeto combina inteligência artificial agêntica (CrewAI), busca vetorial (pgvector) e arquitetura orientada a eventos para criar uma experiência transparente e eficiente para candidatos e recrutadores.

### Estado Atual do Projeto
- ✅ Arquitetura definida (PROJECT_CONTEXT.md)
- ✅ Estrutura de diretórios de submódulos criada
- ✅ Arquivos CLAUDE.md de cada serviço com diretrizes de desenvolvimento
- ⏳ **A Fazer**: Todo o código fonte, infraestrutura, testes e CI/CD

### Arquitetura de Microsserviços

```
┌─────────────────────────────────────────────────────────────────┐
│                         EXTERNAL WORLD                          │
└──────────────────────────────┬──────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Frontend App (Next.js)                      │
│  - SSR/ISR: /vagas, /vagas/[id], /vagas/[id]/aplicar            │
│  - CSR: /admin, /admin/vagas/nova, /admin/candidatos/[id]        │
└──────────────────────────────┬──────────────────────────────────┘
                               │ (HttpOnly JWT Cookie)
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│                     API Gateway (FastAPI)                        │
│  - Validação de JWT, roteamento inteligente, security layer      │
└────────────┬──────────────────────────────────┬─────────────────┘
             │                                  │
             ▼                                  ▼
┌──────────────────────┐            ┌────────────────────────────┐
│   Auth Service       │            │   Core Management API      │
│   (FastAPI)          │            │   (FastAPI)                 │
│   - User CRUD        │            │   - Vagas CRUD              │
│   - JWT Emission     │            │   - Upload PDF → S3         │
│   - PostgreSQL       │            │   - Publish RabbitMQ        │
└──────────────────────┘            └────────────┬───────────────┘
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
                                    │   - CrewAI Orchestration    │
                                    │   - Save Status to Valkey   │
                                    └──────────────────────────────┘
```

---

## Stack Tecnológica Consolidada

| Componente | Tecnologia | Propósito |
|------------|-----------|-----------|
| **APIs de Backend** | Python 3.11+ / FastAPI | Assíncrono, Pydantic v2, boto3 para AWS |
| **Frontend App** | Next.js v14+ (App Router) | TypeScript, Tailwind CSS, Shadcn/ui |
| **IA & Agentes** | CrewAI | Processamento agêntico isolado |
| **Emulador Cloud** | Floci (Docker) | S3 local (porta 4566) |
| **Banco Relacional** | PostgreSQL | Esquemas isolados por serviço |
| **Banco Vetorial** | pgvector | Busca semântica no agent-worker |
| **Mensageria** | RabbitMQ | Event-driven entre Core e Workers |
| **Cache** | Valkey | Status de processamento, cache de relatórios |
| **Contêineres** | Docker Compose | Orquestração do ambiente local |

---

## Roadmap de Execução Global

### Fase 1: Infraestrutura e Configuração (Week 1-2)
#### 1.1 Infraestrutura Base Docker
- [ ] Criar `docker-compose.yml` na raiz com todos os serviços
- [ ] Configurar rede Docker interna segura
- [ ] Configurar Floci (AWS Emulator) com bucket S3
- [ ] Configurar PostgreSQL com múltiplos schemas
- [ ] Configurar RabbitMQ com filas definidas
- [ ] Configurar Valkey para cache
- [ ] Criar Dockerfiles para cada serviço
- [ ] Criar `requirements.txt` para cada serviço Python
- [ ] Criar `package.json` para frontend-app

#### 1.2 Configuração de Desenvolvimento
- [ ] Criar `.env.example` na raiz
- [ ] Criar `.env.example` em cada serviço
- [ ] Configurar health checks para cada serviço
- [ ] Configurar logs estruturados JSON
- [ ] Criar Makefile para comandos comuns
- [ ] Configurar `black` e `isort` para Python
- [ ] Configurar `prettier` e `eslint` para Next.js

### Fase 2: CI/CD Pipeline (Week 2-3)
#### 2.1 GitHub Actions
- [ ] Criar workflow de linting para Python
- [ ] Criar workflow de linting para TypeScript
- [ ] Criar workflow de testes unitários
- [ ] Criar workflow de testes de integração
- [ ] Criar workflow de build Docker
- [ ] Criar workflow de security scan (SAST)
- [ ] Criar workflow de dependecy check (SCA)
- [ ] Criar workflow de deployment staging

#### 2.2 Configuração de Quality Gates
- [ ] Configurar Codecov para coverage
- [ ] Configurar SonarQube (opcional)
- [ ] Definir métricas de qualidade mínimas
- [ ] Configurar pre-commit hooks

### Fase 3: Auth Service (Week 3-4)
#### 3.1 Implementação Core
- [ ] Criar estrutura de pastas do projeto
- [ ] Implementar modelos Pydantic de entrada/saída
- [ ] Implementar conexão PostgreSQL com `auth_schema`
- [ ] Implementar CRUD de usuários (recrutadores e candidatos)
- [ ] Implementar geração de tokens JWT
- [ ] Implementar refresh tokens
- [ ] Implementar endpoints de registro
- [ ] Implementar endpoints de login
- [ ] Implementar endpoints de logout
- [ ] Implementar recuperação de senha
- [ ] Implementar middleware de autenticação

#### 3.2 Testes Auth Service
- [ ] Testes unitários de models Pydantic
- [ ] Testes unitários de utilitários JWT
- [ ] Testes de integração de CRUD usuários
- [ ] Testes de integração de autenticação
- [ ] Testes de integração de autorização
- [ ] Testes de carga (load testing)
- [ ] Fake classes para I/O externo

### Fase 4: API Gateway (Week 4-5)
#### 4.1 Implementação Core
- [ ] Criar estrutura de pastas do projeto
- [ ] Implementar validador de JWT
- [ ] Implementar decodificação de tokens
- [ ] Implementar roteamento inteligente para auth-service
- [ ] Implementar roteamento inteligente para core-management-api
- [ ] Implementar injeção de headers `X-User-Id`, `X-User-Role`
- [ ] Implementar middleware de segurança
- [ ] Implementar rate limiting
- [ ] Implementar CORS apropriado
- [ ] Implementar health check endpoint

#### 4.2 Testes API Gateway
- [ ] Testes unitários de validação JWT
- [ ] Testes de roteamento
- [ ] Testes de injeção de headers
- [ ] Testes de middleware de segurança
- [ ] Testes de rate limiting

### Fase 5: Core Management API (Week 5-7)
#### 5.1 Implementação Core
- [ ] Criar estrutura de pastas do projeto
- [ ] Implementar modelos Pydantic de vagas
- [ ] Implementar modelos Pydantic de candidatos
- [ ] Implementar conexão PostgreSQL com `core_schema`
- [ ] Criar adapter boto3 para S3 (Floci)
- [ ] Implementar CRUD completo de vagas
- [ ] Implementar endpoint de upload de currículo
- [ ] Implementar processamento de upload S3
- [ ] Implementar publicação de eventos RabbitMQ
- [ ] Implementar endpoint de consulta de status
- [ ] Implementar listagem de vagas públicas
- [ ] Implementar endpoint de criação de candidato
- [ ] Implementar gerenciamento de processo seletivo

#### 5.2 Testes Core Management API
- [ ] Testes unitários de models Pydantic
- [ ] Testes unitários de adapter S3
- [ ] Testes de integração de CRUD vagas
- [ ] Testes de integração de upload
- [ ] Testes de integração RabbitMQ
- [ ] Fakes para S3, PostgreSQL, RabbitMQ

### Fase 6: Agent Worker Service (Week 7-9)
#### 6.1 Implementação Core
- [ ] Criar estrutura de pastas do projeto
- [ ] Configurar pgvector no PostgreSQL
- [ ] Implementar consumo RabbitMQ
- [ ] Implementar download de PDF do S3
- [ ] Implementar extrator de texto PDF
- [ ] Implementar gerador de embeddings
- [ ] Implementar busca vetorial com pgvector
- [ ] Criar adapter CrewAI
- [ ] Implementar Gatekeeper Agent (anti-injection)
- [ ] Implementar RAG Specialist Agent (busca vetorial)
- [ ] Implementar Artifact Writer Agent (consolidação)
- [ ] Implementar schema Pydantic `ResultadoProcessoSeletivo`
- [ ] Implementar salvamento de status no Valkey
- [ ] Implementar tratamento de erros e retries

#### 6.2 Testes Agent Worker Service
- [ ] Testes unitários de extrator PDF
- [ ] Testes unitários de gerador embeddings
- [ ] Testes de integração RabbitMQ
- [ ] Testes de integração pgvector
- [ ] Testes e2e do pipeline agêntico
- [ ] Fakes para S3, PostgreSQL, RabbitMQ, Valkey, CrewAI

### Fase 7: Frontend App (Week 9-11)
#### 7.1 Setup e Configuração
- [ ] Inicializar projeto Next.js v14+ com App Router
- [ ] Configurar TypeScript estrito
- [ ] Instalar e configurar Tailwind CSS
- [ ] Instalar e configurar Shadcn/ui
- [ ] Criar estrutura de pastas do projeto
- [ ] Configurar camada de API client
- [ ] Configurar gerenciamento de cookies HttpOnly
- [ ] Criar context providers globais

#### 7.2 Páginas Públicas do Candidato (SSR/ISR)
- [ ] `/vagas` - Listagem de vagas com filtros
- [ ] `/vagas/[id]` - Detalhes da vaga
- [ ] `/vagas/[id]/aplicar` - Formulário de inscrição
- [ ] `/processo/[candidato_id]/questionario` - Perguntas técnicas dinâmicas
- [ ] `/processo/[candidato_id]/guia` - Guia de estudos personalizado
- [ ] Implementar loading states
- [ ] Implementar error boundaries
- [ ] Implementar polling de status via Valkey

#### 7.3 Páginas Privadas do Recrutador (CSR)
- [ ] `/admin` - Dashboard consolidado
- [ ] `/admin/vagas/nova` - Criação de vagas
- [ ] `/admin/vagas/[id]/editar` - Edição de vagas
- [ ] `/admin/candidatos` - Listagem de candidatos
- [ ] `/admin/candidatos/[id]` - Dossiê do candidato
  - Destaque de gaps
  - Roteiro de entrevista estruturado
  - Métricas de risco
- [ ] Implementar tabelas com paginação
- [ ] Implementar gráficos de métricas

#### 7.4 Testes Frontend App
- [ ] Testes de componentes com Vitest
- [ ] Testes E2E com Playwright
- [ ] Testes de acessibilidade
- [ ] Testes de responsividade

### Fase 8: Integração e Homologação (Week 11-12)
#### 8.1 Integração End-to-End
- [ ] Teste completo do fluxo do candidato
  - Listar vagas
  - Candidatar-se
  - Upload de currículo
  - Aguardar processamento
  - Visualizar guia de estudos
- [ ] Teste completo do fluxo do recrutador
  - Criar vaga
  - Visualizar candidatos
  - Analisar dossiê
  - Usar roteiro de entrevista
- [ ] Teste de autenticação entre serviços
- [ ] Teste de roteamento do API Gateway
- [ ] Teste de processamento assíncrono

#### 8.2 Performance e Monitoramento
- [ ] Implementar métricas Prometheus
- [ ] Implementar traces OpenTelemetry
- [ ] Implementar logs estruturados centralizados
- [ ] Configurar alertas
- [ ] Teste de carga (load testing)
- [ ] Otimização de queries PostgreSQL
- [ ] Otimização de embeddings

#### 8.3 Documentação Final
- [ ] Documentação de API (OpenAPI/Swagger)
- [ ] Guia de instalação local
- [ ] Guia de deploy em staging
- [ ] Guia de deploy em produção
- [ ] Diagramas atualizados
- [ ] Runbooks de troubleshooting

---

## Checklist de Validação por Categoria

### 🔧 Infraestrutura
- [ ] Docker Compose sobe todos os serviços sem erros
- [ ] Health checks respondem para todos os serviços
- [ ] Floci S3 aceita uploads e downloads
- [ ] PostgreSQL schemas criados corretamente
- [ ] pgvector extension habilitada
- [ ] RabbitMQ filas criadas e acessíveis
- [ ] Valkey aceita conexões e operações
- [ ] Rede Docker isolada funciona
- [ ] Logs são estruturados em JSON

### 🚀 CI/CD
- [ ] Linting Python (black, isort, pylint/mypy)
- [ ] Linting TypeScript (eslint, prettier)
- [ ] Todos os testes passam em CI
- [ ] Coverage mínimo 80%
- [ ] Security scans executam em cada PR
- [ ] Docker images são construídas
- [ ] Pre-commit hooks funcionam
- [ ] Dependecy check executam

### 🧪 Testes
- [ ] Cada serviço tem testes unitários
- [ ] Cada serviço tem testes de integração
- [ ] Fakes implementados para I/O externo
- [ ] Testes E2E cobrem fluxos principais
- [ ] Testes de carga executam sem falhas
- [ ] Testes de segurança implementados

### 💻 Código
- [ ] Funções têm 4-20 linhas
- [ ] Arquivos têm menos de 500 linhas
- [ ] Nomes são únicos e específicos (anti-grep)
- [ ] Tipagem estrita (sem `any`)
- [ ] Early returns implementados
- [ ] Exceções semânticas
- [ ] Docstrings em funções públicas
- [ ] Comentários explicam POR QUE

### 🔒 Segurança
- [ ] HttpOnly cookies no frontend
- [ ] JWT assinado e validado
- [ ] Rate limiting implementado
- [ ] CORS configurado corretamente
- [ ] Sensitive data em env vars
- [ ] SQL injection prevenido
- [ ] XSS prevenido
- [ ] CSRF tokens onde aplicável
- [ ] Gatekeeper Agent previne prompt injection

### 📊 Observabilidade
- [ ] Logs estruturados em todos os serviços
- [ ] Métricas Prometheus expostas
- [ ] Traces OpenTelemetry configurados
- [ ] Health checks padrão
- [ ] Alertas configurados

---

## Arquivos Críticos a Serem Criados

### Raiz do Projeto
```
/home/lpcoutinho/projects/safehire-ai-platform/
├── docker-compose.yml
├── .env.example
├── Makefile
├── .github/workflows/
│   ├── lint-python.yml
│   ├── lint-typescript.yml
│   ├── test-python.yml
│   ├── test-typescript.yml
│   ├── security-scan.yml
│   └── deploy.yml
├── plans/
│   ├── plano-geral-execucao.md (este arquivo)
│   ├── auth-service/
│   │   └── plano-execucao.md
│   ├── api-gateway/
│   │   └── plano-execucao.md
│   ├── core-management-api/
│   │   └── plano-execucao.md
│   ├── agent-worker-service/
│   │   └── plano-execucao.md
│   └── frontend-app/
│       └── plano-execucao.md
```

### Por Serviço
Cada serviço terá seu próprio plano detalhado seguindo o padrão:
1. **Visão Geral** - Contexto e propósito
2. **Roadmap** - Fases e tarefas
3. **TodoList** - Checklist de implementação
4. **Arquivos a Criar** - Lista de arquivos com caminho
5. **Validação** - Critérios de aceitação

---

## Próximos Passos Imediatos

1. Criar plano detalhado para `auth-service/`
2. Criar plano detalhado para `api-gateway/`
3. Criar plano detalhado para `core-management-api/`
4. Criar plano detalhado para `agent-worker-service/`
5. Criar plano detalhado para `frontend-app/`
6. Criar `docker-compose.yml` inicial na raiz
7. Configurar workflows de CI/CD

---

## Critérios de Sucesso

O projeto será considerado completo quando:

✅ Todos os 5 microsserviços estiverem funcionando localmente via Docker Compose
✅ Todo o fluxo do candidato (inscrição → processamento → guia) funcionar end-to-end
✅ Todo o fluxo do recrutador (criar vaga → ver candidatos → usar dossiê) funcionar end-to-end
✅ Todos os testes tiverem coverage mínimo de 80%
✅ Pipeline de CI/CD estiver funcionando
✅ Documentação completa estiver disponível
✅ Checklist de validação estiver 100% concluído

---

## Referências

- `PROJECT_CONTEXT.md` - Especificações de arquitetura
- `CLAUDE.md` - Diretrizes de desenvolvimento
- `submodules.md` - Guia de submódulos Git