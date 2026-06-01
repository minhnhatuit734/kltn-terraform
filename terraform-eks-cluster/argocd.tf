# ──────────────────────────────────────────────
# Namespace: argocd
# ──────────────────────────────────────────────
resource "kubernetes_namespace_v1" "argocd" {
  metadata {
    name = var.argocd_namespace
    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }

  depends_on = [module.eks]
}

# ──────────────────────────────────────────────
# Helm Release: ArgoCD
# Chart: https://argoproj.github.io/argo-helm
# ──────────────────────────────────────────────
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version
  namespace        = var.argocd_namespace
  create_namespace = false
  timeout          = 600
  atomic           = true
  cleanup_on_fail  = true

  set = [
    {
      name  = "server.service.type"
      value = "LoadBalancer"
    },
    {
      name  = "server.extraArgs[0]"
      value = "--insecure"
    },
    {
      name  = "server.resources.requests.cpu"
      value = "100m"
    },
    {
      name  = "server.resources.requests.memory"
      value = "128Mi"
    },
    {
      name  = "server.resources.limits.cpu"
      value = "500m"
    },
    {
      name  = "server.resources.limits.memory"
      value = "512Mi"
    }
  ]

  depends_on = [kubernetes_namespace_v1.argocd]
}


# ──────────────────────────────────────────────
# ArgoCD Application: kltn-dev
# ──────────────────────────────────────────────
resource "kubectl_manifest" "argocd_app_kltn_dev" {
  yaml_body = <<-YAML
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: kltn-dev
      namespace: ${var.argocd_namespace}
      finalizers:
        - resources-finalizer.argocd.argoproj.io
    spec:
      project: default
      source:
        repoURL: https://github.com/minhnhatuit734/k8s-manifests.git
        targetRevision: main
        path: .
      destination:
        server: https://kubernetes.default.svc
        namespace: dev
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
  YAML

  depends_on = [helm_release.argocd]
}
