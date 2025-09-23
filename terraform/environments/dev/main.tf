locals {
  name = "${var.project}-eks-dev"
}

data "aws_caller_identity" "current" {}

locals {
  # Skip the current caller because EKS grants them admin access automatically
  managed_admins = [
    for p in var.cluster_admin_principals : p
    if p != data.aws_caller_identity.current.arn
  ]
}
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_ca)
  config_path            = null

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      module.eks.cluster_name
    ]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_ca)
    config_path            = null

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks",
        "get-token",
        "--cluster-name",
        module.eks.cluster_name
      ]
    }
  }
}

module "vpc" {
  source       = "../../modules/vpc"
  name         = local.name
  region       = var.region
  cidr         = "10.10.0.0/16"
  cluster_name = var.cluster_name
}

module "iam_core" {
  source = "../../modules/iam/eks-core"
  name   = local.name
}

module "eks" {
  source                    = "../../modules/eks"
  name                      = local.name
  region                    = var.region
  private_subnet_ids        = module.vpc.private_subnet_ids
  cluster_role_arn          = module.iam_core.cluster_role_arn
  cluster_role_dependencies = module.iam_core.cluster_role_dependencies
  node_role_arn             = module.iam_core.node_role_arn
  desired_size              = 2
  min_size                  = 2
  max_size                  = 2
  instance_type             = "t3.medium"
  vpc_id                    = module.vpc.vpc_id
  vpc_cidr                  = module.vpc.vpc_cidr

  cluster_access_config = {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }
}


# IRSA: AWS Load Balancer Controller
module "irsa_alb" {
  source               = "../../modules/iam/irsa-role"
  name                 = "${local.name}-alb-irsa"
  namespace            = "kube-system"
  service_account_name = "aws-load-balancer-controller"
  oidc_provider_arn    = module.eks.oidc_arn
  oidc_provider_url    = replace(module.eks.oidc_url, "https://", "")
  policy_arns          = ["arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess"]
}

# IRSA: ExternalDNS
module "irsa_externaldns" {
  source               = "../../modules/iam/irsa-role"
  name                 = "${local.name}-externaldns-irsa"
  namespace            = "kube-system"
  service_account_name = "external-dns"
  oidc_provider_arn    = module.eks.oidc_arn
  oidc_provider_url    = replace(module.eks.oidc_url, "https://", "")
  policy_arns = ["arn:aws:iam::aws:policy/AmazonRoute53FullAccess"]
}

# IRSA: Cluster Autoscaler
module "irsa_ca" {
  source               = "../../modules/iam/irsa-role"
  name                 = "${local.name}-cluster-autoscaler-irsa"
  namespace            = "kube-system"
  service_account_name = "cluster-autoscaler"
  oidc_provider_arn    = module.eks.oidc_arn
  oidc_provider_url    = replace(module.eks.oidc_url, "https://", "")
}

# IRSA: EBS CSI 
module "irsa_ebs_csi" {
  source               = "../../modules/iam/irsa-role"
  name                 = "${local.name}-ebs-csi-irsa"
  namespace            = "kube-system"
  service_account_name = "ebs-csi-controller-sa"
  oidc_provider_arn    = module.eks.oidc_arn
  oidc_provider_url    = replace(module.eks.oidc_url, "https://", "")
  policy_arns          = ["arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"]
}

# IRSA for S3
module "irsa_loki" {
  source = "../../modules/iam/irsa-role"

  name                 = "${local.name_prefix}-loki-irsa"
  namespace            = local.monitoring_ns
  service_account_name = "loki"
  oidc_provider_arn = module.eks.oidc_arn
  oidc_provider_url = replace(module.eks.oidc_url, "https://", "")

  inline_policies_json_list = [data.aws_iam_policy_document.loki_s3.json]
}

# IRSA for EBS CSI
data "aws_iam_policy" "AmazonEBSCSIDriverPolicy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# S3
locals {
  name_prefix        = "${var.project}-${var.env}"
  monitoring_ns      = "monitoring"
  loki_bucket_chunks = "${local.name_prefix}-loki-chunks-${random_id.loki.hex}"
  loki_bucket_ruler  = "${local.name_prefix}-loki-ruler-${random_id.loki.hex}"
  loki_bucket_admin  = "${local.name_prefix}-loki-admin-${random_id.loki.hex}"
}

resource "random_id" "loki" {
  byte_length = 2
}

resource "aws_s3_bucket" "loki_chunks" { bucket = local.loki_bucket_chunks }
resource "aws_s3_bucket" "loki_ruler" { bucket = local.loki_bucket_ruler }
resource "aws_s3_bucket" "loki_admin" { bucket = local.loki_bucket_admin }

resource "aws_s3_bucket_versioning" "loki_chunks" {
  bucket = aws_s3_bucket.loki_chunks.id
  versioning_configuration { status = "Enabled" }
}
resource "aws_s3_bucket_versioning" "loki_ruler" {
  bucket = aws_s3_bucket.loki_ruler.id
  versioning_configuration { status = "Enabled" }
}
resource "aws_s3_bucket_versioning" "loki_admin" {
  bucket = aws_s3_bucket.loki_admin.id
  versioning_configuration { status = "Enabled" }
}

# Encrypting SSE-S3
resource "aws_s3_bucket_server_side_encryption_configuration" "loki_chunks" {
  bucket = aws_s3_bucket.loki_chunks.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "loki_ruler" {
  bucket = aws_s3_bucket.loki_ruler.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "loki_admin" {
  bucket = aws_s3_bucket.loki_admin.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# No Public access
resource "aws_s3_bucket_public_access_block" "loki_chunks" {
  bucket                  = aws_s3_bucket.loki_chunks.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_s3_bucket_public_access_block" "loki_ruler" {
  bucket                  = aws_s3_bucket.loki_ruler.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_s3_bucket_public_access_block" "loki_admin" {
  bucket                  = aws_s3_bucket.loki_admin.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle for chunks
resource "aws_s3_bucket_lifecycle_configuration" "loki_chunks" {
  # Drop Loki chunk objects older than 30 days to keep the S3 bucket from growing indefinitely
  bucket = aws_s3_bucket.loki_chunks.id
  rule {
    id     = "expire-old-chunks"
    status = "Enabled"
    filter {
      prefix = ""
    }
    expiration { days = 30 }
  }
}

data "aws_iam_policy_document" "loki_s3" {
  statement {
    sid     = "ListBuckets"
    effect  = "Allow"
    actions = ["s3:ListBucket"]
    resources = [
      "arn:aws:s3:::${aws_s3_bucket.loki_chunks.bucket}",
      "arn:aws:s3:::${aws_s3_bucket.loki_ruler.bucket}",
      "arn:aws:s3:::${aws_s3_bucket.loki_admin.bucket}",
    ]
  }
  statement {
    sid     = "ObjectsRW"
    effect  = "Allow"
    actions = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = [
      "arn:aws:s3:::${aws_s3_bucket.loki_chunks.bucket}/*",
      "arn:aws:s3:::${aws_s3_bucket.loki_ruler.bucket}/*",
      "arn:aws:s3:::${aws_s3_bucket.loki_admin.bucket}/*",
    ]
  }
}

module "addons_core" {
  source                = "../../modules/addons-core"
  cluster_name          = module.eks.cluster_name
  ebs_csi_irsa_role_arn = module.irsa_ebs_csi.role_arn
  cni_version           = var.cni_version
  depends_on            = [module.eks]
}



resource "aws_eks_access_entry" "admins" {
  for_each      = toset(local.managed_admins)
  cluster_name  = module.eks.cluster_name
  principal_arn = each.value
  type          = "STANDARD"
  depends_on    = [module.eks]
}

resource "aws_eks_access_policy_association" "admins_cluster" {
  for_each      = aws_eks_access_entry.admins
  cluster_name  = module.eks.cluster_name
  principal_arn = each.value.principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  access_scope { type = "cluster" }
}

resource "kubernetes_namespace" "monitoring" {
  count = var.create_monitoring_ns ? 1 : 0
  metadata { name = var.monitoring_ns }

  timeouts {
    delete = "15m"
  }
}

resource "kubernetes_service_account" "loki" {
  metadata {
    name = "loki"
    namespace = local.monitoring_ns
    annotations = {
      "eks.amazonaws.com/role-arn" = module.irsa_loki.role_arn
    }
  }
  automount_service_account_token = true
}

# ServiceAccounts (kubernetes_manifest/kubernetes_service_account)
resource "kubernetes_service_account" "alb_sa" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = module.irsa_alb.role_arn
    }
  }
  depends_on = [module.irsa_alb, aws_eks_access_policy_association.admins_cluster]
}

resource "kubernetes_service_account" "extdns_sa" {
  metadata {
    name      = "external-dns"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = module.irsa_externaldns.role_arn
    }
  }
  automount_service_account_token = true
  depends_on                      = [module.irsa_externaldns, aws_eks_access_policy_association.admins_cluster]
}

resource "kubernetes_service_account" "ca_sa" {
  metadata {
    name      = "cluster-autoscaler"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = module.irsa_ca.role_arn
    }
    labels = {
      "k8s-addon" = "cluster-autoscaler.addons.k8s.io"
    }
  }
  automount_service_account_token = true
  depends_on                      = [module.irsa_ca, aws_eks_access_policy_association.admins_cluster]
}

module "addons_helm" {
  source = "../../modules/addons-helm"

  region       = var.region
  cluster_name = module.eks.cluster_name
  vpc_id       = module.vpc.vpc_id

  domain                 = var.domain
  grafana_admin_password = var.grafana_admin_password
  grafana_host           = "grafana.dev.${var.domain}"

  # Versions from versions.auto.tfvars
  alb_chart_version = var.alb_chart_version
  ca_chart_version  = var.ca_chart_version

  #loki
  enable_loki = true
  monitoring_ns = local.monitoring_ns

  loki_values_yaml = templatefile("${path.module}/values/loki.yaml.tmpl", {
    bucket_chunks = aws_s3_bucket.loki_chunks.bucket
    bucket_ruler  = aws_s3_bucket.loki_ruler.bucket
    bucket_admin  = aws_s3_bucket.loki_admin.bucket
    region        = var.region
    storage_class = var.loki_storage_class
  })

  depends_on = [module.eks, module.addons_core, kubernetes_service_account.alb_sa, kubernetes_service_account.ca_sa, kubernetes_service_account.extdns_sa, kubernetes_service_account.loki]
}

# ECR 
module "ecr" {
  source = "../../modules/ecr"
  repos  = ["pet-api", "pet-web"]
}
