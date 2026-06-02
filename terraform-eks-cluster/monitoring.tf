# ──────────────────────────────────────────────
# Namespace: monitoring
# ──────────────────────────────────────────────
resource "kubernetes_namespace_v1" "monitoring" {
  metadata {
    name = var.monitoring_namespace
    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }

  depends_on = [
    time_sleep.wait_for_eks_api
  ]
}

# ──────────────────────────────────────────────
# Helm Release: kube-prometheus-stack
# ──────────────────────────────────────────────
resource "helm_release" "kube_prometheus_stack" {
  name             = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = var.kube_prometheus_stack_chart_version
  namespace        = var.monitoring_namespace
  create_namespace = false

  wait                       = true
  wait_for_jobs              = true
  timeout                    = 1200
  atomic                     = true
  cleanup_on_fail            = true
  disable_openapi_validation = true

  dynamic "set" {
    for_each = [
      # Grafana
      {
        name  = "grafana.enabled"
        value = "true"
      },
      {
        name  = "grafana.adminPassword"
        value = var.grafana_admin_password
      },
      {
        name  = "grafana.service.type"
        value = "LoadBalancer"
      },
      {
        name  = "grafana.persistence.enabled"
        value = "false"
      },
      {
        name  = "grafana.defaultDashboardsEnabled"
        value = "true"
      },
      {
        name  = "grafana.defaultDashboardsTimezone"
        value = "Asia/Ho_Chi_Minh"
      },

      # Prometheus
      {
        name  = "prometheus.enabled"
        value = "true"
      },
      {
        name  = "prometheus.prometheusSpec.storageSpec"
        value = ""
      },
      {
        name  = "prometheus.prometheusSpec.retention"
        value = var.prometheus_retention
      },
      {
        name  = "prometheus.prometheusSpec.resources.requests.cpu"
        value = "200m"
      },
      {
        name  = "prometheus.prometheusSpec.resources.requests.memory"
        value = "512Mi"
      },
      {
        name  = "prometheus.prometheusSpec.resources.limits.cpu"
        value = "1000m"
      },
      {
        name  = "prometheus.prometheusSpec.resources.limits.memory"
        value = "2Gi"
      },

      # Alertmanager
      {
        name  = "alertmanager.enabled"
        value = "true"
      },
      {
        name  = "alertmanager.service.type"
        value = "ClusterIP"
      },
      {
        name  = "alertmanager.alertmanagerSpec.storage"
        value = ""
      },

      # Node Exporter
      {
        name  = "nodeExporter.enabled"
        value = "true"
      },

      # Kube State Metrics
      {
        name  = "kubeStateMetrics.enabled"
        value = "true"
      }
    ]

    content {
      name  = set.value.name
      value = set.value.value
    }
  }

  depends_on = [
    kubernetes_namespace_v1.monitoring,
    time_sleep.wait_for_eks_api
  ]
}
