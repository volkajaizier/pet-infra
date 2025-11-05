terraform {
  required_version = ">= 1.6"
}

resource "helm_release" "alb" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = var.alb_chart_version

  timeout         = 900
  wait            = true
  atomic          = true
  cleanup_on_fail = true

  values = [yamlencode({
    clusterName = var.cluster_name
    region      = var.region
    vpcId       = var.vpc_id
    serviceAccount = {
      create = false
      name   = "aws-load-balancer-controller"
    }
    podLabels = { "app.kubernetes.io/name" = "aws-load-balancer-controller" }
  })]
}

# external-dns

resource "helm_release" "external_dns" {
  name       = "external-dns"
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  namespace  = "kube-system"
  version    = "1.19.0"

  timeout           = 1200
  wait              = true
  wait_for_jobs     = true
  atomic            = true
  cleanup_on_fail   = true
  dependency_update = true

  values = [yamlencode(
    merge(
      {
        serviceAccount = {
          create = false
          name   = "external-dns"
        }

        sources = ["service", "ingress"]

        provider   = "aws"
        policy     = "upsert-only"
        registry   = "txt"
        txtOwnerId = var.cluster_name
        aws = {
          zoneType = "public"
        }
      },

      var.domain_filters != null
      ? { domainFilters = var.domain_filters }
      : (var.domain != null ? { domainFilters = [var.domain] } : {})
    )
  )]
}



# metrics-server

resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  namespace  = "kube-system"

  values = [yamlencode({
    args = [
      "--kubelet-preferred-address-types=InternalIP,Hostname,ExternalIP",
      "--kubelet-insecure-tls"
    ]
  })]
}

# Cluster Autoscaler

resource "helm_release" "cluster_autoscaler" {
  name       = "cluster-autoscaler"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  namespace  = "kube-system"
  version    = var.ca_chart_version

  timeout = 900

  wait            = true
  atomic          = true
  cleanup_on_fail = true

  values = [yamlencode({
    autoDiscovery = { clusterName = var.cluster_name }
    awsRegion     = var.region
    rbac = {
      serviceAccount = {
        create = false
        name   = "cluster-autoscaler"
      }
    }
    extraArgs = {
      "balance-similar-node-groups"   = "true"
      "skip-nodes-with-local-storage" = "false"
      "skip-nodes-with-system-pods"   = "false"
      "scan-interval"                 = "10s"
      "expander"                      = "least-waste"
    }
  })]
}

# kube-prometheus-stack (Prom+Grafana)

resource "helm_release" "kps" {
  name             = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  namespace        = var.monitoring_ns
  create_namespace = false

  values = [yamlencode({
    grafana = {
      adminPassword = var.grafana_admin_password
      ingress = {
        enabled          = true
        ingressClassName = "alb"
        annotations = {
          "alb.ingress.kubernetes.io/scheme" = "internet-facing"
        }
        hosts = [var.grafana_host]
      }
    }
    prometheus = {
      prometheusSpec = {
        retention = "15d"
      }
    }
  })]

  depends_on = [helm_release.alb]
}


# Loki + promtail
resource "helm_release" "loki" {
  count      = var.enable_loki ? 1 : 0
  name       = "loki"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki"
  version    = var.loki_chart_version

  namespace        = var.monitoring_ns
  create_namespace = false
  set {
    name  = "serviceAccount.create"
    value = "false"
  }
  set {
    name  = "serviceAccount.name"
    value = "loki"
  }

  # main config of the chart
  values = [var.loki_values_yaml]

  timeout         = 600
  wait            = true
  atomic          = true
  cleanup_on_fail = true

  depends_on = [helm_release.alb]
}


resource "helm_release" "promtail" {
  count      = var.enable_loki ? 1 : 0
  name       = "promtail"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "promtail"
  namespace  = var.monitoring_ns
  values = [yamlencode({
    config = {
      snippets = {
        pipelineStages = [
          { cri = {} }
        ]
      }
    }
  })]

  depends_on = [helm_release.alb]
}
