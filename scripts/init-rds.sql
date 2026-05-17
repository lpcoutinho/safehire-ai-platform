-- Criar schemas isolados no Floci RDS (PostgreSQL)
CREATE SCHEMA IF NOT EXISTS auth_schema;
CREATE SCHEMA IF NOT EXISTS core_schema;
CREATE SCHEMA IF NOT EXISTS agent_schema;

-- Habilitar extensão pgvector no agent_schema
-- Nota: Floci RDS suporta extensões Postgres standard
CREATE EXTENSION IF NOT EXISTS vector SCHEMA agent_schema;

-- Grant permissions
GRANT ALL ON SCHEMA auth_schema TO safehire;
GRANT ALL ON SCHEMA core_schema TO safehire;
GRANT ALL ON SCHEMA agent_schema TO safehire;

-- Criar tabelas básicas (será feito pelas migrations dos serviços)