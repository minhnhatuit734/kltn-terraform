resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = "4.15.1"
  namespace        = "ingress-nginx"
  create_namespace = true

  wait                       = true
  wait_for_jobs              = true
  timeout                    = 900
  atomic                     = true
  cleanup_on_fail            = true
  disable_openapi_validation = true

  values = [
    yamlencode({
      controller = {
        replicaCount = 1

        ingressClass = "nginx"

        ingressClassResource = {
          name    = "nginx"
          enabled = true
          default = true
        }

        service = {
          type = "LoadBalancer"

          annotations = {
            "service.beta.kubernetes.io/aws-load-balancer-type"                              = "nlb"
            "service.beta.kubernetes.io/aws-load-balancer-scheme"                            = "internet-facing"
            "service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled" = "true"
          }
        }
      }
    })
  ]

  depends_on = [
    time_sleep.wait_for_eks_api
  ]
}