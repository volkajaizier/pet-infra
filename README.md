# pet-infra

Terraform definitions for a dev EKS environment. The stack is applied from
`terraform/environments/dev` and builds the following in order:

1. **Networking (VPC module)** – VPC, public/private subnets, NAT/IGW and route
   tables tagged for EKS discovery.
2. **Core IAM (iam/eks-core module)** – cluster and node roles with the
   standard AWS-managed policies.
3. **EKS cluster (eks module)** – control plane, launch template, managed node
   group, OIDC provider and security-group wiring.
4. **Support services**
   - Dynamic `aws_s3_bucket` resources for Loki chunks/ruler/admin data with
     versioning, encryption and lifecycle policies.
   - Random ID for unique bucket suffixes.
5. **IRSA roles (iam/irsa-role module)** – service accounts for ALB
   controller, ExternalDNS, Cluster Autoscaler, EBS CSI and Loki.
6. **Cluster access** – optional `aws_eks_access_entry` resources granting
   admin to principals listed in `cluster_admin_principals`.
7. **Kubernetes primitives** – monitoring namespace and annotated service
   accounts bound to the IRSA roles.
8. **Add-ons**
   - `addons-core` module installs the core AWS EKS add-ons (VPC CNI, kube-proxy,
     CoreDNS, EBS CSI driver).
   - `addons-helm` module deploys Helm releases: AWS Load Balancer Controller,
     ExternalDNS, Metrics Server, Cluster Autoscaler, kube-prometheus-stack,
     Loki and Promtail (Loki/promtail are gated by `enable_loki`).
9. **ECR repositories** – `pet-api` and `pet-web` registries for application
   images.

Replace or override the sample values in `terraform/environments/dev/dev.auto.tfvars`
with your own project, region and secrets before applying.
