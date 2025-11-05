terraform {
  required_version = ">= 1.6"
}

# EKS cluster

resource "aws_eks_cluster" "this" {
  name     = var.name
  role_arn = var.cluster_role_arn
  version  = var.k8s_version

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    endpoint_public_access  = true
    endpoint_private_access = false
  }

  dynamic "access_config" {
    for_each = [
      var.cluster_access_config != null ? var.cluster_access_config : {
        authentication_mode                         = "API_AND_CONFIG_MAP"
        bootstrap_cluster_creator_admin_permissions = true
      }
    ]
    content {
      authentication_mode                         = access_config.value.authentication_mode
      bootstrap_cluster_creator_admin_permissions = try(access_config.value.bootstrap_cluster_creator_admin_permissions, true)
    }
  }

  depends_on = [var.cluster_role_dependencies]
  tags       = { Name = var.name }
}

# Node group

resource "aws_eks_node_group" "default" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.name}-ng"
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.private_subnet_ids

  scaling_config {
    desired_size = var.desired_size
    min_size     = var.min_size
    max_size     = var.max_size
  }

  launch_template {
    id      = aws_launch_template.nodes.id
    version = "$Latest"
  }

  instance_types = [var.instance_type]
  ami_type       = var.ami_type
  tags           = { Name = "${var.name}-ng" }
}

#OIDC

data "aws_eks_cluster" "this" { name = aws_eks_cluster.this.name }
data "aws_eks_cluster_auth" "this" { name = aws_eks_cluster.this.name }
data "tls_certificate" "oidc" {
  url = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  url             = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.oidc.certificates[0].sha1_fingerprint]
}

output "cluster_name" { value = aws_eks_cluster.this.name }
output "cluster_arn" { value = aws_eks_cluster.this.arn }
output "cluster_ca" { value = data.aws_eks_cluster.this.certificate_authority[0].data }
output "cluster_ep" { value = data.aws_eks_cluster.this.endpoint }
output "oidc_arn" { value = aws_iam_openid_connect_provider.eks.arn }
output "oidc_url" { value = aws_iam_openid_connect_provider.eks.url }
output "cluster_endpoint" { value = aws_eks_cluster.this.endpoint }
