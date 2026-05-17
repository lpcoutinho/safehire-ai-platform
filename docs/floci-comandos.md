# Floci - Guia de Desenvolvimento

Guia de referência para uso do Floci (emulador AWS all-in-one) no desenvolvimento local.

## Configuração

### Endpoint Local

```bash
export AWS_ENDPOINT_URL="http://localhost:4566"
export AWS_ACCESS_KEY_ID="test_access_key"
export AWS_SECRET_ACCESS_KEY="test_secret_key"
export AWS_REGION="us-east-1"
```

Ou use inline nos comandos:
```bash
aws --endpoint-url=http://localhost:4566 ...
```

## Portas Mapeadas

| Serviço | Porta Container | Porta Host |
|---------|-----------------|------------|
| AWS API | 4566 | 4566 |
| RDS PostgreSQL | 5432 | 5433 |
| SQS | 9324 | 9326 |
| SQS Management | 9325 | 9327 |
| ElastiCache (Valkey) | 6379 | 6380 |
| S3 Management | 8080 | 8089 |

---

## S3 - Armazenamento de Arquivos

### Criar Bucket

```bash
aws --endpoint-url=http://localhost:4566 s3 mb s3://safehire-curriculos
```

### Listar Buckets

```bash
aws --endpoint-url=http://localhost:4566 s3 ls
```

### Upload de Arquivo

```bash
aws --endpoint-url=http://localhost:4566 s3 cp curriculo.pdf s3://safehire-curriculos/
```

### Listar Arquivos em Bucket

```bash
aws --endpoint-url=http://localhost:4566 s3 ls s3://safehire-curriculos/
```

### Download de Arquivo

```bash
aws --endpoint-url=http://localhost:4566 s3 cp s3://safehire-curriculos/curriculo.pdf ./curriculo.pdf
```

### Deletar Bucket (vazio)

```bash
aws --endpoint-url=http://localhost:4566 s3 rb s3://safehire-curriculos
```

### Deletar Bucket (com conteúdo)

```bash
aws --endpoint-url=http://localhost:4566 s3 rb s3://safehire-curriculos --force
```

---

## SQS - Filas de Mensagens

### Criar Fila

```bash
aws --endpoint-url=http://localhost:4566 sqs create-queue --queue-name candidatos.novos
```

### Listar Filas

```bash
aws --endpoint-url=http://localhost:4566 sqs list-queues
```

### Enviar Mensagem

```bash
aws --endpoint-url=http://localhost:4566 sqs send-message \
  --queue-url http://localhost:4566/000000000000/candidatos.novos \
  --message-body '{"candidato_id": "123", "nome": "Luiz Paulo", "vaga": "Tech Lead"}'
```

### Receber Mensagem

```bash
aws --endpoint-url=http://localhost:4566 sqs receive-message \
  --queue-url http://localhost:4566/000000000000/candidatos.novos
```

### Receber Mensagem com Auto-Delete

```bash
aws --endpoint-url=http://localhost:4566 sqs receive-message \
  --queue-url http://localhost:4566/000000000000/candidatos.novos \
  --wait-time-seconds 10 | jq -r '.Messages[0].ReceiptHandle' | \
  xargs -I {} aws --endpoint-url=http://localhost:4566 sqs delete-message \
  --queue-url http://localhost:4566/000000000000/candidatos.novos \
  --receipt-handle {}
```

### Deletar Fila

```bash
aws --endpoint-url=http://localhost:4566 sqs delete-queue \
  --queue-url http://localhost:4566/000000000000/candidatos.novos
```

---

## RDS (PostgreSQL) - Banco de Dados

### Via Makefile

```bash
make db-shell
```

### Via psql Direto

```bash
psql -h localhost -p 5433 -U safehire -d safehire
```

### Comandos Úteis no psql

```sql
-- Listar bancos
\l

-- Listar tabelas
\dt

-- Listar schemas
\dn

-- Conectar em schema específico
SET search_path TO auth_schema;

-- Listar tabelas do schema atual
\dt auth_schema.*

-- Descrever tabela
\d auth_schema.usuarios

-- Sair
\q
```

---

## ElastiCache (Valkey) - Cache

### Via Makefile

```bash
make redis-shell
```

### Via redis-cli Direto

```bash
redis-cli -h localhost -p 6380
```

### Comandos Úteis no redis-cli

```bash
# Set valor
SET session:user:123 "{'name': 'Luiz Paulo', 'role': 'recruiter'}"

# Get valor
GET session:user:123

# Set com TTL (10 minutos)
SET status:job:456 "processing" EX 600

# Listar todas as chaves
KEYS *

# Listar chaves por pattern
KEYS session:*

# Deletar chave
DEL session:user:123

# Verificar TTL
TTL status:job:456

# Flush all (cuidado!)
FLUSHALL

# Sair
EXIT
```

---

## Monitoramento e Diagnóstico

### Ver Logs do Floci

```bash
make logs
```

### Ver Health Status

```bash
curl http://localhost:4566/_localstack/health
```

### Ver Contêiner Status

```bash
make ps
```

### Ver UI de Gestão

- **S3 Management**: http://localhost:8089
- **SQS Management**: http://localhost:9327

### Entrar no Shell do Contêiner

```bash
docker compose exec floci bash
```

### Ver Recursos do Contêiner

```bash
docker stats safehire-floci
```

---

## Setup Inicial do Projeto

### Executar Script de Init (Schemas)

```bash
docker compose exec floci psql -h localhost -p 5432 -U safehire -d safehire \
  -f /docker-entrypoint-initdb.d/init.sql
```

### Criar Bucket e Fila Iniciais

```bash
# Bucket S3
aws --endpoint-url=http://localhost:4566 s3 mb s3://safehire-curriculos

# Fila SQS
aws --endpoint-url=http://localhost:4566 sqs create-queue --queue-name candidatos.novos
```

---

## Troubleshooting

### Porta Já em Uso

Se um dos serviços já estiver rodando na porta:
1. Verifique qual processo está usando: `lsof -i :<porta>`
2. Mate o processo: `kill -9 <PID>`
3. Reinicie: `make down && make up`

### Container Não Sobe

```bash
# Ver logs detalhados
docker compose logs --tail=100 floci

# Ver se há erros de permissão
docker compose exec floci ls -la /tmp/localstack_data
```

### Conexão com RDS Falhando

```bash
# Verifica se RDS está rodando no container
docker compose exec floci pg_isready -h localhost -p 5432

# Conexão de teste do host
psql -h localhost -p 5433 -U safehire -d safehire
```

### Reset Completo (Perde Dados)

```bash
make clean
make up
```

---

## Integração com Python

### Boto3 - S3

```python
import boto3

s3 = boto3.client(
    's3',
    endpoint_url='http://localhost:4566',
    aws_access_key_id='test_access_key',
    aws_secret_access_key='test_secret_key',
    region_name='us-east-1'
)

# Upload
s3.upload_file('curriculo.pdf', 'safehire-curriculos', 'curriculos/123.pdf')

# Download
s3.download_file('safehire-curriculos', 'curriculos/123.pdf', 'local.pdf')
```

### Boto3 - SQS

```python
import boto3

sqs = boto3.client(
    'sqs',
    endpoint_url='http://localhost:4566',
    aws_access_key_id='test_access_key',
    aws_secret_access_key='test_secret_key',
    region_name='us-east-1'
)

# Enviar mensagem
sqs.send_message(
    QueueUrl='http://localhost:4566/000000000000/candidatos.novos',
    MessageBody='{"candidato_id": "123"}'
)

# Receber mensagem
response = sqs.receive_message(
    QueueUrl='http://localhost:4566/000000000000/candidatos.novos',
    MaxNumberOfMessages=1
)
message = response['Messages'][0]
```

### Redis/Valkey

```python
import redis

r = redis.Redis(
    host='localhost',
    port=6380,
    decode_responses=True
)

# Set
r.set('session:user:123', "{'name': 'Luiz Paulo'}")

# Get
value = r.get('session:user:123')
```

---

## Links Úteis

- **Documentação Floci**: https://floci.io/
- **AWS CLI Docs**: https://docs.aws.amazon.com/cli/
- **Redis Commands**: https://redis.io/commands/
- **PostgreSQL Docs**: https://www.postgresql.org/docs/