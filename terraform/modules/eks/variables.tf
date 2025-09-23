variable "name" { type = string }
variable "region" { type = string }
variable "k8s_version" {
  type    = string
  default = "1.31"
}
variable "private_subnet_ids" { type = list(string) }

variable "cluster_role_arn" { type = string }
variable "cluster_role_dependencies" {
  type    = list(any)
  default = []
}
variable "node_role_arn" { type = string }

variable "desired_size" {
  type    = number
  default = 2
}
variable "min_size" {
  type    = number
  default = 2
}
variable "max_size" {
  type    = number
  default = 2
}
variable "instance_type" {
  type    = string
  default = "t3.medium"
}
variable "ami_type" {
  type    = string
  default = "AL2023_x86_64_STANDARD"
}
variable "vpc_id" { type = string }
variable "vpc_cidr" { type = string }

variable "cluster_access_config" {
  description = "EKS access config"
  type = object({
    authentication_mode                         = optional(string, "API_AND_CONFIG_MAP")
    bootstrap_cluster_creator_admin_permissions = optional(bool, true)
  })
  default = null
}