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
resource "null_resource" "cleanup_loadbalancer" {
  triggers = {
    cluster_name = module.eks.cluster_name
    region       = "ap-southeast-1"
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      aws eks update-kubeconfig --name ${self.triggers.cluster_name} --region ${self.triggers.region}
      kubectl delete service -n ingress-nginx ingress-nginx-controller --ignore-not-found=true
      echo "Waiting 60s for LoadBalancer to be deleted..."
      sleep 60
    EOT
    interpreter = ["C:/Program Files/Git/bin/bash.exe", "-c"]
  }

  depends_on = [helm_release.ingress_nginx]
}