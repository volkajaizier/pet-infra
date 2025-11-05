variable "region" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "vpc_id" {
  type    = string
  default = null
}

variable "enable_loki" {
  type    = bool
  default = false
}

variable "alb_chart_version" {
  type = string
}
variable "ca_chart_version" {
  type = string
}

# parameters for external-dns / grafana / promtail
variable "domain" {
  type    = string
  default = null
}
variable "grafana_admin_password" {
  type    = string
  default = null
}
variable "grafana_host" {
  type    = string
  default = null
}
variable "domain_filters" {
  type    = list(string)
  default = null
}

variable "monitoring_ns" {
  description = "Kubernetes namespace for monitoring stack"
  type        = string
  default     = "monitoring"
}

variable "loki_chart_version" {
  description = "Grafana Loki chart version (pin for reproducibility)"
  type        = string
  default     = "5.39.0"
}

variable "loki_values_yaml" {
  description = "Rendered values YAML for Loki (string)"
  type        = string
  default     = ""
}
