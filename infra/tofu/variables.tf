variable "aws_region" {
  description = "Região AWS"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Ambiente (staging ou production)"
  type        = string
}

variable "image_tag" {
  description = "Tag da imagem Docker para deploy"
  type        = string
  default     = "latest"
}

variable "vpc_cidr" {
  description = "CIDR block da VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "AZs para subnets"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "db_instance_class" {
  description = "Classe da instância RDS"
  type        = string
  default     = "db.t3.medium"
}

variable "db_allocated_storage" {
  description = "Storage do RDS em GB"
  type        = number
  default     = 20
}

variable "db_password" {
  description = "Senha do banco PostgreSQL"
  type        = string
  sensitive   = true
}

variable "cache_node_type" {
  description = "Tipo de nó do ElastiCache"
  type        = string
  default     = "cache.t3.micro"
}

variable "ecs_task_cpu" {
  description = "CPU para tasks Fargate (unidade: 256 = 0.25 vCPU)"
  type        = number
  default     = 256
}

variable "ecs_task_memory" {
  description = "Memória para tasks Fargate (MB)"
  type        = number
  default     = 512
}

variable "ecs_desired_count" {
  description = "Número desejado de tasks por serviço"
  type        = number
  default     = 1
}

variable "domain_name" {
  description = "Domínio para o ALB (opcional)"
  type        = string
  default     = ""
}

variable "ecr_image_registry" {
  description = "Registry das imagens Docker (ex: ghcr.io/lpcoutinho)"
  type        = string
}
