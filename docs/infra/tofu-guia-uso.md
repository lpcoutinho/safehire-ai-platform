# OpenTofu — Guia de Uso no SafeHire AI Platform

## Visão Geral

O SafeHire usa **OpenTofu** (fork Apache 2.0 do Terraform, Linux Foundation) como IaC (Infrastructure as Code) para provisionar toda a infraestrutura AWS. O projeto segue a arquitetura de módulos reutilizáveis com configurações de backend separadas por ambiente.

```
infra/tofu/
├── versions.tf                    # Versão TOFU + providers (backend vazio)
├── main.tf                        # Orquestração dos 8 módulos
├── variables.tf                   # Variáveis globais
├── outputs.tf                     # Outputs da raiz
├── locals.tf                      # Locais compartilhados
├── providers-local.tf             # Provider Floci (dev local)
├── providers-aws.tf.bak           # Provider AWS real (staging/prod)
├── backends/
│   ├── local.tfbackend            # Backend S3 via Floci
│   ├── staging.tfbackend          # Backend S3 AWS staging
│   └── production.tfbackend       # Backend S3 AWS production
├── bootstrap/
│   └── main.tf                    # Cria S3 state + DynamoDB lock (executar 1x)
├── modules/
│   ├── networking/                # VPC, subnets, SGs, NAT, IGW
│   ├── iam/                       # ECS execution + task roles
│   ├── rds/                       # PostgreSQL 15 + pgvector
│   ├── storage/                   # S3 buckets
│   ├── messaging/                 # SQS queues + DLQ
│   ├── cache/                     # ElastiCache Valkey
│   ├── ecs/                       # ECS Fargate cluster, ALB, task defs, services
│   └── monitoring/                # CloudWatch dashboards + log groups
└── environments/
    ├── staging/terraform.tfvars   # Config staging
    └── production/terraform.tfvars # Config production
```

## Arquitetura dos Módulos

### Dependências entre módulos

```
networking ──┬── iam ──────┐
             │             │
             ├── rds ──────┤
             │             │
             ├── storage ──┤
             │             │
             ├── messaging ┤
             │             │
             ├── cache ────┤
             │             │
             └── monitoring│
                           │
                           ▼
                         ecs (depende de todos acima)
```

### Recursos provisionados por módulo

| Módulo | Recursos |
|--------|----------|
| **networking** | VPC, 2 subnets públicas, 2 subnets privadas, IGW, NAT Gateway, EIP, route tables, 4 security groups (ECS, RDS, Cache, ALB) |
| **iam** | ECS Execution Role, ECS Task Role, políticas S3/SQS/X-Ray |
| **rds** | PostgreSQL 15, subnet group, parameter group (pgvector), storage gp3 criptografado |
| **storage** | S3 `safehire-curriculos-{env}` com versioning, encryption, lifecycle |
| **messaging** | SQS `candidatos-novos-{env}` + DLQ `candidatos-novos-dlq-{env}` |
| **cache** | ElastiCache Valkey (Redis 7), subnet group, encryption at-rest |
| **ecs** | Fargate cluster, ALB (HTTP→HTTPS redirect), 4 task definitions (api-gateway, core-management, agent-worker, frontend-app), 4 ECS services, CloudWatch log groups |
| **monitoring** | CloudWatch dashboard (ECS CPU/Memory, RDS, ALB), log group X-Ray |

## Backend State

O state do OpenTofu é armazenado em **S3** com **DynamoDB** para locking (previne corrupção em applies concorrentes).

| Ambiente | Bucket | DynamoDB Table | Key |
|----------|--------|----------------|-----|
| Local (Floci) | `safehire-tofu-state` | `safehire-tofu-locks` | `local/terraform.tfstate` |
| Staging | `safehire-tofu-state` | `safehire-tofu-locks` | `staging/terraform.tfstate` |
| Production | `safehire-tofu-state` | `safehire-tofu-locks` | `production/terraform.tfstate` |

## Fluxo de Trabalho

### 1. Bootstrap (executar 1x, antes de tudo)

Cria o bucket S3 e a tabela DynamoDB que armazenam o state.

```bash
# Na AWS real (staging/production)
tofu -chdir=infra/tofu/bootstrap init
tofu -chdir=infra/tofu/bootstrap apply

# No Floci local
AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-east-1 \
  aws --endpoint-url=http://localhost:4566 s3 mb s3://safehire-tofu-state

AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-east-1 \
  aws --endpoint-url=http://localhost:4566 dynamodb create-table \
    --table-name safehire-tofu-locks \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST
```

### 2. Desenvolvimento Local (Floci)

Pré-requisito: Floci rodando com DynamoDB habilitado.

```bash
# Verificar que o Floci está rodando com DynamoDB
docker compose up -d floci
curl -s http://localhost:4566/_localstack/health | grep dynamodb
# Deve retornar: "dynamodb": "running"

# Inicializar com backend local
tofu -chdir=infra/tofu init \
  -backend-config=backends/local.tfbackend \
  -reconfigure

# Planejar
tofu -chdir=infra/tofu plan \
  -var-file=environments/staging/terraform.tfvars \
  -var="db_password=test123" \
  -var="ecr_image_registry=ghcr.io/test"

# Aplicar (cria toda infra no Floci)
tofu -chdir=infra/tofu apply \
  -var-file=environments/staging/terraform.tfvars \
  -var="db_password=test123" \
  -var="ecr_image_registry=ghcr.io/test"

# Destruir (limpa tudo)
tofu -chdir=infra/tofu destroy \
  -var-file=environments/staging/terraform.tfvars \
  -var="db_password=test123" \
  -var="ecr_image_registry=ghcr.io/test"
```

### 3. Staging

```bash
# Trocar provider: remover local, ativar AWS
rm infra/tofu/providers-local.tf
mv infra/tofu/providers-aws.tf.bak infra/tofu/providers-aws.tf

# Inicializar com backend staging
tofu -chdir=infra/tofu init \
  -backend-config=backends/staging.tfbackend \
  -reconfigure

# Planejar
tofu -chdir=infra/tofu plan \
  -var-file=environments/staging/terraform.tfvars \
  -var="db_password=${DB_PASSWORD}" \
  -var="ecr_image_registry=${ECR_IMAGE_REGISTRY}" \
  -var="image_tag=${IMAGE_TAG}"

# Aplicar
tofu -chdir=infra/tofu apply \
  -var-file=environments/staging/terraform.tfvars \
  -var="db_password=${DB_PASSWORD}" \
  -var="ecr_image_registry=${ECR_IMAGE_REGISTRY}" \
  -var="image_tag=${IMAGE_TAG}"
```

### 4. Production

```bash
# Mesma configuração de provider que staging (providers-aws.tf)

# Inicializar com backend production
tofu -chdir=infra/tofu init \
  -backend-config=backends/production.tfbackend \
  -reconfigure

# Planejar
tofu -chdir=infra/tofu plan \
  -var-file=environments/production/terraform.tfvars \
  -var="db_password=${DB_PASSWORD}" \
  -var="ecr_image_registry=${ECR_IMAGE_REGISTRY}" \
  -var="image_tag=${IMAGE_TAG}"

# Aplicar
tofu -chdir=infra/tofu apply \
  -var-file=environments/production/terraform.tfvars \
  -var="db_password=${DB_PASSWORD}" \
  -var="ecr_image_registry=${ECR_IMAGE_REGISTRY}" \
  -var="image_tag=${IMAGE_TAG}"
```

## CI/CD — Deploy Automatizado

O pipeline `.github/workflows/deploy.yml` orquestra o deploy via OpenTofu:

```yaml
# Trigger manual
workflow_dispatch:
  inputs:
    environment: vps | aws-staging | aws-production
    image_tag: latest | <tag específica>

# AWS jobs:
# 1. Checkout com submodules
# 2. Configure AWS credentials (secrets)
# 3. Setup OpenTofu
# 4. tofu init (backend S3 + DynamoDB)
# 5. tofu plan (salva tfplan)
# 6. tofu apply tfplan
```

### Comandos via GitHub CLI

```bash
# Deploy staging
gh workflow run deploy.yml \
  -f environment=aws-staging \
  -f image_tag=v1.2.3

# Deploy production
gh workflow run deploy.yml \
  -f environment=aws-production \
  -f image_tag=v1.2.3
```

## Variáveis por Ambiente

| Variável | Staging | Production |
|----------|---------|------------|
| `db_instance_class` | `db.t3.medium` | `db.r6g.large` |
| `db_allocated_storage` | 20 GB | 100 GB |
| `cache_node_type` | `cache.t3.micro` | `cache.r6g.large` |
| `ecs_task_cpu` | 256 (0.25 vCPU) | 1024 (1 vCPU) |
| `ecs_task_memory` | 512 MB | 2048 MB |
| `ecs_desired_count` | 1 | 2 |
| `availability_zones` | 2 AZs | 3 AZs |

## ECS Task Definitions

Cada submódulo tem seu `docker/ecs-task-definition.json` que é renderizado via `templatefile()` pelo módulo ECS:

| Submódulo | Container | Porta |
|-----------|-----------|-------|
| `api-gateway` | api-gateway | 8000 |
| `core-management-api` | core-management | 8000 |
| `agent-worker-service` | agent-worker | — (sem porta, consome SQS) |
| `frontend-app` | frontend-app | 3000 |

As variáveis no template (`${REPOSITORY_URL}`, `${IMAGE_TAG}`, `${RDS_HOST}`, etc.) são substituídas pelo OpenTofu com os valores reais da infraestrutura.

## Switch entre Ambientes

Para trocar de ambiente, sempre execute:

```bash
# 1. Remover provider do ambiente atual
rm -f infra/tofu/providers-local.tf infra/tofu/providers-aws.tf

# 2. Colocar o provider correto
# Para local:
cp infra/tofu/providers-local.tf.bak infra/tofu/providers-local.tf 2>/dev/null || echo "criar providers-local.tf"

# Para AWS:
mv infra/tofu/providers-aws.tf.bak infra/tofu/providers-aws.tf

# 3. Re-init com o backend correto
tofu -chdir=infra/tofu init \
  -backend-config=backends/<local|staging|production>.tfbackend \
  -reconfigure
```

## Comandos Úteis

```bash
# Validar sintaxe
tofu -chdir=infra/tofu validate

# Formatar arquivos
tofu -chdir=infra/tofu fmt

# Ver estado atual
tofu -chdir=infra/tofu state list

# Ver detalhes de um recurso
tofu -chdir=infra/tofu state show module.networking.aws_vpc.main

# Ver outputs
tofu -chdir=infra/tofu output

# Ver plan sem aplicar
tofu -chdir=infra/tofu plan -var-file=environments/staging/terraform.tfvars \
  -var="db_password=test123" -var="ecr_image_registry=ghcr.io/test"

# Gerar gráfico de dependências
tofu -chdir=infra/tofu graph | dot -Tpng > infra-diagram.png

# Forçar unlock (se travado)
tofu -chdir=infra/tofu force-unlock <LOCK_ID>
```

## Troubleshooting

### "S3 bucket does not exist"
O bucket de state não existe. Rode o bootstrap primeiro.

### "Backend initialization required"
O backend mudou. Rode `tofu init -reconfigure` com o `.tfbackend` correto.

### "Duplicate provider configuration"
Não pode ter `providers-local.tf` e `providers-aws.tf` ativos ao mesmo tempo. Remova um.

### "Retrieving AWS account details... InvalidClientTokenId"
O provider tá tentando validar credenciais reais. Para Floci, use `providers-local.tf` com `skip_credentials_validation = true`.

### State corrompido por apply concorrente
O DynamoDB lock previne isso. Se acontecer, rode `tofu force-unlock <LOCK_ID>`.

## Segurança

- **Senhas** — passadas via variável, nunca versionadas. Use `pass`, `1Password`, ou GitHub Secrets.
- **State file** — criptografado no S3 (`encrypt = true`).
- **Acesso** — bucket S3 e DynamoDB com `public_access_block` ativado.
- **RDS** — storage criptografado, acesso restrito ao security group ECS.
- **S3 buckets** — versioning + encryption + lifecycle de expiração.
