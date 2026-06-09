# 🚀 KLTN — Terraform Infrastructure for Travel Web Application

> **Khóa Luận Tốt Nghiệp (KLTN)** — Hệ thống hạ tầng DevSecOps hoàn chỉnh trên AWS, triển khai tự động bằng Terraform, CD bằng ArgoCD và giám sát bằng Prometheus/Grafana.

---

## 📋 Mục lục

- [Tổng quan dự án](#tổng-quan-dự-án)
- [Kiến trúc hệ thống](#kiến-trúc-hệ-thống)
- [Luồng CI/CD](#luồng-cicd)
- [Cấu trúc thư mục](#cấu-trúc-thư-mục)
- [Thành phần hạ tầng](#thành-phần-hạ-tầng)
- [Yêu cầu](#yêu-cầu)
- [Hướng dẫn triển khai](#hướng-dẫn-triển-khai)
- [Biến môi trường](#biến-môi-trường)
- [Endpoints & URLs](#endpoints--urls)
- [Monitoring](#monitoring)
- [Xóa hạ tầng](#xóa-hạ-tầng)

---

## 📌 Tổng quan dự án

Dự án xây dựng pipeline **DevSecOps end-to-end** cho ứng dụng web đặt tour du lịch (`uittravel.shop`) với kiến trúc microservices. Toàn bộ hạ tầng được quản lý bằng **Terraform** và chia thành 4 module chính:

| Module | Mục đích |
|---|---|
| `terraform_CI` | Provision EC2 chứa Jenkins + SonarQube (CI server) |
| `argocd/` | Provision EC2 + K3s + ArgoCD standalone (ArgoCD server) |
| `terraform-eks-cluster/` | Provision AWS EKS cluster + toàn bộ add-ons |
| `terraform-ec2-chatbot/` | Provision EC2 chạy Chatbot AI (Rasa, MLflow, MinIO) |

---

## 🏗️ Kiến trúc hệ thống

Kiến trúc tổng thể khi triển khai trên AWS với ArgoCD làm CD controller:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              INTERNET / USERS                               │
└──────────────────┬──────────────────────────────────┬───────────────────────┘
                   │                                  │
         HTTPS *.uittravel.shop              Developer / CI Push
                   │                                  │
                   ▼                                  ▼
┌──────────────────────────────┐     ┌────────────────────────────────────────┐
│        Cloudflare DNS        │     │           GitHub Repositories          │
│  (CNAME → NLB hostname)      │     │                                        │
│  dev.uittravel.shop          │     │  ┌─────────────────┐  ┌─────────────┐  │
│  api-dev.uittravel.shop      │     │  │  app-source repo│  │k8s-manifests│  │
│  prod.uittravel.shop         │     │  │  (microservices)│  │  (GitOps)   │  │
│  api-prod.uittravel.shop     │     │  └────────┬────────┘  └──────┬──────┘  │
│  argocd.uittravel.shop       │     │           │ push             │ watch   │
│  grafana.uittravel.shop      │     └───────────┼──────────────────┼─────────┘
│  chatbot.uittravel.shop      │                 │                  │
│  mlflow.uittravel.shop       │                 │                  │
└──────────────────┬───────────┘                 │                  │
                   │                             ▼                  │
                   │                ┌────────────────────────┐      │
                   │                │    CI Server (EC2)     │      │
                   │                │  ap-southeast-1a       │      │
                   │                │  ┌──────────────────┐  │      │
                   │                │  │  Jenkins :8080   │  │      │
                   │                │  │  SonarQube :9000 │  │      │
                   │                │  │  Snyk            │  │      │
                   │                │  │  Trivy           │  │      │
                   │                │  └──────────┬───────┘  │      │
                   │                └─────────────┼──────────┘      │
                   │                              │ push image       │
                   │                              ▼                  │
                   │                   ┌──────────────────┐          │
                   │                   │   Docker Hub /   │          │
                   │                   │   ECR Registry   │          │
                   │                   └──────────────────┘          │
                   │                                                  │
                   ▼                                                  ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                    AWS EKS Cluster  (ap-southeast-1)                        │
│                    VPC: 10.10.0.0/16                                        │
│  ┌───────────────────┐   ┌───────────────────┐                             │
│  │  Public Subnet 1  │   │  Public Subnet 2  │   (Multi-AZ)                │
│  │  10.10.1.0/24     │   │  10.10.2.0/24     │                             │
│  │  ap-southeast-1a  │   │  ap-southeast-1b  │                             │
│  └─────────┬─────────┘   └────────┬──────────┘                             │
│            └──────────┬───────────┘                                         │
│                       │                                                      │
│  ┌────────────────────▼────────────────────────────────────────────────┐    │
│  │              EKS Managed Node Group  (m7i-flex.large × 2-3)        │    │
│  │                                                                     │    │
│  │  ┌──────────────────────────────────────────────────────────────┐  │    │
│  │  │  namespace: ingress-nginx                                    │  │    │
│  │  │  ┌─────────────────────────────────────────────────────┐    │  │    │
│  │  │  │  NGINX Ingress Controller (AWS NLB - internet-facing)│    │  │    │
│  │  │  │  Port 80 / 443 → Routes to backend services          │    │  │    │
│  │  │  └─────────────────────────────────────────────────────┘    │  │    │
│  │  └──────────────────────────────────────────────────────────────┘  │    │
│  │                                                                     │    │
│  │  ┌──────────────────────────────────────────────────────────────┐  │    │
│  │  │  namespace: cert-manager                                     │  │    │
│  │  │  cert-manager v1.18.2                                        │  │    │
│  │  │  ClusterIssuer: letsencrypt-prod (ACME DNS-01/Cloudflare)    │  │    │
│  │  └──────────────────────────────────────────────────────────────┘  │    │
│  │                                                                     │    │
│  │  ┌──────────────────────────────────────────────────────────────┐  │    │
│  │  │  namespace: argocd   ◄──── GitOps CD Controller              │  │    │
│  │  │  argo-cd Helm chart v7.8.23                                  │  │    │
│  │  │  ┌─────────────────────────────────────────────────────┐    │  │    │
│  │  │  │  argocd-server (ClusterIP, insecure mode)           │    │  │    │
│  │  │  │  argocd-repo-server                                 │    │  │    │
│  │  │  │  argocd-application-controller                      │    │  │    │
│  │  │  │  argocd-dex-server                                  │    │  │    │
│  │  │  │  argocd-redis                                       │    │  │    │
│  │  │  └─────────────────────────────────────────────────────┘    │  │    │
│  │  │  Applications:                                               │  │    │
│  │  │   • kltn-dev  → k8s-manifests/overlays/dev  → ns: dev       │  │    │
│  │  │   • kltn-prod → k8s-manifests/overlays/prod → ns: prod      │  │    │
│  │  └──────────────────────────────────────────────────────────────┘  │    │
│  │                                                                     │    │
│  │  ┌─────────────────────────┐  ┌──────────────────────────────────┐ │    │
│  │  │  namespace: dev          │  │  namespace: prod                 │ │    │
│  │  │  ┌────────────────────┐ │  │  ┌────────────────────────────┐  │ │    │
│  │  │  │ frontend (Next.js) │ │  │  │ frontend (Next.js)         │  │ │    │
│  │  │  │ users-service      │ │  │  │ users-service              │  │ │    │
│  │  │  │ tours-service      │ │  │  │ tours-service              │  │ │    │
│  │  │  │ bookings-service   │ │  │  │ bookings-service           │  │ │    │
│  │  │  │ reviews-service    │ │  │  │ reviews-service            │  │ │    │
│  │  │  │ blog-service       │ │  │  │ blog-service               │  │ │    │
│  │  │  │ chat-service       │ │  │  │ chat-service               │  │ │    │
│  │  │  │ Secret: kltn-app-  │ │  │  │ Secret: kltn-app-secrets   │  │ │    │
│  │  │  │         secrets    │ │  │  └────────────────────────────┘  │ │    │
│  │  │  └────────────────────┘ │  └──────────────────────────────────┘ │    │
│  │  └─────────────────────────┘                                        │    │
│  │                                                                     │    │
│  │  ┌──────────────────────────────────────────────────────────────┐  │    │
│  │  │  namespace: monitoring                                       │  │    │
│  │  │  kube-prometheus-stack v72.3.0                               │  │    │
│  │  │  ┌─────────────┐ ┌────────────┐ ┌──────────────────────┐   │  │    │
│  │  │  │  Prometheus  │ │  Grafana   │ │  AlertManager        │   │  │    │
│  │  │  │  (15d retain)│ │  (ClusterIP│ │  Node Exporter       │   │  │    │
│  │  │  │              │ │  + Ingress)│ │  kube-state-metrics  │   │  │    │
│  │  │  └─────────────┘ └────────────┘ └──────────────────────┘   │  │    │
│  │  └──────────────────────────────────────────────────────────────┘  │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                             │
│  EKS Add-ons: CoreDNS | kube-proxy | vpc-cni | eks-pod-identity-agent      │
└─────────────────────────────────────────────────────────────────────────────┘
                   │
                   ▼
         ┌────────────────────┐
         │  MongoDB Atlas     │
         │  (External Cloud)  │
         │  Per-service DBs:  │
         │  tour_users        │
         │  tour_tours        │
         │  tour_bookings     │
         │  tour_reviews      │
         │  tour_blog         │
         │  tour_chat         │
         └────────────────────┘
```

---

## 🔄 Luồng CI/CD

```
Developer Push Code
        │
        ▼
┌────────────────┐
│   GitHub       │  ── Webhook trigger ──►  Jenkins Pipeline
│  (app source)  │
└────────────────┘
        
Jenkins Pipeline (EC2 - m7i-flex.large):
  1. Checkout source code
  2. SonarQube   → Static code analysis (SAST)
  3. Snyk        → Dependency vulnerability scan (SCA)
  4. Docker build → Build container image
  5. Trivy       → Container image vulnerability scan
  6. Docker push → Push image to registry (Docker Hub / ECR)
  7. Update image tag → Commit to k8s-manifests repo (overlays/dev or overlays/prod)
        │
        ▼
┌────────────────────────────────────────┐
│  GitHub: minhnhatuit734/k8s-manifests  │
│  ├── base/                             │
│  ├── overlays/                         │
│  │   ├── dev/   (image tag updated)    │
│  │   └── prod/  (image tag updated)    │
└────────────────┬───────────────────────┘
                 │  ArgoCD watches & auto-sync (selfHeal + prune)
                 ▼
┌────────────────────────────────────────┐
│  ArgoCD on EKS                         │
│  Application: kltn-dev                 │
│   source: overlays/dev  → ns: dev      │
│  Application: kltn-prod                │
│   source: overlays/prod → ns: prod     │
└────────────────────────────────────────┘
                 │
                 ▼
         EKS Namespace (dev / prod)
         Pods rolling-update tự động
```

---

## 📁 Cấu trúc thư mục

```
kltn-terraform/
├── argocd/                          # ArgoCD standalone trên EC2 + K3s
│   ├── main.tf                      # VPC, EC2, Security Group, EIP
│   ├── variables.tf                 # Khai báo biến
│   ├── outputs.tf                   # Output sau khi apply
│   ├── terraform.tfvars.example     # Template biến mẫu
│   └── scripts/
│       └── install.sh               # User data: cài K3s + ArgoCD
│
├── terraform_CI/                    # CI Server: Jenkins + SonarQube
│   ├── main.tf                      # VPC, Subnet, SG, EC2 (m7i-flex.large)
│   ├── user_data.sh                 # Cài Jenkins, Docker, Node.js, Java, Snyk, Trivy
│   └── modules/
│       ├── vpc/
│       ├── subnet/
│       ├── security_group/
│       └── EC2/
│
├── terraform-eks-cluster/           # AWS EKS cluster + add-ons
│   ├── main.tf                      # EKS module, VPC, Helm/kubectl providers
│   ├── variables.tf                 # Tất cả biến cấu hình
│   ├── versions.tf                  # Terraform & provider versions
│   ├── output.tf                    # URLs, endpoints output
│   ├── terraform.tfvars.example     # Template biến mẫu
│   │
│   ├── argocd.tf                    # Helm: argo-cd, Ingress, Applications (dev+prod)
│   ├── cert-manager.tf              # Helm: cert-manager + ClusterIssuer
│   ├── cert-manager-cloudflare.tf   # ClusterIssuer với DNS-01 challenge Cloudflare
│   ├── cloudflare-dns.tf            # Cloudflare CNAME records → NLB
│   ├── cloudflare-provider.tf       # Cloudflare provider config
│   ├── ingress-nginx.tf             # Helm: ingress-nginx (AWS NLB)
│   ├── kubernetes-secrets.tf        # Secrets cho namespace dev + prod
│   ├── monitoring.tf                # Helm: kube-prometheus-stack + Grafana Ingress
│   ├── eks-wait.tf                  # time_sleep chờ EKS API ready
│   └── modules/
│       ├── eks-cluster/
│       ├── eks-node-group/
│       ├── iam/
│       └── vpc/
│
├── terraform-ec2-chatbot/           # EC2 cho Chatbot AI (Rasa, MLflow, MinIO)
│   ├── main.tf                      # AWS EC2, Security Group, EIP, User data
│   ├── cloudflare-dns.tf            # Cloudflare DNS records
│   ├── variables.tf                 # Khai báo biến
│   └── outputs.tf                   # Output URLs
│
├── argocd.yml                       # ArgoCD Application manifest (standalone deploy)
├── letsencrypt-account.key          # ACME account key (Let's Encrypt)
├── secret-example.yaml              # Ví dụ cấu trúc Secret
├── get-services.ps1                 # Script kiểm tra services trên cluster
└── README.md
```

---

## 🧩 Thành phần hạ tầng

### 1. CI Server (`terraform_CI/`)

| Thành phần | Chi tiết |
|---|---|
| **Instance** | EC2 `m7i-flex.large` — Ubuntu 22.04 |
| **Region** | `ap-southeast-1` (Singapore) |
| **Jenkins** | Port `8080` — phiên bản `2.541.2` (LTS, pinned) |
| **SonarQube** | Port `9000` — Docker container `sonarqube:lts` |
| **Snyk** | CLI — phân tích dependency (SCA) |
| **Trivy** | CLI — quét lỗ hổng container image |
| **Docker** | Docker Engine + Compose v2.29.1 |
| **Java** | OpenJDK 17 |
| **Node.js** | v20 LTS |

### 2. ArgoCD Standalone (`argocd/`)

| Thành phần | Chi tiết |
|---|---|
| **Instance** | EC2 Ubuntu 22.04 |
| **K3s** | Kubernetes nhẹ — tự cài qua `user_data` |
| **ArgoCD** | Cài trên K3s qua Helm |
| **Mục đích** | ArgoCD server độc lập (không dùng EKS) |
| **Networking** | VPC riêng, EIP cố định, NodePort 30080/30443 |

### 3. EKS Cluster (`terraform-eks-cluster/`)

| Thành phần | Helm Chart | Version |
|---|---|---|
| **EKS** | `terraform-aws-modules/eks/aws` | `~> 21.0` |
| **NGINX Ingress** | `ingress-nginx/ingress-nginx` | `4.15.1` |
| **Cert-Manager** | `jetstack/cert-manager` | `v1.18.2` |
| **ArgoCD** | `argoproj/argo-cd` | `7.8.23` |
| **Prometheus Stack** | `prometheus-community/kube-prometheus-stack` | `72.3.0` |

#### Node Group
| Tham số | Giá trị |
|---|---|
| Instance type | `m7i-flex.large` |
| Capacity | `ON_DEMAND` |
| Min / Desired / Max | `2 / 2 / 3` |
| AMI | `AL2023_x86_64_STANDARD` |

#### EKS Add-ons
- `CoreDNS`
- `kube-proxy`
- `vpc-cni` (before compute)
- `eks-pod-identity-agent` (before compute)

### 4. Chatbot Server (`terraform-ec2-chatbot/`)

| Thành phần | Chi tiết |
|---|---|
| **Instance** | EC2 Ubuntu 24.04 |
| **Software** | Docker, Rasa, MLflow, MinIO |
| **Mục đích** | Triển khai AI Chatbot, theo dõi mô hình với MLflow và object storage với MinIO |
| **Networking** | Elastic IP cố định, Cloudflare DNS (`chatbot`, `mlflow`) |

---

## 📦 ArgoCD Applications

ArgoCD tự động sync từ repo **`minhnhatuit734/k8s-manifests`**:

```yaml
# kltn-dev
source:
  repoURL: https://github.com/minhnhatuit734/k8s-manifests.git
  targetRevision: main
  path: overlays/dev
destination:
  namespace: dev
syncPolicy:
  automated:
    prune: true      # xóa resource thừa
    selfHeal: true   # tự phục hồi nếu bị sửa tay

# kltn-prod
source:
  path: overlays/prod
destination:
  namespace: prod
```

---

## ⚙️ Yêu cầu

### Công cụ cần cài

```bash
# Terraform >= 1.5.7
terraform --version

# AWS CLI v2 (đã config credentials)
aws --version
aws configure

# kubectl
kubectl version --client

# Helm >= 3.x
helm version
```

### Tài khoản cần có

- **AWS** — IAM user/role với quyền `AdministratorAccess` (hoặc đủ quyền cho EKS, VPC, EC2, IAM)
- **Cloudflare** — API Token với quyền: `Zone:Read` + `DNS:Edit` cho zone `uittravel.shop`
- **MongoDB Atlas** — Connection string cho 6 databases
- **GitHub** — Repository `k8s-manifests` làm GitOps source

---

## 🚀 Hướng dẫn triển khai

### Bước 1: Tạo CI Server

```bash
cd terraform_CI

terraform init
terraform plan
terraform apply
```

Sau khi apply, Jenkins UI tại `http://<EC2_IP>:8080`.

---

### Bước 2: Tạo ArgoCD Standalone (tuỳ chọn)

```bash
cd argocd

cp terraform.tfvars.example terraform.tfvars
# Sửa biến: aws_region, key_name, public_key_path, ...

terraform init
terraform plan
terraform apply
```

ArgoCD UI tại `http://<EIP>:30080`.

---

### Bước 3: Tạo EKS Cluster + Toàn bộ Add-ons

```bash
cd terraform-eks-cluster

# Tạo file biến từ template
cp terraform.tfvars.example terraform.tfvars
```

Chỉnh sửa `terraform.tfvars`:

```hcl
aws_region   = "ap-southeast-1"
cluster_name = "kltn-eks-dev"

cloudflare_api_token = "<your-token>"
cloudflare_zone_id   = "<your-zone-id>"
letsencrypt_email    = "your@email.com"

jwt_secret       = "<secret>"
mongo_atlas_uri  = "mongodb+srv://..."
together_api_key = "<key>"

mongo_url_users    = "mongodb+srv://..."
mongo_url_tours    = "mongodb+srv://..."
mongo_url_bookings = "mongodb+srv://..."
mongo_url_reviews  = "mongodb+srv://..."
mongo_url_blog     = "mongodb+srv://..."
mongo_url_chat     = "mongodb+srv://..."

grafana_admin_password = "Admin@KLTN2024!"
```

```bash
terraform init
terraform plan -out=plan.out
terraform apply plan.out
```

> ⚠️ **Lưu ý:** Quá trình apply mất khoảng **20–30 phút** do cần khởi tạo EKS cluster, chờ NLB provision và DNS propagate.

---

### Bước 4: Tạo Chatbot Server (Tuỳ chọn)

```bash
cd terraform-ec2-chatbot

cp terraform.tfvars.example terraform.tfvars
# Chỉnh sửa biến trong terraform.tfvars nếu cần

terraform init
terraform plan
terraform apply
```

---

### Bước 5: Cấu hình kubectl

```bash
aws eks update-kubeconfig \
  --region ap-southeast-1 \
  --name kltn-eks-dev
```

---

### Bước 6: Lấy mật khẩu ArgoCD

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d
```

---

## 🔑 Biến môi trường

| Biến | Bắt buộc | Mô tả |
|---|---|---|
| `aws_region` | ✅ | AWS Region (default: `ap-southeast-1`) |
| `cluster_name` | ✅ | Tên EKS cluster |
| `cloudflare_api_token` | ✅ | Token Cloudflare (Zone Read + DNS Edit) |
| `cloudflare_zone_id` | ✅ | Zone ID của `uittravel.shop` |
| `letsencrypt_email` | ✅ | Email đăng ký Let's Encrypt |
| `jwt_secret` | ✅ | JWT secret cho backend |
| `mongo_atlas_uri` | ✅ | MongoDB Atlas URI |
| `together_api_key` | ✅ | Together AI API Key |
| `mongo_url_users` | ✅ | MongoDB URI cho users service |
| `mongo_url_tours` | ✅ | MongoDB URI cho tours service |
| `mongo_url_bookings` | ✅ | MongoDB URI cho bookings service |
| `mongo_url_reviews` | ✅ | MongoDB URI cho reviews service |
| `mongo_url_blog` | ✅ | MongoDB URI cho blog service |
| `mongo_url_chat` | ✅ | MongoDB URI cho chat service |
| `grafana_admin_password` | ✅ | Mật khẩu admin Grafana |
| `node_instance_types` | ❌ | Loại EC2 node (default: `m7i-flex.large`) |
| `node_desired_size` | ❌ | Số node mong muốn (default: `2`) |
| `prometheus_retention` | ❌ | Thời gian lưu metric (default: `15d`) |

---

## 🌐 Endpoints & URLs

Sau khi triển khai thành công:

| Dịch vụ | URL |
|---|---|
| **Frontend (Dev)** | `https://dev.uittravel.shop` |
| **API Gateway (Dev)** | `https://api-dev.uittravel.shop` |
| **Frontend (Prod)** | `https://prod.uittravel.shop` |
| **API Gateway (Prod)** | `https://api-prod.uittravel.shop` |
| **ArgoCD UI** | `https://argocd.uittravel.shop` |
| **Grafana** | `https://grafana.uittravel.shop` |
| **Chatbot API** | `https://chatbot.uittravel.shop` |
| **MLflow** | `https://mlflow.uittravel.shop` |
| **Jenkins** | `http://<CI_EC2_IP>:8080` |
| **SonarQube** | `http://<CI_EC2_IP>:9000` |
| **Prometheus** | `kubectl port-forward svc/kube-prometheus-stack-prometheus -n monitoring 9090:9090` |

---

## 📊 Monitoring

Hệ thống giám sát sử dụng **kube-prometheus-stack**:

| Thành phần | Mô tả |
|---|---|
| **Prometheus** | Thu thập metrics từ toàn bộ cluster, lưu `15d` |
| **Grafana** | Dashboard trực quan, timezone `Asia/Ho_Chi_Minh` |
| **AlertManager** | Quản lý cảnh báo |
| **Node Exporter** | Metrics hệ thống mỗi node |
| **kube-state-metrics** | Metrics về trạng thái Kubernetes objects |

Truy cập Grafana:
- URL: `https://grafana.uittravel.shop`
- Username: `admin`
- Password: xem `grafana_admin_password` trong `terraform.tfvars`

---

## 🗑️ Xóa hạ tầng

> ⚠️ **Cảnh báo:** Lệnh dưới đây sẽ xóa toàn bộ hạ tầng, bao gồm EKS cluster và dữ liệu.

```bash
# Xóa EKS cluster (chạy script destroy để dọn dẹp NLB trước)
cd terraform-eks-cluster
powershell -File destroy.ps1

# Xóa Chatbot
cd ../terraform-ec2-chatbot
terraform destroy

# Xóa CI server
cd ../terraform_CI
terraform destroy

# Xóa ArgoCD standalone
cd ../argocd
terraform destroy
```

---

## 🔒 Bảo mật

- **Secrets** được lưu dưới dạng Kubernetes Secret (không commit vào Git)
- **TLS** tự động cấp bởi Let's Encrypt qua cert-manager (DNS-01 challenge với Cloudflare)
- **SAST** bằng SonarQube trong CI pipeline
- **SCA** bằng Snyk phân tích dependency
- **Container Scanning** bằng Trivy
- **`terraform.tfvars`** được thêm vào `.gitignore`

---

## 👤 Tác giả

**Minh Nhật** — `minhnhatuit734`  
Trường Đại học Công nghệ Thông tin — UIT  
Khóa Luận Tốt Nghiệp

---

## 📄 License

MIT License — Chỉ dùng cho mục đích học thuật.
