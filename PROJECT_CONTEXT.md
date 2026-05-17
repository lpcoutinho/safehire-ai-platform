# Project Context & Multi-Service Architecture Spec: SafeHire AI

## 1. Visão Geral e Arquitetura de Microsserviços
O **SafeHire AI** é uma plataforma corporativa distribuída, baseada em microsserviços e orientada a eventos para automação do pipeline de recrutamento técnico (*Tech Recruiting*). O sistema conta com um Frontend completo baseado em renderização híbrida para atender candidatos e recrutadores, consumindo serviços internos de forma segura e assíncrona, apoiado por uma infraestrutura emulada local da AWS para armazenamento de arquivos de mídia.

### Compliance LGPD & Segurança desde o Design (Privacy by Design):
Para total conformidade com a LGPD (Lei Geral de Proteção de Dados), o sistema adota criptografia ponta a ponta e gestão rigorosa do ciclo de vida de chaves:
- **Anonimização e Higienização:** Dados de currículos passam por descaracterização (remoção de CPFs, e-mails e nomes brutos) antes de qualquer processamento por modelos de linguagem (LLMs).
- **Criptografia em Repouso (Crypto-at-Rest):** Dados Pessoais Identificáveis (PII) salvos no PostgreSQL são criptografados a nível de coluna (através de extensões como `pgcrypto` ou criptografia na camada de aplicação via criptografia simétrica AES-256).
- **Roteamento e Gerenciamento de Chaves (Envelope Encryption):** O sistema utiliza chaves de criptografia de dados (DEKs) exclusivas por candidato para cifrar seus dados sensíveis. Essas DEKs são, por sua vez, cifradas por uma Chave Mestra (KEK) gerenciada em uma ferramenta dedicada (AWS KMS simulado no Floci). O roteamento garante que chaves nunca sejam expostas em logs ou persistidas junto com os dados cifrados.

### Os Componentes da Arquitetura:
1. **`auth-service` (FastAPI):** Gerenciamento de usuários (recrutadores e candidatos) e emissão de tokens JWT. Possui seu próprio esquema isolado no PostgreSQL.
2. **`api-gateway` (FastAPI / Reverse Proxy):** Validador central de segurança, decodificação de JWT e roteamento inteligente de tráfego para os serviços internos.
3. **`core-management-api` (FastAPI):** Regras de negócio, CRUD de vagas, recepção de currículos, upload para o S3 (Floci) e publicação de eventos no RabbitMQ.
4. **`agent-worker-service` (Python Core + CrewAI):** Worker assíncrono isolado. Consome o RabbitMQ, baixa os currículos armazenados no S3 (Floci), realiza busca vetorial no `pgvector` e orquestra a inteligência agêntica.
5. **`frontend-app` (Next.js + TypeScript):** Aplicação servidora de interface (Node.js), responsável por renderizar as páginas públicas dos candidatos (via SSR/ISR) e o painel administrativo dos recrutadores (via CSR).
6. **`aws-emulator` (Floci):** Emulador local leve de serviços da AWS (S3), eliminando custos e dependências externas durante o ciclo de desenvolvimento e testes.

---

## 2. Stack Tecnológica por Componente
O Claude Code deve respeitar rigorosamente as seguintes stacks ao gerar ou alterar o código:

- **APIs de Backend & Workers:** Python 3.11+ utilizando **FastAPI** (assíncrono) com SDK **`boto3`** para comunicação AWS.
- **Frontend App:** **Next.js (v14+ com App Router)** rodando em Node.js com **TypeScript**, **Tailwind CSS** e **Shadcn/ui**.
- **IA & Agentes:** **CrewAI** rodando exclusivamente dentro do `agent-worker-service`.
- **Emulador Cloud (Local):** **Floci** executando em modo nativo via container Docker (Porta `4566`).
- **Banco de Dados Relacional:** **PostgreSQL** (Bancos lógicos separados por microsserviço).
- **Banco de Dados Vetorial:** Extensão **`pgvector`** acoplada ao banco do `agent-worker-service`.
- **Mensageria (Event-Driven):** **RabbitMQ** para comunicação assíncrona entre as APIs de Core e os Workers de IA.
- **Cache & Sessão:** **Valkey** para cache de relatórios, dados voláteis e controle de status de processamento de tarefas.
- **Contenerização:** **Docker** e **Docker Compose** para orquestração de todo o ambiente local.

---

## 3. Topologia da Rede e Fluxo de Mensagens


```

[Usuário / Browser]
│
▼
┌───────────────┐
│ Next.js App   │
└───────┬───────┘
│ (Chamadas HTTP com HttpOnly Cookie JWT)
▼
┌───────────────┐
│  API Gateway  │
└───────┬───────┘
├──────────────────────────────────────┐
▼                                      ▼
┌───────────────┐                    ┌───────────────────┐
│ Auth Service  │                    │Core Management API├ ➔ (PostgreSQL)
└───────────────┘                    └─────────┬─────────┘
│ (1. Upload PDF)
├─ ➔ [AWS Emulator: Floci (S3)]
│
(2. Fila: candidatos.novos)
│
▼
┌───────────────────┐
│Agent Worker Service│ ➔ (PostgreSQL + pgvector)
└─────────┬─────────┘
│ (3. Download PDF)
├─ ➔ [AWS Emulator: Floci (S3)]
│
(Salva Status no Valkey)

```

### Contrato de Eventos (RabbitMQ - Fila `candidatos.novos`):
```json
{
  "candidato_id": 123,
  "vaga_id": 45,
  "s3_key": "curriculos/vaga_45/candidato_123.pdf",
  "timestamp": "2026-05-16T18:42:00Z"
}

```

---

## 4. Escopo de Telas e Rotas do Frontend (Next.js)

### Fluxo Público do Candidato (Server-Side Rendering - SSR/ISR):

* `/vagas`: Painel público com listagem e filtros dinâmicos de posições abertas.
* `/vagas/[id]`: Detalhes de uma vaga específica com requisitos consumidos do backend.
* `/vagas/[id]/aplicar`: Formulário de inscrição com upload de arquivo PDF de currículo.
* `/processo/[candidato_id]/questionario`: Tela que renderiza as perguntas técnicas dinâmicas geradas pela IA.
* `/processo/[candidato_id]/guia`: Página de transparência exibindo o roteiro personalizado de estudos para o candidato.

### Fluxo Privado do Recrutador (Client-Side Rendering - CSR):

* `/admin`: Dashboard consolidado de contratações e monitoramento de alertas.
* `/admin/vagas/nova`: Formulário de criação de vagas com campos otimizados para embeddings do RAG.
* `/admin/candidatos/[id]`: Dossiê do candidato contendo o Destaque de Gaps, o **Roteiro de Entrevista** estruturado para o entrevistador e métricas de risco.

---

## 5. Design da Equipe CrewAI (Strictly Inside `agent-worker-service`)

O processamento agêntico segue uma pipeline sequencial rígida com três personas:

1. **Gatekeeper Agent:** Sanitiza o input bruto do PDF (baixado do bucket S3 do Floci) contra *Indirect Prompt Injection* isolando o contexto dentro de tags XML `<curriculo>`. Se detectar ameaças, altera a flag de injeção e interrompe o fluxo imediatamente.
2. **RAG Specialist Agent:** Consome a ferramenta `@tool` que executa uma query SQL com o operador `<=>` (similaridade de cosseno) no `pgvector` para mapear os requisitos da vaga contra o currículo.
3. **Artifact Writer Agent:** Consolida os dados e garante que a resposta final atenda estritamente ao contrato do schema Pydantic `ResultadoProcessoSeletivo`.

---

## 6. Esquema Pydantic Uniforme de Saída

O worker deve estruturar e validar o resultado final utilizando obrigatoriamente este formato:

```python
from pydantic import BaseModel, Field
from typing import List, Dict

class ResultadoProcessoSeletivo(BaseModel):
    tentativa_injection: bool = Field(description="True se o currículo continha instruções maliciosas ocultas.")
    justificativa_seguranca: str = Field(description="Detalhes textuais da ameaça detectada pelo Gatekeeper.")
    candidato_aprovado_na_triagem: bool = Field(description="Se o candidato atende os requisitos mínimos obrigatórios da vaga.")
    desafio_codigo_customizado: str = Field(description="Enunciado completo do teste prático de código focado nos gaps.")
    roteiro_recrutador: List[Dict[str, str]] = Field(description="Lista de dicionários contendo chaves 'pergunta', 'resposta_esperada' e 'red_flag'.")
    guia_estudos_candidato: str = Field(description="Roteiro de estudos transparente e orientativo para o candidato.")

```

---

## 7. Diretrizes de Desenvolvimento para o Claude Code

1. **Isolamento de Ambientes:** Cada serviço deve conter seu próprio `Dockerfile` e gerenciamento de dependências (`requirements.txt` ou `package.json`) isolado em sua respectiva pasta.
2. **Abstração Cloud com Floci:** O código Python em desenvolvimento local deve instanciar clientes `boto3` passando o parâmetro `endpoint_url="http://aws-emulator:4566"`. Em ambiente produtivo, esse parâmetro deve ser omitido dinamicamente via variável de ambiente `ENV=production`.
3. **Segurança de Rede:** O Next.js e o `api-gateway` são os únicos componentes com exposição de portas para o Host público. Os demais microsserviços (incluindo o Floci) rodam estritamente dentro da rede interna privada do Docker.
4. **Gerenciamento de Sessão Stateless:** O Token JWT gerado pelo `auth-service` deve ser armazenado pelo Next.js como um **HttpOnly Cookie** seguro. O `api-gateway` decodifica a assinatura do token e repassa os metadados do usuário para os microsserviços internos via Headers HTTP padrão (`X-User-Id`, `X-User-Role`).
5. **Resiliência de Estado:** O Next.js deve realizar *polling* ou ler eventos rápidos baseados no status armazenado no **Valkey** para exibir dinamicamente o progresso da triagem ("Processando currículo...") antes de liberar o acesso às telas do candidato.
