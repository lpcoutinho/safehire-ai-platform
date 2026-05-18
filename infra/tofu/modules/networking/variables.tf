variable "vpc_cidr" {
  type = string
}

variable "availability_zones" {
  type = list(string)
}

variable "environment" {
  type = string
}

variable "namespace" {
  type = string
}
