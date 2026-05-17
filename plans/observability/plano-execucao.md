# Plano de Observabilidade - SafeHire AI Platform

## Contexto

O projeto SafeHire AI atualmente não possui uma camada de observabilidade estruturada. Com uma arquitetura de microsserviços distribuída, processamento assíncrono e IA agêntica, é essencial implementar observabilidade completa para:

1. **Monitorar a saúde dos serviços** em tempo real
2. **Rastrear requisições** entre serviços (distributed tracing)
3. **Coletar métricas** de performance e recursos
4. **Centralizar logs** para análise e debugging
5. **Detectar anomalias** no processamento de IA
6. **Garantir uptime** com alertas automáticos

---

## Arquitetura de Observabilidade Proposta

### Stack de Desenvolvimento (Local)

```
┌─────────────────────────────────────────────────────────────────────┐
│              LAYER DE OBSERVABILIDADE LOCAL (DEV)                   │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌─────────┐  │
│  │  GRAFANA     │  │  UPTIME KUMA │  │  PROMETHEUS  │  │ JAEGER  │  │
│  │  :3001       │  │  :3002       │  │  :9090       │  │ :16686  │  │
│  │  Dashboards  │  │  Monitors    │  │  Metrics     │  │ Tracing │  │
│  └──────┬───────┘  └──────────────┘  └──────┬───────┘  └────┬────┘  │
│         │                                  │              │         │
│         └──────────────────────────────────┼──────────────┘         │
│                                            │                        │
│         ┌──────────────────────────────────┼──────────────┐         │
│         │                                  │              │         │
│  ┌──────▼──────┐  ┌──────────────┐  ┌──────▼──────┐  ┌──▼───────┐   │
│  │   LOKI      │  │   TEMPO      │  │  ALERTMGR   │  │ OTEL     │   │
│  │  :3100      │  │  :3200       │  │  :9093      │  │ Collector│   │
│  │  Logs       │  │  Distributed │  │  Alerts     │  │ :4317    │   │
│  └─────────────┘  │  Tracing     │  └─────────────┘  └──────────┘   │
│                   └──────────────┘                                  │
└─────────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────────┐
│                    SERVIÇOS DA APLICAÇÃO (LOCAL)                    │
│  (com instrumentação OpenTelemetry)                                 │
├─────────────────────────────────────────────────────────────────────┤
│  auth-service | api-gateway | core-api | agent-worker | frontend    │
└─────────────────────────────────────────────────────────────────────┘
```

### Stack de Produção (AWS)

```
┌───────────────────────────────────────────────────────────────────┐
│              LAYER DE OBSERVABILIDADE PRODUÇÃO (AWS)              │
├───────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌─────────────────────────────────────────────────────────────┐  │
│  │                    AWS CLOUDWATCH                           │  │
│  ├─────────────────────────────────────────────────────────────┤  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │  │
│  │  │    Logs      │  │   Metrics    │  │   Alarms     │       │  │
│  │  │  (CloudWatch │  │  (CloudWatch │  │  (CloudWatch │       │  │
│  │  │   Logs)      │  │   Metrics)   │  │   Alarms)    │       │  │
│  │  └──────────────┘  └──────────────┘  └──────────────┘       │  │
│  │                                                             │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │  │
│  │  │    Traces    │  │  Dashboards  │  │  Insights    │       │  │
│  │  │  (X-Ray)     │  │  (CloudWatch │  │  (Logs       │       │  │
│  │  │              │  │   Dashboards)│  │   Insights)  │       │  │
│  │  └──────────────┘  └──────────────┘  └──────────────┘       │  │
│  │                                                             │  │
│  │  ┌──────────────┐  ┌──────────────┐                         │  │
│  │  │  RUM (Real   │  │   SRE (Site   │                        │  │
│  │  │   User       │  │   Reliability)│                        │  │
│  │  │   Monitoring)│  │                │                       │  │
│  │  └──────────────┘  └──────────────┘                         │  │
│  └─────────────────────────────────────────────────────────────┘  │
│                              ↓                                    │
│  ┌─────────────────────────────────────────────────────────────┐  │
│  │              AWS INFRASTRUCTURE (PROD)                      │  │
│  ├─────────────────────────────────────────────────────────────┤  │
│  │  ECS/Fargate | API Gateway | Lambda | S3 | SQS | RDS |      │  │
│  └─────────────────────────────────────────────────────────────┘  │
└───────────────────────────────────────────────────────────────────┘
```

### Estratégia Dual-Stack

```
                    ┌─────────────────┐
                    │   APLICAÇÃO     │
                    │   (Python/TS)   │
                    └────────┬────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
              ▼              ▼              ▼
    ┌─────────────┐  ┌─────────────┐  ┌─────────────┐
    │  DEVELOPMENT│  │   STAGING   │  │  PRODUCTION │
    │    (Local)  │  │    (AWS)    │  │    (AWS)    │
    └─────────────┘  └─────────────┘  └─────────────┘
              │              │               │
    ┌─────────▼─────┐  ┌─────▼──────┐  ┌─────▼──────┐
    │ Prometheus +  │  │ Prometheus │  │ CloudWatch │
    │ Grafana Local │  │  + Grafana │  │    + X-Ray │
    └───────────────┘  └────────────┘  └────────────┘
```

**Ambiente**: Variável `ENV=development|staging|production` determina a stack de observabilidade.

---

## Serviços de Observabilidade a Adicionar

### Stack Local (Desenvolvimento)

| Serviço | Porta | Propósito | Stack |
|---------|-------|-----------|-------|
| **Prometheus** | 9090 | Coleta de métricas | Metrics |
| **Grafana** | 3001 | Visualização e dashboards | Visualization |
| **Loki** | 3100 | Agregação de logs estruturados | Logging |
| **Tempo** | 3200 | Distributed tracing com OpenTelemetry | Tracing |
| **Jaeger** | 16686 | Visualização de traces | Tracing UI |
| **Alertmanager** | 9093 | Gerenciamento de alertas | Alerting |
| **Uptime Kuma** | 3002 | Monitoramento de uptime e status | Uptime Monitor |
| **OpenTelemetry Collector** | 4317 | Coleta centralizada de traces/metrics/logs | OTEL |

### Stack AWS (Produção)

| Serviço AWS | Propósito | Complemento AWS |
|-------------|-----------|------------------|
| **CloudWatch Metrics** | Coleta de métricas nativas + customizadas | - |
| **CloudWatch Logs** | Agregação de logs estruturados | CloudWatch Logs Insights |
| **AWS X-Ray** | Distributed tracing entre serviços | Service Map |
| **CloudWatch Dashboards** | Visualização em tempo real | - |
| **CloudWatch Alarms** | Alertas baseados em métricas | SNS → Slack/Email |
| **CloudWatch Synthetics** | Uptime monitoring (canaries) | - |
| **CloudWatch RUM** | Real User Monitoring (frontend) | - |
| **Amazon Managed Prometheus** | Prometheus gerenciado (opcional) | - |
| **Amazon Managed Grafana** | Grafana gerenciado (opcional) | - |

**Nota sobre portas:**
- Grafana: 3001
- Uptime Kuma: 3002 (ajustado para evitar conflito)

---

## Roadmap de Implementação

### Fase 1: Infraestrutura de Observabilidade (Dia 1-2)

#### 1.1 Adicionar Serviços ao Docker Compose
- [ ] Adicionar Prometheus ao docker-compose.yml
- [ ] Adicionar Grafana ao docker-compose.yml
- [ ] Adicionar Loki ao docker-compose.yml
- [ ] Adicionar Tempo ao docker-compose.yml
- [ ] Adicionar Alertmanager ao docker-compose.yml
- [ ] Adicionar Uptime Kuma ao docker-compose.yml
- [ ] Adicionar OpenTelemetry Collector ao docker-compose.yml
- [ ] Criar network `observability-network`
- [ ] Criar volumes para persistência de dados

#### 1.2 Configuração de Prometheus
- [ ] Criar `monitoring/prometheus/prometheus.yml` com scrape configs
- [ ] Criar `monitoring/prometheus/alerts.yml` com regras de alerta
- [ ] Configurar scrape jobs para todos os serviços
- [ ] Configurar scraping de RabbitMQ metrics
- [ ] Configurar scraping de PostgreSQL metrics
- [ ] Configurar scraping de Valkey metrics

#### 1.3 Configuração de Grafana
- [ ] Criar `monitoring/grafana/datasources/` com datasource do Prometheus
- [ ] Criar `monitoring/grafana/dashboards/` com dashboards pré-configurados
- [ ] Configurar datasource Loki para logs
- [ ] Configurar datasource Tempo para traces
- [ ] Importar dashboards padrão (FastAPI, PostgreSQL, RabbitMQ)

#### 1.4 Configuração de Loki
- [ ] Criar `monitoring/loki/loki-config.yml`
- [ ] Configurar scraping de logs via promtail ou otel-collector
- [ ] Configurar retenção de logs

#### 1.5 Configuração de Tempo
- [ ] Criar `monitoring/tempo/tempo.yml`
- [ ] Configurar OpenTelemetry receiver
- [ ] Configurar storage

#### 1.6 Configuração de Alertmanager
- [ ] Criar `monitoring/alertmanager/config.yml`
- [ ] Configurar rotas de alerta
- [ ] Configurar receivers (email, Slack, etc.)

#### 1.7 Configuração de Uptime Kuma
- [ ] Criar volume para persistência do Uptime Kuma
- [ ] Configurar monitores para endpoints críticos
- [ ] Configurar notificações

---

### Fase 2: Instrumentação de Serviços (Dia 3-5)

#### 2.1 Configuração Base de Observabilidade (Python)
- [ ] Criar `observability/base_config.py` com configurações compartilhadas
- [ ] Criar `observability/metrics.py` com métricas padrão
- [ ] Criar `observability/tracing.py` com configuração de tracing
- [ ] Criar `observability/logging.py` com logger estruturado JSON
- [ ] Criar `observability/factory.py` - Factory pattern para escolha de stack

```python
# observability/factory.py
from typing import Literal
from observability.metrics_local import LocalMetrics
from observability.metrics_aws import CloudWatchMetrics
from observability.logging_local import LocalLogger
from observability.logging_aws import CloudWatchLogger
from observability.tracing_local import LocalTracer
from observability.tracing_aws import XRayTracer

ObservabilityStack = Literal['local', 'aws', 'hybrid']

def create_metrics(stack: ObservabilityStack, service_name: str):
    """Factory para criar cliente de métricas."""
    if stack in ['local', 'hybrid']:
        return LocalMetrics(service_name)
    elif stack == 'aws':
        return CloudWatchMetrics(f"SafeHire/{service_name}")
    else:
        raise ValueError(f"Invalid stack: {stack}")

def create_logger(stack: ObservabilityStack, service_name: str):
    """Factory para criar logger."""
    if stack in ['local', 'hybrid']:
        return LocalLogger(service_name)
    elif stack == 'aws':
        return CloudWatchLogger(f"/aws/ecs/{service_name}")
    else:
        raise ValueError(f"Invalid stack: {stack}")

def create_tracer(stack: ObservabilityStack, service_name: str):
    """Factory para criar tracer."""
    if stack in ['local', 'hybrid']:
        return LocalTracer(service_name)
    elif stack == 'aws':
        return XRayTracer(service_name)
    else:
        raise ValueError(f"Invalid stack: {stack}")
```

#### 2.2 Auth Service
- [ ] Adicionar dependências ao `requirements.txt`:
  - `prometheus-fastapi-instrumentator>=7.0.0`
  - `opentelemetry-api>=1.21.0`
  - `opentelemetry-sdk>=1.21.0`
  - `opentelemetry-instrumentation-fastapi>=0.42b0`
  - `opentelemetry-instrumentation-httpx>=0.42b0`
  - `opentelemetry-exporter-otlp>=1.21.0`
  - `python-json-logger>=2.0.7`
- [ ] Implementar middleware de métricas Prometheus
- [ ] Implementar middleware de tracing OpenTelemetry
- [ ] Configurar logger estruturado JSON
- [ ] Expor endpoint `/metrics`
- [ ] Adicionar health check `/health`

#### 2.3 API Gateway
- [ ] Adicionar dependências de observabilidade
- [ ] Implementar middleware de métricas
- [ ] Implementar middleware de tracing (distributed tracing)
- [ ] Configurar logger estruturado
- [ ] Adicionar métricas de rate limiting
- [ ] Adicionar health check

#### 2.4 Core Management API
- [ ] Adicionar dependências de observabilidade
- [ ] Implementar instrumentação de endpoints
- [ ] Implementar tracing de operações S3
- [ ] Implementar tracing de publicação RabbitMQ
- [ ] Adicionar métricas de upload
- [ ] Adicionar health check

#### 2.5 Agent Worker Service
- [ ] Adicionar dependências de observabilidade
- [ ] Implementar instrumentação de CrewAI agents
  - Métricas de tempo de execução por agent
  - Métricas de tokens consumidos
  - Métricas de success/failure rate
- [ ] Implementar tracing do pipeline de processamento
- [ ] Adicionar métricas de embeddings
- [ ] Adicionar métricas de vector search
- [ ] Adicionar health check

#### 2.6 Frontend App (Next.js)
- [ ] Adicionar `@opentelemetry/instrumentation` package
- [ ] Configurar tracing client-side
- [ ] Adicionar métricas de performance (Web Vitals)
- [ ] Integrar com Error Boundary para tracking de erros

---

### Fase 3: Dashboards e Alertas (Dia 5-6)

#### 3.1 Dashboards Grafana
- [ ] Criar dashboard `System Overview`:
  - CPU, Memory, Network por serviço
  - Request rate, error rate, latency
  - Health status de todos os serviços
- [ ] Criar dashboard `API Performance`:
  - Endpoints mais lentos
  - Error rate por endpoint
  - P95, P99 latência
- [ ] Criar dashboard `Database Performance`:
  - PostgreSQL query performance
  - Connection pool status
  - pgvector operations
- [ ] Criar dashboard `Message Queue`:
  - RabbitMQ queue depth
  - Consumer lag
  - Message rate
- [ ] Criar dashboard `AI Agents`:
  - Agent execution time
  - Token consumption
  - Success/failure rates
  - Embedding generation metrics

#### 3.2 Regras de Alerta Prometheus
- [ ] Alerta: Service Down (health check falhando)
- [ ] Alerta: High Error Rate (> 5% em 5 min)
- [ ] Alerta: High Latency (> 1s P95 em 5 min)
- [ ] Alerta: Memory Usage (> 80%)
- [ ] Alerta: CPU Usage (> 80%)
- [ ] Alerta: Queue Depth (RabbitMQ > 1000 mensagens)
- [ ] Alerta: Agent Failure Rate (> 10%)
- [ ] Alerta: Database Connection Pool Full

#### 3.3 Configuração de Uptime Kuma
- [ ] Monitor: API Gateway (http://api-gateway:8000/health)
- [ ] Monitor: Auth Service (http://auth-service:8000/health)
- [ ] Monitor: Core API (http://core-management-api:8000/health)
- [ ] Monitor: Frontend (http://frontend-app:3000)
- [ ] Monitor: PostgreSQL (postgres:5432)
- [ ] Monitor: RabbitMQ (rabbitmq:5672)
- [ ] Monitor: Valkey (valkey:6379)
- [ ] Configurar notificações (email/Slack)

---

### Fase 4: AWS CloudWatch - Produção (Dia 8-10)

#### 4.1 Infraestrutura AWS
- [ ] Criar bucket S3 para logs (opcional)
- [ ] Criar tópicos SNS para notificações
- [ ] Criar roles IAM para serviços ECS
- [ ] Criar Secrets Manager para credenciais
- [ ] Criar ECS task definitions com X-Ray sidecar
- [ ] Configurar log groups no CloudWatch Logs

#### 4.2 CloudWatch Integration (Python)
- [ ] Criar `observability/logging_aws.py` com CloudWatchLogsHandler
- [ ] Criar `observability/metrics_aws.py` com CloudWatchMetrics
- [ ] Criar `observability/tracing_aws.py` com X-Ray integration
- [ ] Criar `observability/alarms_aws.py` com alarmes
- [ ] Adicionar boto3 aos requirements.txt
- [ ] Adicionar aws-xray-sdk ao requirements.txt

#### 4.3 CloudWatch Dashboards (AWS)
- [ ] Criar script para gerar dashboard SafeHire-Overview
- [ ] Criar dashboard de API Performance
- [ ] Criar dashboard de AI Agents
- [ ] Criar dashboard de System Health
- [ ] Configurar widgets customizados

#### 4.4 CloudWatch Alarms (AWS)
- [ ] Criar alarme: Service Down (health check)
- [ ] Criar alarme: High Error Rate (>5%)
- [ ] Criar alarme: High Latency (>1s P95)
- [ ] Criar alarme: Queue Depth (>1000)
- [ ] Criar alarme: Agent Failure Rate (>10%)
- [ ] Criar alarme: RDS CPU >80%
- [ ] Criar alarme: ECS Task Failures
- [ ] Configurar SNS para Slack/Email

#### 4.5 CloudWatch Synthetics (Canaries)
- [ ] Criar canary para API Gateway health
- [ ] Criar canary para Auth Service health
- [ ] Criar canary para Core API health
- [ ] Criar canary para Frontend health
- [ ] Criar canary para login flow
- [ ] Criar canary para candidatura flow
- [ ] Configurar alertas dos canaries

#### 4.6 CloudWatch RUM (Frontend)
- [ ] Criar CloudWatch RUM app
- [ ] Configurar Identity Pool Cognito
- [ ] Integrar SDK no frontend-app
- [ ] Rastrear Web Vitals
- [ ] Rastrear erros JavaScript
- [ ] Rastrear performance de navegação

#### 4.7 AWS X-Ray
- [ ] Instalar X-Ray Daemon sidecar em ECS
- [ ] Instrumentar todas as chamadas HTTP
- [ ] Instrumentar chamadas S3
- [ ] Instrumentar chamadas SQS/RabbitMQ
- [ ] Instrumentar chamadas PostgreSQL
- [ ] Configurar service map
- [ ] Configurar sampling rate

---

### Fase 5: Melhores Práticas (Dia 10-12)

#### 4.1 Logs Estruturados
- [ ] Padronizar formato JSON de logs
- [ ] Adicionar campos obrigatórios: `timestamp`, `level`, `service`, `trace_id`, `span_id`
- [ ] Adicionar contextuais: `user_id`, `request_id`, `correlation_id`
- [ ] Configurar log levels apropriados por ambiente

#### 4.2 Tracing
- [ ] Configurar sampling rate (10% production, 100% dev)
- [ ] Adicionar span attributes padronizados
- [ ] Implementar baggage propagation entre serviços
- [ ] Configurar trace retention

#### 4.3 Metrics
- [ ] Definir nomenclatura padronizada (ex: `http_requests_total{method="GET",path="/api/vagas"}`)
- [ ] Usar tipos de métricas apropriados (Counter, Gauge, Histogram, Summary)
- [ ] Adicionar labels relevantes (service, endpoint, status_code, etc.)

#### 4.4 Error Tracking
- [ ] Configurar Sentry ou similar para exception tracking
- [ ] Adicionar contextos (user, request, environment)
- [ ] Configurar release tracking

#### 4.5 Documentation
- [ ] Criar `docs/observability.md` com guia de uso
- [ ] Documentar métricas disponíveis
- [ ] Documentar dashboards
- [ ] Criar runbook de troubleshooting
- [ ] Documentar switch entre stacks (dev/prod)
- [ ] Criar guia de migração para AWS

---

## Switch Automático entre Stacks

### Configuração Baseada em Ambiente

```python
# app/main.py
from os import getenv
from observability.factory import create_metrics, create_logger, create_tracer

ENV = getenv('ENV', 'development')
OBSERVABILITY_STACK = getenv('OBSERVABILITY_STACK', 'aws' if ENV == 'production' else 'local')

# Auto-select stack based on environment
if ENV == 'production':
    OBSERVABILITY_STACK = 'aws'
elif ENV == 'staging':
    OBSERVABILITY_STACK = 'hybrid'  # Local + AWS logs
else:
    OBSERVABILITY_STACK = 'local'

# Create observability clients
metrics = create_metrics(OBSERVABILITY_STACK, 'auth-service')
logger = create_logger(OBSERVABILITY_STACK, 'auth-service')
tracer = create_tracer(OBSERVABILITY_STACK, 'auth-service')
```

### Estratégias de Stack

| Estratégia | Local | Staging | Produção |
|------------|-------|---------|-----------|
| **local** | Prometheus/Loki/Tempo | - | - |
| **aws** | CloudWatch | CloudWatch | CloudWatch |
| **hybrid** | Prometheus/Loki | Prometheus + CloudWatch Logs | - |

**Recomendação:**
- **Desenvolvimento**: `local` - Stack completa local
- **Staging**: `hybrid` - Métricas locais + Logs AWS para debugging
- **Produção**: `aws` - Stack completa AWS nativa

### Arquivo de Configuração

```python
# observability/config.py
from pydantic_settings import BaseSettings

class ObservabilityConfig(BaseSettings):
    stack: str = 'local'
    environment: str = 'development'
    service_name: str = 'safehire'

    # Local stack
    prometheus_url: str = 'http://prometheus:9090'
    loki_url: str = 'http://loki:3100'
    tempo_url: str = 'http://tempo:3200'

    # AWS stack
    aws_region: str = 'us-east-1'
    cloudwatch_log_group: str = '/aws/ecs/safehire'
    xray_daemon_address: str = '127.0.0.1:2000'

    # General
    log_level: str = 'INFO'
    trace_sampling_rate: float = 1.0
    trace_timeout: int = 30

    class Config:
        env_prefix = 'OBSERVABILITY_'
        env_file = '.env'

config = ObservabilityConfig()
```

---

## Arquivos a Criar/Modificar

### Novos Arquivos

| Arquivo | Descrição |
|---------|-----------|
| `docker-compose.observability.yml` | Docker Compose completo com observabilidade |
| `monitoring/prometheus/prometheus.yml` | Configuração Prometheus |
| `monitoring/prometheus/alerts.yml` | Regras de alerta |
| `monitoring/grafana/datasources/prometheus.yml` | Datasource Prometheus |
| `monitoring/grafana/dashboards/*.json` | Dashboards Grafana |
| `monitoring/loki/loki-config.yml` | Configuração Loki |
| `monitoring/tempo/tempo.yml` | Configuração Tempo |
| `monitoring/alertmanager/config.yml` | Configuração Alertmanager |
| `.env.observability.example` | Variáveis de ambiente |
| `Makefile` (update) | Comandos de observabilidade |

### Arquivos a Modificar

| Arquivo | Modificações |
|---------|--------------|
| `docker-compose.yml` | Incluir services de observabilidade (dev) |
| `docker-compose.aws.yml` | Configuração para produção AWS |
| `.env.observability.example` | Variáveis de ambiente |
| `auth-service/requirements.txt` | Adicionar dependências |
| `api-gateway/requirements.txt` | Adicionar dependências |
| `core-management-api/requirements.txt` | Adicionar dependências |
| `agent-worker-service/requirements.txt` | Adicionar dependências |
| `frontend-app/package.json` | Adicionar dependências |

### Variáveis de Ambiente

```env
# Stack de Observabilidade
OBSERVABILITY_STACK=local|aws|hybrid
ENV=development|staging|production

# Local Stack (Prometheus/Grafana)
PROMETHEUS_URL=http://prometheus:9090
GRAFANA_URL=http://grafana:3001
LOKI_URL=http://loki:3100
TEMPO_URL=http://tempo:3200

# AWS Stack (CloudWatch)
AWS_REGION=us-east-1
CLOUDWATCH_LOG_GROUP=/aws/ecs/safehire
XRAY_DAEMON_ADDRESS=xray-daemon:2000
CLOUDWATCH_RUM_APP_ID=safehire-frontend
CLOUDWATCH_RUM_IDENTITY_POOL=us-east-1:xxxx

# Alertas
ALERT_SLACK_WEBHOOK=https://hooks.slack.com/...
ALERT_EMAIL=alerts@safehire.ai
ALERT_PAGERDUTY_SERVICE_KEY=xxxxx

# Tracing
TRACE_SAMPLING_RATE=1.0  # 100% dev, 0.1 prod
TRACE_TIMEOUT=30

# Logs
LOG_LEVEL=INFO|DEBUG|ERROR
LOG_FORMAT=json
LOG_PRETTY_PRINT=true
```

---

## Configuração Detalhada dos Serviços

### Prometheus (`monitoring/prometheus/prometheus.yml`)

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    cluster: 'safehire'
    environment: 'development'

scrape_configs:
  - job_name: 'auth-service'
    static_configs:
      - targets: ['auth-service:8000']
    metrics_path: '/metrics'

  - job_name: 'api-gateway'
    static_configs:
      - targets: ['api-gateway:8000']
    metrics_path: '/metrics'

  - job_name: 'core-management-api'
    static_configs:
      - targets: ['core-management-api:8000']
    metrics_path: '/metrics'

  - job_name: 'agent-worker-service'
    static_configs:
      - targets: ['agent-worker-service:8000']
    metrics_path: '/metrics'

  - job_name: 'postgres'
    static_configs:
      - targets: ['postgres_exporter:9187']

  - job_name: 'rabbitmq'
    static_configs:
      - targets: ['rabbitmq:15692']

  - job_name: 'valkey'
    static_configs:
      - targets: ['valkey_exporter:9121']

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']

alerting:
  alertmanagers:
    - static_configs:
        - targets: ['alertmanager:9093']

rule_files:
  - 'alerts.yml'
```

### Grafana Dashboard Exemplo

```json
{
  "title": "SafeHire API Performance",
  "panels": [
    {
      "title": "Request Rate",
      "targets": [
        {
          "expr": "sum(rate(http_requests_total[5m])) by (service, path)"
        }
      ]
    },
    {
      "title": "Error Rate",
      "targets": [
        {
          "expr": "sum(rate(http_requests_total{status=~'5..'}[5m])) by (service) / sum(rate(http_requests_total[5m])) by (service)"
        }
      ]
    },
    {
      "title": "P95 Latency",
      "targets": [
        {
          "expr": "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))"
        }
      ]
    }
  ]
}
```

### Uptime Kuma Setup

Monitors a configurar:
1. **API Gateway** - GET http://api-gateway:8000/health - Intervalo 30s
2. **Auth Service** - GET http://auth-service:8000/health - Intervalo 30s
3. **Core API** - GET http://core-management-api:8000/health - Intervalo 30s
4. **Frontend** - GET http://frontend-app:3000 - Intervalo 60s
5. **PostgreSQL** - TCP postgres:5432 - Intervalo 30s
6. **RabbitMQ** - TCP rabbitmq:5672 - Intervalo 30s
7. **Valkey** - TCP valkey:6379 - Intervalo 30s

---

## Métricas de Agent CrewAI

### Métricas a Implementar

```python
# Em agent-worker-service/observability/metrics.py

from prometheus_client import Counter, Histogram, Gauge

# Agent execution metrics
agent_execution_time = Histogram(
    'crewai_agent_execution_seconds',
    'Time spent executing agent',
    ['agent_name', 'task_name', 'status']
)

agent_token_usage = Counter(
    'crewai_agent_tokens_total',
    'Total tokens consumed by agents',
    ['agent_name', 'model']
)

agent_success_rate = Gauge(
    'crewai_agent_success_rate',
    'Success rate of agent executions',
    ['agent_name']
)

# Pipeline metrics
pipeline_execution_time = Histogram(
    'crewai_pipeline_execution_seconds',
    'Time spent executing full pipeline',
    ['pipeline_name', 'status']
)

pdf_processing_time = Histogram(
    'crewai_pdf_processing_seconds',
    'Time spent processing PDF'
)

embedding_generation_time = Histogram(
    'crewai_embedding_generation_seconds',
    'Time spent generating embeddings',
    ['model']
)

vector_search_time = Histogram(
    'crewai_vector_search_seconds',
    'Time spent performing vector search'
)

# Queue metrics
queue_depth = Gauge(
    'crewai_queue_depth',
    'Number of messages in queue',
    ['queue_name']
)

consumer_lag = Gauge(
    'crewai_consumer_lag',
    'Consumer lag in messages',
    ['consumer_name', 'queue_name']
)
```

---

## Validação e Testes

### Checklist de Validação

- [ ] Prometheus coleta métricas de todos os serviços
- [ ] Grafana exibe dashboards corretamente
- [ ] Loki coleta e exibe logs estruturados
- [ ] Tempo coleta e exibe traces
- [ ] Alertmanager envia alertas configurados
- [ ] Uptime Kuma detecta falhas de serviços
- [ ] Health checks funcionam em todos os serviços
- [ ] Distributed tracing funciona entre serviços
- [ ] Métricas de CrewAI são coletadas
- [ ] Logs são estruturados em JSON

### Comandos de Validação

```bash
# Verificar status dos serviços de observabilidade
docker-compose -f docker-compose.observability.yml ps

# Testar Prometheus
curl http://localhost:9090/api/v1/targets

# Testar métricas de um serviço
curl http://localhost:8001/metrics

# Testar trace generation
curl -X POST http://localhost:8000/api/test/tracing

# Verificar logs no Loki
curl http://localhost:3100/loki/api/v1/query_range?query={service="auth-service"}

# Verificar alertas no Alertmanager
curl http://localhost:9093/api/v1/alerts
```

---

## Makefile - Comandos Adicionais

```makefile
# Observabilidade commands
observability-up: ## Inicia serviços de observabilidade
	docker-compose -f docker-compose.observability.yml up -d

observability-down: ## Para serviços de observabilidade
	docker-compose -f docker-compose.observability.yml down

grafana: ## Abre Grafana no navegador
	xdg-open http://localhost:3001

prometheus: ## Abre Prometheus no navegador
	xdg-open http://localhost:9090

tempo: ## Abre Tempo no navegador
	xdg-open http://localhost:3200

uptime-kuma: ## Abre Uptime Kuma no navegador
	xdg-open http://localhost:3002

alerts: ## Lista alertas ativos
	curl http://localhost:9093/api/v1/alerts
```

---

## Documentação

### URLs de Acesso

| Serviço | URL | Credenciais |
|---------|-----|-------------|
| Grafana | http://localhost:3001 | admin/admin (mudar no primeiro acesso) |
| Prometheus | http://localhost:9090 | - |
| Tempo | http://localhost:3200 | - |
| Loki | http://localhost:3100 | - |
| Alertmanager | http://localhost:9093 | - |
| Uptime Kuma | http://localhost:3002 | admin/admin (mudar no primeiro acesso) |
| RabbitMQ Management | http://localhost:15672 | guest/guest |

### Links Úteis

- Grafana Dashboards Community: https://grafana.com/grafana/dashboards/
- Prometheus Best Practices: https://prometheus.io/docs/practices/
- OpenTelemetry Python: https://opentelemetry.io/docs/instrumentation/python/
- CrewAI Observability: https://docs.crewai.com/

---

## Próximos Passos

Após implementação:

1. Configurar backup de dados de observabilidade
2. Integrar com PagerDuty ou Opsgenie para on-call
3. Configurar SLOs (Service Level Objectives)
4. Implementar AIOps para detecção automática de anomalias
5. Adicionar análise de custo (observabilidade de billing)

---

## AWS CloudWatch - Stack de Produção

### Visão Geral

**AWS CloudWatch** é a solução nativa de observabilidade da Amazon para ambientes de produção. Inclui:

| Componente | AWS Service | Função |
|------------|-------------|--------|
| **CloudWatch Metrics** | CloudWatch | Métricas customizadas e AWS nativas |
| **CloudWatch Logs** | CloudWatch Logs | Agregação e análise de logs |
| **CloudWatch Alarms** | CloudWatch Alarms | Alertas baseados em métricas |
| **CloudWatch Dashboards** | CloudWatch Dashboards | Visualizações personalizadas |
| **CloudWatch Logs Insights** | CloudWatch Logs Insights | Queries avançadas em logs |
| **AWS X-Ray** | X-Ray | Distributed tracing |
| **CloudWatch RUM** | CloudWatch RUM | Real User Monitoring (frontend) |
| **CloudWatch Synthetics** | CloudWatch Synthetics | Monitores de uptime |
| **Amazon Managed Service for Prometheus** | AMP | Prometheus gerenciado |
| **Amazon Managed Grafana** | AMG | Grafana gerenciado |

---

### Arquitetura AWS CloudWatch

```
┌───────────────────────────────────────────────────────────────────┐
│                        AWS ACCOUNT (PROD)                         │
├───────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌─────────────────────────────────────────────────────────────┐  │
│  │                   CLOUDWATCH LOGS                           │  │
│  │  /aws/ecs/auth-service                                      │  │
│  │  /aws/ecs/api-gateway                                       │  │
│  │  /aws/ecs/core-management-api                               │  │
│  │  /aws/ecs/agent-worker-service                              │  │
│  │  /aws/lambda/function/*                                     │  │
│  │  /aws/apigateway/*                                          │  │
│  └─────────────────────────────────────────────────────────────┘  │
│                              ↓                                    │
│  ┌─────────────────────────────────────────────────────────────┐  │
│  │                  CLOUDWATCH METRICS                         │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │  │
│  │  │   AWS       │  │  Custom     │  │  Agent      │          │  │
│  │  │   Metrics   │  │  Metrics    │  │  Metrics    │          │  │
│  │  │ (ECS, RDS,  │  │ (app-spec)  │  │ (CrewAI)    │          │  │
│  │  │  S3, SQS)   │  │             │  │             │          │  │
│  │  └─────────────┘  └─────────────┘  └─────────────┘          │  │
│  └─────────────────────────────────────────────────────────────┘  │
│                              ↓                                    │
│  ┌─────────────────────────────────────────────────────────────┐  │
│  │                 CLOUDWATCH DASHBOARDS                       │  │
│  │  System Health | API Performance | AI Agents | Cost         │  │
│  └─────────────────────────────────────────────────────────────┘  │
│                              ↓                                    │
│  ┌─────────────────────────────────────────────────────────────┐  │
│  │                 CLOUDWATCH ALARMS                           │  │
│  │  → SNS Topic → Slack/Email/PagerDuty                        │  │
│  └─────────────────────────────────────────────────────────────┘  │
│                              ↓                                    │
│  ┌─────────────────────────────────────────────────────────────┐  │
│  │                    AWS X-RAY                                │  │
│  │  Service Map → Distributed Traces → Analytics               │  │
│  └─────────────────────────────────────────────────────────────┘  │
└───────────────────────────────────────────────────────────────────┘
```

---

### Configuração de CloudWatch

#### 1. CloudWatch Logs

```python
# observability/logging_aws.py
import boto3
import json
import logging
from typing import Dict, Any
from datetime import datetime

class CloudWatchLogger:
    def __init__(self, log_group_name: str, region: str = "us-east-1"):
        self.client = boto3.client('logs', region_name=region)
        self.log_group_name = log_group_name
        self.stream_name = self._create_log_stream()

    def _create_log_stream(self) -> str:
        """Cria log stream se não existir."""
        stream_name = f"stream-{datetime.utcnow().strftime('%Y%m%d-%H%M%S')}"

        try:
            self.client.create_log_group(logGroupName=self.log_group_name)
        except self.client.exceptions.ResourceAlreadyExistsException:
            pass

        self.client.create_log_stream(
            logGroupName=self.log_group_name,
            logStreamName=stream_name
        )
        return stream_name

    def log(self, level: str, message: str, **kwargs) -> None:
        """Envia log estruturado para CloudWatch."""
        log_entry = {
            "timestamp": int(datetime.utcnow().timestamp() * 1000),
            "level": level,
            "message": message,
            **kwargs
        }

        self.client.put_log_events(
            logGroupName=self.log_group_name,
            logStreamName=self.stream_name,
            logEvents=[{
                "timestamp": log_entry["timestamp"],
                "message": json.dumps(log_entry)
            }]
        )
```

#### 2. CloudWatch Metrics

```python
# observability/metrics_aws.py
import boto3
import time
from typing import Optional

class CloudWatchMetrics:
    def __init__(self, namespace: str, region: str = "us-east-1"):
        self.client = boto3.client('cloudwatch', region_name=region)
        self.namespace = namespace
        self._metrics_buffer = []

    def put_metric(
        self,
        metric_name: str,
        value: float,
        unit: str = "Count",
        dimensions: Optional[Dict[str, str]] = None
    ) -> None:
        """Envia métrica para CloudWatch."""
        dimensions = dimensions or {}
        dimension_list = [
            {"Name": k, "Value": v} for k, v in dimensions.items()
        ]

        self.client.put_metric_data(
            Namespace=self.namespace,
            MetricData=[{
                "MetricName": metric_name,
                "Value": value,
                "Unit": unit,
                "Dimensions": dimension_list,
                "Timestamp": time.time()
            }]
        )

    # Métricas de CrewAI
    def record_agent_execution(
        self,
        agent_name: str,
        execution_time: float,
        status: str
    ) -> None:
        """Registra execução de agent."""
        self.put_metric(
            metric_name="AgentExecutionTime",
            value=execution_time,
            unit="Seconds",
            dimensions={
                "AgentName": agent_name,
                "Status": status
            }
        )

    def record_token_usage(
        self,
        agent_name: str,
        model: str,
        tokens: int
    ) -> None:
        """Registra consumo de tokens."""
        self.put_metric(
            metric_name="TokenUsage",
            value=tokens,
            unit="Count",
            dimensions={
                "AgentName": agent_name,
                "Model": model
            }
        )

    def record_pdf_processing(self, duration: float, success: bool) -> None:
        """Registra processamento de PDF."""
        self.put_metric(
            metric_name="PDFProcessingDuration",
            value=duration,
            unit="Seconds",
            dimensions={"Success": str(success)}
        )
```

#### 3. AWS X-Ray Integration

```python
# observability/tracing_aws.py
import boto3
from aws_xray_sdk.core import xray_recorder
from aws_xray_sdk.core import patch_all

class XRayTracer:
    def __init__(self, daemon_address: str = "127.0.0.1:2000"):
        xray_recorder.configure(
            daemon_address=daemon_address,
            service="safehire-ai",
            context_missing="LOG_ERROR"
        )
        patch_all()

    def begin_subsegment(self, name: str):
        """Inicia subsegment para tracking."""
        return xray_recorder.begin_subsegment(name)

    def end_subsegment(self, subsegment):
        """Finaliza subsegment."""
        xray_recorder.end_subsegment()

    def put_annotation(self, key: str, value: Any):
        """Adiciona anotação ao trace atual."""
        xray_recorder.put_annotation(key, value)

    def put_metadata(self, key: str, value: Any):
        """Adiciona metadata ao trace atual."""
        xray_recorder.put_metadata(key, value)

# Context manager para tracing
from contextlib import contextmanager

@contextmanager
def trace_operation(name: str):
    """Context manager para tracing de operações."""
    subsegment = xray_recorder.begin_subsegment(name)
    try:
        yield subsegment
    except Exception as e:
        subsegment.add_error_flag()
        raise
    finally:
        xray_recorder.end_subsegment()
```

#### 4. CloudWatch Alarms

```python
# observability/alarms_aws.py
import boto3

class CloudWatchAlarms:
    def __init__(self, region: str = "us-east-1"):
        self.client = boto3.client('cloudwatch', region_name=region)

    def create_high_error_rate_alarm(
        self,
        service_name: str,
        threshold: float = 5.0,
        sns_topic_arn: str = None
    ) -> str:
        """Cria alarme para alta taxa de erro."""
        alarm_name = f"safehire-{service_name}-high-error-rate"

        params = {
            "AlarmName": alarm_name,
            "AlarmDescription": f"Alerta: {service_name} com alta taxa de erro",
            "MetricName": "HTTPErrorRate",
            "Namespace": f"SafeHire/{service_name}",
            "Statistic": "Average",
            "Period": 300,  # 5 minutos
            "EvaluationPeriods": 1,
            "Threshold": threshold,
            "ComparisonOperator": "GreaterThanThreshold",
            "TreatMissingData": "notBreaching"
        }

        if sns_topic_arn:
            params["AlarmActions"] = [sns_topic_arn]

        self.client.put_metric_alarm(**params)
        return alarm_name

    def create_high_latency_alarm(
        self,
        service_name: str,
        threshold: float = 1.0,
        sns_topic_arn: str = None
    ) -> str:
        """Cria alarme para alta latência."""
        alarm_name = f"safehire-{service_name}-high-latency"

        params = {
            "AlarmName": alarm_name,
            "AlarmDescription": f"Alerta: {service_name} com latência alta",
            "MetricName": "APILatency",
            "Namespace": f"SafeHire/{service_name}",
            "Statistic": "p95",
            "Period": 300,
            "EvaluationPeriods": 1,
            "Threshold": threshold,
            "ComparisonOperator": "GreaterThanThreshold",
            "TreatMissingData": "notBreaching"
        }

        if sns_topic_arn:
            params["AlarmActions"] = [sns_topic_arn]

        self.client.put_metric_alarm(**params)
        return alarm_name

    def create_queue_depth_alarm(
        self,
        queue_name: str,
        threshold: int = 1000,
        sns_topic_arn: str = None
    ) -> str:
        """Cria alarme para profundidade de fila SQS."""
        alarm_name = f"safehire-{queue_name}-high-queue-depth"

        params = {
            "AlarmName": alarm_name,
            "AlarmDescription": f"Alerta: Fila {queue_name} com muitas mensagens",
            "MetricName": "ApproximateNumberOfMessagesVisible",
            "Namespace": "AWS/SQS",
            "Dimensions": [{"Name": "QueueName", "Value": queue_name}],
            "Statistic": "Sum",
            "Period": 300,
            "EvaluationPeriods": 1,
            "Threshold": threshold,
            "ComparisonOperator": "GreaterThanThreshold",
            "TreatMissingData": "notBreaching"
        }

        if sns_topic_arn:
            params["AlarmActions"] = [sns_topic_arn]

        self.client.put_metric_alarm(**params)
        return alarm_name

    def create_agent_failure_rate_alarm(
        self,
        agent_name: str,
        threshold: float = 10.0,
        sns_topic_arn: str = None
    ) -> str:
        """Cria alarme para alta taxa de falha de agents."""
        alarm_name = f"safehire-agent-{agent_name}-high-failure-rate"

        params = {
            "AlarmName": alarm_name,
            "AlarmDescription": f"Alerta: Agent {agent_name} com alta taxa de falha",
            "MetricName": "AgentFailureRate",
            "Namespace": "SafeHire/Agents",
            "Dimensions": [{"Name": "AgentName", "Value": agent_name}],
            "Statistic": "Average",
            "Period": 300,
            "EvaluationPeriods": 1,
            "Threshold": threshold,
            "ComparisonOperator": "GreaterThanThreshold",
            "TreatMissingData": "notBreaching"
        }

        if sns_topic_arn:
            params["AlarmActions"] = [sns_topic_arn]

        self.client.put_metric_alarm(**params)
        return alarm_name
```

---

### CloudWatch RUM (Real User Monitoring)

```typescript
// frontend-app/public/rum.js
import { AwsRum } from 'aws-rum-web';

try {
  const awsRum = new AwsRum({
    identityPoolId: 'us-east-1:xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
    sessionSampleRate: 1,
    guestRoleArn: 'arn:aws:iam::xxxxxxxxxxxx:role/CognitoSafeHireRUMGuestRole',
    endpoint: 'https://dataplane.rum.us-east-1.amazonaws.com',
    telemetries: ['performance', 'errors', 'http'],
    allowCookies: true,
    enableXRay: true,
    region: 'us-east-1',
    appVersion: '1.0.0',
    appTitle: 'SafeHire AI',
    pageViewAttributes: {
      userId: window.user_id,
      role: window.user_role
    }
  });

  // Adicionar contexto customizado
  awsRum.addSessionAttributes({
    environment: process.env.NEXT_PUBLIC_ENV,
    version: process.env.NEXT_PUBLIC_VERSION
  });

  // Rastrear erros
  window.addEventListener('error', (event) => {
    awsRum.recordError(event.error);
  });

} catch (error) {
  console.error('Failed to initialize AWS RUM:', error);
}
```

---

### CloudWatch Synthetics (Uptime Monitoring)

```python
# scripts/create_synthetics_canary.py
import boto3
import json

def create_api_gateway_canary():
    """Cria canary para monitorar API Gateway."""
    client = boto3.client('synthetics')

    canary_script = """
    var synthetics = require('Synthetics');
    var log = require('SyntheticsLogger');

    const apiGatewayUrl = 'https://api.safehire-ai.com';

    exports.handler = async () => {
      const response = await synthetics.executeHttpStep(
        'Check API Gateway Health',
        apiGatewayUrl + '/health',
        {
          method: 'GET'
        }
      );

      if (response.statusCode !== 200) {
        throw new Error(`Health check failed: ${response.statusCode}`);
      }
    };
    """

    client.create_canary(
        Name='safehire-api-gateway-health',
        Script={
            'Handler': 'index.handler',
            'ZipFile': canary_script
        },
        ExecutionRoleArn='arn:aws:iam::xxxxxxxxxxxx:role/CloudWatchSyntheticsRole',
        Schedule={
            'Expression': 'rate(5 minutes)'
        },
        RunConfig={
            'TimeoutInSeconds': 60
        },
        SuccessRetentionPeriodInDays=30,
        FailureRetentionPeriodInDays=30,
        RuntimeVersion='syn-nodejs-puppeteer-6.2'
    )
```

---

### CloudWatch Dashboard - Exemplo

```python
# scripts/create_cloudwatch_dashboard.py
import boto3
import json

def create_safehire_dashboard():
    """Cria dashboard CloudWatch para SafeHire AI."""
    client = boto3.client('cloudwatch')

    dashboard_body = {
        "widgets": [
            {
                "type": "metric",
                "x": 0,
                "y": 0,
                "width": 12,
                "height": 6,
                "properties": {
                    "metrics": [
                        ["SafeHire/AuthService", "HTTPRequestDuration", {"stat": "p95"}],
                        [".", "HTTPRequestDuration", {"stat": "Average"}],
                        ["SafeHire/APIGateway", "HTTPRequestDuration", {"stat": "p95"}],
                        [".", "HTTPRequestDuration", {"stat": "Average"}]
                    ],
                    "view": "timeSeries",
                    "stacked": False,
                    "region": "us-east-1",
                    "title": "API Latency"
                }
            },
            {
                "type": "metric",
                "x": 0,
                "y": 6,
                "width": 12,
                "height": 6,
                "properties": {
                    "metrics": [
                        ["SafeHire/AuthService", "HTTPErrorRate", {"stat": "Average"}],
                        ["SafeHire/APIGateway", "HTTPErrorRate", {"stat": "Average"}],
                        ["SafeHire/CoreAPI", "HTTPErrorRate", {"stat": "Average"}]
                    ],
                    "view": "timeSeries",
                    "stacked": false,
                    "region": "us-east-1",
                    "title": "Error Rate"
                }
            },
            {
                "type": "metric",
                "x": 0,
                "y": 12,
                "width": 12,
                "height": 6,
                "properties": {
                    "metrics": [
                        ["SafeHire/Agents", "AgentExecutionTime", {"stat": "Average"}],
                        [".", "TokenUsage", {"stat": "Sum"}],
                        [".", "AgentFailureRate", {"stat": "Average"}]
                    ],
                    "view": "timeSeries",
                    "stacked": False,
                    "region": "us-east-1",
                    "title": "AI Agent Metrics"
                }
            },
            {
                "type": "log",
                "x": 12,
                "y": 0,
                "width": 12,
                "height": 6,
                "properties": {
                    "logs": [
                        ["/aws/ecs/auth-service", "ERROR", "searchTerm", "\"\"", "source": "/aws/ecs/auth-service"]
                    ],
                    "view": "table",
                    "region": "us-east-1",
                    "title": "Recent Errors"
                }
            },
            {
                "type": "text",
                "x": 12,
                "y": 6,
                "width": 12,
                "height": 6,
                "properties": {
                    "markdown": "# System Health\n\n- **ECS Tasks**: Running\n- **RDS**: Healthy\n- **SQS**: Normal\n- **S3**: Available",
                    "title": "System Status"
                }
            },
            {
                "type": "alarm",
                "x": 12,
                "y": 12,
                "width": 12,
                "height": 6,
                "properties": {
                    "alarms": [
                        "safehire-auth-service-high-error-rate",
                        "safehire-api-gateway-high-latency",
                        "safehire-candidatos-novos-high-queue-depth",
                        "safehire-agent-gatekeeper-high-failure-rate"
                    ],
                    "title": "Active Alarms"
                }
            }
        ]
    }

    client.put_dashboard(
        DashboardName='SafeHire-Overview',
        DashboardBody=json.dumps(dashboard_body)
    )
```

---

### Integração com ECS (Docker em Produção)

```yaml
# ecs-task-definition.json
{
  "family": "safehire-auth-service",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "executionRoleArn": "arn:aws:iam::xxxxxxxxxxxx:role/ecsTaskExecutionRole",
  "taskRoleArn": "arn:aws:iam::xxxxxxxxxxxx:role/ecsTaskRole",
  "containerDefinitions": [
    {
      "name": "auth-service",
      "image": "lpcoutinho/safehire-auth-service:latest",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 8000,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {
          "name": "ENV",
          "value": "production"
        },
        {
          "name": "OBSERVABILITY_STACK",
          "value": "cloudwatch"
        },
        {
          "name": "AWS_REGION",
          "value": "us-east-1"
        },
        {
          "name": "CLOUDWATCH_LOG_GROUP",
          "value": "/aws/ecs/auth-service"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/aws/ecs/auth-service",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "ecs",
          "awslogs-create-group": "true"
        }
      },
      "secrets": [
        {
          "name": "DATABASE_URL",
          "valueFrom": "arn:aws:secretsmanager:us-east-1:xxxxxxxxxxxx:secret:safehire/database-url"
        },
        {
          "name": "JWT_SECRET_KEY",
          "valueFrom": "arn:aws:secretsmanager:us-east-1:xxxxxxxxxxxx:secret:safehire/jwt-secret"
        }
      ],
      "healthCheck": {
        "command": [
          "CMD-SHELL",
          "curl -f http://localhost:8000/health || exit 1"
        ],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 60
      },
      "dependsOn": [
        {
          "containerName": "xray-daemon",
          "condition": "START"
        }
      ]
    },
    {
      "name": "xray-daemon",
      "image": "amazon/aws-xray-daemon",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 2000,
          "protocol": "udp"
        }
      ]
    }
  ]
}
```

---

### AWS CloudWatch vs Stack Local

| Aspecto | Desenvolvimento (Local) | Produção (AWS) |
|---------|--------------------------|----------------|
| **Métricas** | Prometheus | CloudWatch Metrics |
| **Logs** | Loki | CloudWatch Logs |
| **Tracing** | Tempo/Jaeger | AWS X-Ray |
| **Dashboards** | Grafana | CloudWatch Dashboards |
| **Alertas** | Alertmanager | CloudWatch Alarms |
| **Uptime** | Uptime Kuma | CloudWatch Synthetics |
| **Frontend** | Web Vitals | CloudWatch RUM |
| **Custo** | $0 (local) | AWS service charges |

---

### Custos de CloudWatch (Estimativa)

| Serviço | Preço Estimado |
|---------|----------------|
| CloudWatch Metrics | $0.30/milhão de métricas |
| CloudWatch Logs | $0.50/GB ingestão + $0.03/GB armazenamento |
| CloudWatch Dashboards | $3/dashbórd |
| CloudWatch Alarms | Sem custo |
| AWS X-Ray | $5/milhão de traces |
| CloudWatch RUM | $0.25/10⁴ eventos |
| CloudWatch Synthetics | $0.0012/canary execution |

**Estimativa mensal (produção)**: ~$30-100 dependendo do volume