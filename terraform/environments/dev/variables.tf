variable "project" { type = string }
variable "region" {
  type    = string
  default = "eu-west-2"
}
variable "domain" { type = string }
variable "cluster_name" {
  type        = string
  description = "EKS cluster name"
}

# EKS addons
variable "cni_version" {
  type    = string
  default = "v1.16.2-eksbuild.1"
}
variable "kube_proxy_version" {
  type    = string
  default = "v1.30.0-eksbuild.2"
}
variable "coredns_version" {
  type    = string
  default = "v1.11.3-eksbuild.1"
}
variable "ebs_csi_version" {
  type    = string
  default = "v1.36.0-eksbuild.1"
}

# Helm charts
variable "alb_chart_version" {
  type    = string
  default = "1.8.1"
}
variable "ca_chart_version" {
  type    = string
  default = "9.43.0"
}

variable "grafana_admin_password" {
  type    = string
  default = null
}
variable "grafana_host" {
  type    = string
  default = null
}

variable "cluster_admin_principals" {
  description = "List of IAM principals (user/role ARNs) to grant EKS admin access"
  type        = list(string)
  default     = [] # value in dev.auto.tfvars
}

variable "env" {
  description = "Environment (dev/stage/prod). If null, fallback to terraform.workspace"
  type        = string
  default     = null
}

variable "create_monitoring_ns" {
  type    = bool
  default = true
}

variable "monitoring_ns" {
  type        = string
  description = "Namespace for monitoring stack"
  default     = "monitoring"
}

variable "loki_storage_class" {
  description = "Kubernetes StorageClass name to use for Loki StatefulSets"
  type        = string
  default     = "gp3"
}

# RDS Postgres (dev defaults)
variable "rds_db_name" {
  description = "Initial database name for RDS Postgres"
  type        = string
  default     = "petdb"
}

variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}
