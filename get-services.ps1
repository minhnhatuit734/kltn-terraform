# Script lay thong tin cac dich vu tu EKS cluster kltn-eks-dev

Write-Host "=== 1. Cap nhat kubeconfig ===" -ForegroundColor Cyan
aws eks update-kubeconfig --region ap-southeast-1 --name kltn-eks-dev

Write-Host "`n=== 2. Thong tin dich vu ArgoCD ===" -ForegroundColor Cyan
$argocd_host = kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
if ($argocd_host) {
    Write-Host "ArgoCD URL: http://$argocd_host" -ForegroundColor Green
} else {
    Write-Host "Dang cho LoadBalancer cap phat Hostname cho ArgoCD..." -ForegroundColor Yellow
    kubectl get svc argocd-server -n argocd
}

$null = kubectl get secret argocd-initial-admin-secret -n argocd 2>$null
if ($LASTEXITCODE -eq 0) {
    $argocd_secret = kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}"
    $argocd_pass = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($argocd_secret))
    Write-Host "Username  : admin"
    Write-Host "Password  : $argocd_pass"
} else {
    Write-Host "Mat khau khoi tao da duoc thay doi hoac secret khong ton tai." -ForegroundColor Yellow
}

Write-Host "`n=== 3. Thong tin dich vu Grafana ===" -ForegroundColor Cyan
$grafana_host = kubectl get svc kube-prometheus-stack-grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
if ($grafana_host) {
    Write-Host "Grafana URL: http://$grafana_host" -ForegroundColor Green
} else {
    Write-Host "Dang cho LoadBalancer cap phat Hostname cho Grafana..." -ForegroundColor Yellow
    kubectl get svc kube-prometheus-stack-grafana -n monitoring
}
Write-Host "Username   : admin"
Write-Host "Password   : Admin@KLTN2024!"

Write-Host "`n=== 4. Thong tin dich vu Prometheus ===" -ForegroundColor Cyan
Write-Host "Prometheus khong expose ra ngoai. Chay lenh sau de truy cap tai http://localhost:9090 :" -ForegroundColor Yellow
Write-Host "kubectl port-forward svc/kube-prometheus-stack-prometheus -n monitoring 9090:9090" -ForegroundColor Magenta
