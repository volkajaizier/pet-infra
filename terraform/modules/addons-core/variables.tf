variable "cluster_name" { type = string }

# VPC CNI
variable "cni_version" { type = string }

# kube-proxy
variable "kube_proxy_version" {
  type    = string
  default = null
}

# CoreDNS
variable "coredns_version" {
  type    = string
  default = null
}

# EBS CSI
variable "ebs_csi_version" {
  type    = string
  default = null
}
variable "ebs_csi_irsa_role_arn" { type = string } 