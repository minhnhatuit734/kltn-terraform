resource "kubernetes_namespace_v1" "argocd" {
  metadata {
    name = var.argocd_namespace

    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }

  depends_on = [
    time_sleep.wait_for_eks_api
  ]
}

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version
  namespace        = var.argocd_namespace
  create_namespace = false

  wait                       = true
  wait_for_jobs              = true
  timeout                    = 900
  atomic                     = true
  cleanup_on_fail            = true
  disable_openapi_validation = true

  set {
  name  = "crds.keep"
  value = "false"
}
  skip_crds        = false

  dynamic "set" {
    for_each = [
      {
        name  = "server.service.type"
        value = "ClusterIP"
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

    content {
      name  = set.value.name
      value = set.value.value
    }
  }

  depends_on = [
    kubernetes_namespace_v1.argocd
  ]
}

resource "kubectl_manifest" "argocd_ingress" {
  yaml_body = <<-YAML
    apiVersion: networking.k8s.io/v1
    kind: Ingress
    metadata:
      name: argocd-ingress
      namespace: ${var.argocd_namespace}
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
            - argocd.uittravel.shop
          secretName: argocd-tls
      rules:
        - host: argocd.uittravel.shop
          http:
            paths:
              - path: /
                pathType: Prefix
                backend:
                  service:
                    name: argocd-server
                    port:
                      number: 80
  YAML

  depends_on = [
    helm_release.argocd,
    kubectl_manifest.letsencrypt_prod_cluster_issuer
  ]
}

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
        path: overlays/dev
      destination:
        server: https://kubernetes.default.svc
        namespace: dev
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
  YAML

  depends_on = [
    helm_release.argocd,
    kubernetes_secret_v1.kltn_app_secrets_dev
  ]
}

resource "kubectl_manifest" "argocd_app_kltn_prod" {
  yaml_body = <<-YAML
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: kltn-prod
      namespace: ${var.argocd_namespace}
      finalizers:
        - resources-finalizer.argocd.argoproj.io
    spec:
      project: default
      source:
        repoURL: https://github.com/minhnhatuit734/k8s-manifests.git
        targetRevision: main
        path: overlays/prod
      destination:
        server: https://kubernetes.default.svc
        namespace: prod
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
  YAML

  depends_on = [
    helm_release.argocd,
    kubernetes_secret_v1.kltn_app_secrets_prod
  ]
}