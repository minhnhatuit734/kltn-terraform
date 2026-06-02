# KLTN Terraform Infrastructure

Repo này dùng Terraform để dựng hạ tầng AWS cho hệ thống KLTN, gồm EKS cluster, ingress-nginx, ArgoCD, monitoring bằng kube-prometheus-stack/Grafana, Kubernetes secrets cho ứng dụng, và DNS Cloudflare.

File quan trọng nhất để chạy được là `terraform-eks-cluster/terraform.tfvars`.

Tạo file này bằng cách copy file mẫu:

```powershell
Copy-Item terraform-eks-cluster\terraform.tfvars.example terraform-eks-cluster\terraform.tfvars
```

Sau đó mở `terraform-eks-cluster/terraform.tfvars` và điền giá trị thật.

## Yêu cầu trước khi chạy

Cài các công cụ sau:

- Terraform `>= 1.5.7`
- AWS CLI
- kubectl
- Helm
- Tài khoản AWS đã có quyền tạo VPC, EKS, EC2, IAM, Load Balancer
- Cloudflare API token có quyền `Zone Read` và `DNS Edit`

Đăng nhập AWS:

```powershell
aws configure
aws sts get-caller-identity
```

## Cấu trúc repo

```text
.
├── terraform-eks-cluster/   # Hạ tầng EKS chính
├── terraform_CI/            # Hạ tầng EC2 CI/Jenkins/SonarQube
├── get-services.ps1         # Script lấy URL ArgoCD, Grafana, Prometheus
├── argocd.yml               # Manifest ArgoCD tham khảo
└── secret-example.yaml      # Ví dụ Kubernetes Secret
```

## Cấu hình Terraform EKS

Các biến bắt buộc trong `terraform-eks-cluster/terraform.tfvars`:

```hcl
cloudflare_api_token = "replace-me"
cloudflare_zone_id   = "replace-me"

jwt_secret       = "replace-me"
mongo_atlas_uri  = "replace-me"
together_api_key = "replace-me"
```

Các biến có default nhưng có thể đổi:

```hcl
aws_region         = "ap-southeast-1"
cluster_name       = "kltn-eks-dev"
kubernetes_version = "1.33"

node_instance_types = ["m7i-flex.large"]
node_capacity_type  = "ON_DEMAND"
node_desired_size   = 2
node_min_size       = 2
node_max_size       = 3

grafana_admin_password = "Admin@KLTN2024!"
```

## Triển khai EKS

Chạy trong thư mục `terraform-eks-cluster`:

```powershell
cd terraform-eks-cluster
terraform init
terraform validate
terraform plan
terraform apply
```

Khi Terraform hỏi xác nhận, nhập:

```text
yes
```

Terraform sẽ tạo:

- VPC và public subnets
- EKS cluster
- EKS managed node group
- ingress-nginx
- namespace `dev`, `prod`, `argocd`, `monitoring`
- Kubernetes secret `kltn-app-secrets` cho `dev` và `prod`
- ArgoCD và 2 application `kltn-dev`, `kltn-prod`
- kube-prometheus-stack và Grafana
- DNS Cloudflare: `dev`, `api-dev`, `prod`, `api-prod`

## Kết nối kubectl

Sau khi `terraform apply` xong:

```powershell
aws eks update-kubeconfig --region ap-southeast-1 --name kltn-eks-dev
kubectl get nodes -o wide
```

Node cần ở trạng thái `Ready`.

## Lấy URL dịch vụ

Có thể chạy script:

```powershell
.\get-services.ps1
```

Hoặc lấy thủ công:

```powershell
kubectl get svc argocd-server -n argocd
kubectl get svc kube-prometheus-stack-grafana -n monitoring
kubectl -n dev get svc
kubectl -n prod get svc
```

Lấy mật khẩu ArgoCD mặc định:

```powershell
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}"
```

Trên PowerShell có thể decode base64:

```powershell
[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String("<password-base64>"))
```

Grafana mặc định:

```text
Username: admin
Password: giá trị grafana_admin_password trong terraform.tfvars
```

Prometheus không expose public. Dùng port-forward:

```powershell
kubectl port-forward svc/kube-prometheus-stack-prometheus -n monitoring 9090:9090
```

Sau đó mở `http://localhost:9090`.

## Kiểm tra ArgoCD và ứng dụng

```powershell
kubectl -n argocd get applications
kubectl -n dev get all
kubectl -n prod get all
kubectl -n dev get secret kltn-app-secrets
kubectl -n prod get secret kltn-app-secrets
```

Kết quả mong muốn:

- ArgoCD application ở trạng thái `Synced` và `Healthy`
- Pod trong `dev` và `prod` ở trạng thái `Running`
- Secret `kltn-app-secrets` tồn tại trong cả 2 namespace

## Terraform CI

Thư mục `terraform_CI` dựng một EC2 phục vụ CI. Trước khi chạy cần đảm bảo AWS account có key pair tên:

```text
jenkin_keypair
```

Chạy:

```powershell
cd terraform_CI
terraform init
terraform validate
terraform plan
terraform apply
```

Lưu ý: AMI ID trong `terraform_CI/main.tf` đang cố định theo region `ap-southeast-1`. Nếu đổi region cần kiểm tra lại AMI.

## Dọn hạ tầng để tránh tốn phí

Xóa EKS stack:

```powershell
cd terraform-eks-cluster
terraform destroy
```

Xóa CI stack nếu đã tạo:

```powershell
cd terraform_CI
terraform destroy
```

Không nên chỉ stop EC2 thủ công trên AWS Console vì EKS, Load Balancer hoặc các tài nguyên liên quan vẫn có thể phát sinh chi phí.

