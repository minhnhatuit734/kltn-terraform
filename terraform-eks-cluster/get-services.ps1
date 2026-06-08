Write-Host "=== 1. Cap nhat kubeconfig ===" -ForegroundColor Cyan
aws eks update-kubeconfig --region ap-southeast-1 --name kltn-eks-dev

Write-Host "`n=== 2. NGINX Ingress LoadBalancer ===" -ForegroundColor Cyan
$ingressHost = kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

if ($ingressHost) {
    Write-Host "NGINX Ingress LB: http://$ingressHost" -ForegroundColor Green
} else {
    Write-Host "Dang cho LoadBalancer cap phat hostname cho ingress-nginx..." -ForegroundColor Yellow
    kubectl get svc ingress-nginx-controller -n ingress-nginx
}

Write-Host "`n=== 3. ArgoCD ===" -ForegroundColor Cyan
Write-Host "ArgoCD URL: https://argocd.uittravel.shop" -ForegroundColor Green

$null = kubectl get secret argocd-initial-admin-secret -n argocd 2>$null
if ($LASTEXITCODE -eq 0) {
    $argocdSecret = kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}"
    $argocdPass = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($argocdSecret))
    Write-Host "Username  : admin"
    Write-Host "Password  : $argocdPass"
} else {
    Write-Host "Mat khau khoi tao da duoc thay doi hoac secret khong ton tai." -ForegroundColor Yellow
}

Write-Host "`n=== 4. Grafana ===" -ForegroundColor Cyan
Write-Host "Grafana URL: https://grafana.uittravel.shop" -ForegroundColor Green
Write-Host "Username   : admin"
Write-Host "Password   : xem terraform.tfvars -> grafana_admin_password"

Write-Host "`n=== 5. Application URLs ===" -ForegroundColor Cyan
Write-Host "Dev Frontend : https://dev.uittravel.shop"
Write-Host "Dev API      : https://api-dev.uittravel.shop"
Write-Host "Prod Frontend: https://prod.uittravel.shop"
Write-Host "Prod API     : https://api-prod.uittravel.shop"

Write-Host "`n=== 6. Prometheus ===" -ForegroundColor Cyan
Write-Host "Prometheus khong expose public. Chay lenh sau de truy cap tai http://localhost:9090 :" -ForegroundColor Yellow
Write-Host "kubectl port-forward svc/kube-prometheus-stack-prometheus -n monitoring 9090:9090" -ForegroundColor Magenta

Write-Host "`n=== 7. Chatbot MLOps Services (EC2) ===" -ForegroundColor Cyan
Write-Host "MLflow UI      : http://46.137.246.147:5000"
Write-Host "MinIO S3 UI    : http://46.137.246.147:9001"
Write-Host "MinIO API      : http://46.137.246.147:9000"
Write-Host "S3 Username    : admin"
Write-Host "S3 Password    : password123"
Write-Host "Chatbot Domain : https://chatbot.uittravel.shop"
Write-Host "MLflow Domain  : https://mlflow.uittravel.shop"

Write-Host "`n=== 8. Jenkins CI/CD ===" -ForegroundColor Cyan
Write-Host "Jenkins URL    : http://54.254.94.172:8080"