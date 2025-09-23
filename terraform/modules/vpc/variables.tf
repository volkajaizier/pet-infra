variable "name" {
  type = string
}

variable "region" {
  type = string
}

variable "cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "cluster_name" {
  type        = string
  description = "EKS cluster name for k8s discovery tags on subnets"
}