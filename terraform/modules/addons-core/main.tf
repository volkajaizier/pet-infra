terraform {
  required_version = ">= 1.6"
}

# VPC CNI
resource "aws_eks_addon" "cni" {
  cluster_name  = var.cluster_name
  addon_name    = "vpc-cni"
  addon_version = var.cni_version

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  configuration_values = jsonencode({
    env = {
      ENABLE_PREFIX_DELEGATION = "true"
      WARM_PREFIX_TARGET       = "1"
    }
  })

  timeouts {
    create = "20m"
    update = "20m"
    delete = "20m"
  }
}

# kube-proxy
resource "aws_eks_addon" "kube_proxy" {
  cluster_name  = var.cluster_name
  addon_name    = "kube-proxy"
  addon_version = var.kube_proxy_version

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  timeouts {
    create = "20m"
    update = "20m"
    delete = "20m"
  }
}

# CoreDNS
resource "aws_eks_addon" "coredns" {
  cluster_name  = var.cluster_name
  addon_name    = "coredns"
  addon_version = var.coredns_version

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  timeouts {
    create = "20m"
    update = "20m"
    delete = "20m"
  }
}

# EBS CSI
resource "aws_eks_addon" "ebs_csi" {
  cluster_name = var.cluster_name
  addon_name   = "aws-ebs-csi-driver"

  addon_version            = var.ebs_csi_version
  service_account_role_arn = var.ebs_csi_irsa_role_arn

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  timeouts {
    create = "20m"
    update = "20m"
    delete = "20m"
  }
}

output "addons_versions" {
  value = {
    cni        = aws_eks_addon.cni.addon_version
    kube_proxy = try(aws_eks_addon.kube_proxy.addon_version, null)
    coredns    = try(aws_eks_addon.coredns.addon_version, null)
    ebs_csi    = try(aws_eks_addon.ebs_csi.addon_version, null)
  }
}
