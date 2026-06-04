# destroy.ps1
# Chạy trong thư mục: C:\Project\kltn-terraform\terraform-eks-cluster

$ErrorActionPreference = "Continue"

$ClusterName = "kltn-eks-dev"
$Region = "ap-southeast-1"

Write-Host "=== Step 0: Check current directory ===" -ForegroundColor Cyan
Write-Host "Current path: $(Get-Location)"

Write-Host "=== Step 1: Update kubeconfig ===" -ForegroundColor Cyan
aws eks update-kubeconfig --name $ClusterName --region $Region

Write-Host "=== Step 2: Delete EKS nodegroups first ===" -ForegroundColor Cyan

$nodegroups = aws eks list-nodegroups `
  --cluster-name $ClusterName `
  --region $Region `
  --query "nodegroups[]" `
  --output text 2>$null

if ($nodegroups) {
    foreach ($ng in $nodegroups.Split()) {
        Write-Host "Deleting nodegroup: $ng" -ForegroundColor Yellow

        aws eks delete-nodegroup `
          --cluster-name $ClusterName `
          --nodegroup-name $ng `
          --region $Region

        Write-Host "Waiting for nodegroup to be deleted: $ng"

        while ($true) {
            $status = aws eks describe-nodegroup `
              --cluster-name $ClusterName `
              --nodegroup-name $ng `
              --region $Region `
              --query "nodegroup.status" `
              --output text 2>$null

            if (-not $status) {
                Write-Host "Nodegroup deleted: $ng" -ForegroundColor Green
                break
            }

            Write-Host "Current nodegroup status: $status"
            Start-Sleep -Seconds 30
        }
    }
} else {
    Write-Host "No nodegroups found or cluster not available." -ForegroundColor Yellow
}

Write-Host "=== Step 3: Delete LoadBalancer services if Kubernetes API is available ===" -ForegroundColor Cyan

kubectl delete service -n ingress-nginx ingress-nginx-controller --ignore-not-found=true 2>$null
kubectl delete service -n argocd argocd-server --ignore-not-found=true 2>$null
kubectl delete service -n monitoring kube-prometheus-stack-grafana --ignore-not-found=true 2>$null

Write-Host "Waiting 90s for AWS to delete LoadBalancers..."
Start-Sleep -Seconds 90

Write-Host "=== Step 4: Remove broken Kubernetes/Helm resources from Terraform state ===" -ForegroundColor Cyan

$stateResources = terraform state list

$resourcesToRemove = @(
    "helm_release.argocd",
    "kubernetes_namespace_v1.prod",
    "kubernetes_namespace_v1.monitoring",
    "kubernetes_namespace_v1.argocd"
)

foreach ($res in $resourcesToRemove) {
    if ($stateResources -contains $res) {
        Write-Host "Removing from state: $res" -ForegroundColor Yellow
        terraform state rm $res
    } else {
        Write-Host "Not in state, skip: $res"
    }
}

Write-Host "=== Step 5: Terraform destroy ===" -ForegroundColor Cyan
terraform destroy -parallelism=3 -auto-approve