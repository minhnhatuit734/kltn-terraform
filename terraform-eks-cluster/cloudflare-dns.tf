resource "time_sleep" "wait_for_ingress_nginx_lb" {
  create_duration = "90s"

  depends_on = [
    helm_release.ingress_nginx
  ]
}

data "kubernetes_service_v1" "ingress_nginx_controller" {
  metadata {
    name      = "ingress-nginx-controller"
    namespace = "ingress-nginx"
  }

  depends_on = [
    time_sleep.wait_for_ingress_nginx_lb
  ]
}

locals {
  ingress_nginx_lb_hostname = data.kubernetes_service_v1.ingress_nginx_controller.status[0].load_balancer[0].ingress[0].hostname
}

resource "cloudflare_dns_record" "dev_frontend" {
  zone_id = var.cloudflare_zone_id

  name    = "dev"
  type    = "CNAME"
  content = local.ingress_nginx_lb_hostname
  ttl     = 1
  proxied = false
}

resource "cloudflare_dns_record" "dev_api" {
  zone_id = var.cloudflare_zone_id

  name    = "api-dev"
  type    = "CNAME"
  content = local.ingress_nginx_lb_hostname
  ttl     = 1
  proxied = false
}

resource "cloudflare_dns_record" "prod_frontend" {
  zone_id = var.cloudflare_zone_id

  name    = "prod"
  type    = "CNAME"
  content = local.ingress_nginx_lb_hostname
  ttl     = 1
  proxied = false
}

resource "cloudflare_dns_record" "prod_api" {
  zone_id = var.cloudflare_zone_id

  name    = "api-prod"
  type    = "CNAME"
  content = local.ingress_nginx_lb_hostname
  ttl     = 1
  proxied = false
}
