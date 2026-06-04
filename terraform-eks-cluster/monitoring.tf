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
        value = "ClusterIP"
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
      {
        name  = "nodeExporter.enabled"
        value = "true"
      },
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

resource "kubectl_manifest" "grafana_ingress" {
  yaml_body = <<-YAML
    apiVersion: networking.k8s.io/v1
    kind: Ingress
    metadata:
      name: grafana-ingress
      namespace: ${var.monitoring_namespace}
      annotations:
        cert-manager.io/cluster-issuer: letsencrypt-prod
        nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
        nginx.ingress.kubernetes.io/ssl-redirect: "true"
        nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
        nginx.ingress.kubernetes.io/proxy-body-size: "20m"
    spec:
      ingressClassName: nginx
      tls:
        - hosts:
            - grafana.uittravel.shop
          secretName: grafana-tls
      rules:
        - host: grafana.uittravel.shop
          http:
            paths:
              - path: /
                pathType: Prefix
                backend:
                  service:
                    name: kube-prometheus-stack-grafana
                    port:
                      number: 80
  YAML

  depends_on = [
    helm_release.kube_prometheus_stack,
    kubectl_manifest.letsencrypt_prod_cluster_issuer
  ]
}