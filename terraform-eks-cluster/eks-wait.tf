resource "time_sleep" "wait_for_eks_api" {
  create_duration = "180s"

  depends_on = [
    module.eks
  ]
}