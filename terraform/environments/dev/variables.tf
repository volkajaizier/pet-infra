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
variable "cni_version" { type = string }
variable "kube_proxy_version" { type = string }
variable "coredns_version" { type = string }
variable "ebs_csi_version" { type = string }

# Helm charts
variable "alb_chart_version" { type = string }
variable "ca_chart_version" { type = string }

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
  default     = "gp2"
}
