# KLTN Terraform Infrastructure

Repo này chứa mã Terraform dùng để triển khai hạ tầng AWS cho hệ thống khóa luận tốt nghiệp.

Hạ tầng chính được triển khai trên AWS EKS. Sau đó, ứng dụng microservices được deploy bằng ArgoCD theo mô hình GitOps.

## Mục lục

- [Tổng quan hệ thống](#tổng-quan-hệ-thống)
- [Các repository liên quan](#các-repository-liên-quan)
- [Hạ tầng được tạo bởi Terraform](#hạ-tầng-được-tạo-bởi-terraform)
- [Kiến trúc ứng dụng](#kiến-trúc-ứng-dụng)
- [Luồng request](#luồng-request)
- [Cách triển khai hạ tầng](#cách-triển-khai-hạ-tầng)
- [Kết nối kubectl với EKS](#kết-nối-kubectl-với-eks)
- [Kiểm tra ArgoCD](#kiểm-tra-argocd)
- [Kiểm tra ứng dụng sau khi deploy](#kiểm-tra-ứng-dụng-sau-khi-deploy)
- [Kiểm tra API Gateway](#kiểm-tra-api-gateway)
- [Kiểm tra Frontend](#kiểm-tra-frontend)
- [ConfigMap và Secret](#configmap-và-secret)
- [Dừng hệ thống để tránh tốn phí AWS](#dừng-hệ-thống-để-tránh-tốn-phí-aws)
- [Resume sau khi destroy](#resume-sau-khi-destroy)

## Tổng quan hệ thống

Hệ thống KLTN được triển khai theo luồng:

```text
Terraform
-> AWS Infrastructure
-> EKS Cluster
-> ArgoCD
-> k8s-manifests
-> Frontend + Microservices
```

Trong đó:

- `kltn-terraform`: tạo hạ tầng AWS/EKS.
- `k8s-manifests`: chứa Kubernetes manifests.
- `KLTN-dev`: chứa source code frontend và microservices.
- `DockerHub`: chứa Docker image của các service.
- `ArgoCD`: tự động sync manifests vào EKS.

## Các repository liên quan

| Repository | Vai trò |
| --- | --- |
| `kltn-terraform` | Tạo hạ tầng AWS/EKS bằng Terraform |
| `k8s-manifests` | Chứa Kubernetes Deployment, Service, ConfigMap |
| `KLTN-dev` | Source code frontend và backend microservices |
| `Chatbot` | Rasa/Chatbot/MLOps, xử lý ở giai đoạn sau |

## Hạ tầng được tạo bởi Terraform

Repo này dùng Terraform để tạo các thành phần chính:

- VPC
- Subnets
- Internet Gateway
- Route Tables
- Security Groups
- EKS Cluster
- EKS Managed Node Group
- Worker Node EC2

Thông tin cluster hiện tại:

| Thuộc tính | Giá trị |
| --- | --- |
| Cluster name | `kltn-eks-dev` |
| Region | `ap-southeast-1` |
| Namespace ứng dụng | `dev` |
| Namespace ArgoCD | `argocd` |

## Kiến trúc ứng dụng

Hệ thống gồm các service chính:

| Service | Vai trò | Port |
| --- | --- | --- |
| `frontend` | Giao diện người dùng | `3000` |
| `api-gateway` | Cổng giao tiếp chính giữa frontend và backend | `4000` |
| `users-service` | Quản lý người dùng | `3001` |
| `auth-service` | Xác thực, đăng nhập, JWT | `3002` |
| `tours-service` | Quản lý tour du lịch | `3003` |
| `bookings-service` | Quản lý đặt tour | `3004` |
| `reviews-service` | Quản lý đánh giá | `3005` |
| `blog-service` | Quản lý blog/bài viết | `3006` |
| `chat-service` | Service chat | `3007` |

## Luồng request

Luồng truy cập hiện tại:

```text
User Browser
-> Frontend LoadBalancer
-> API Gateway LoadBalancer
-> Internal Microservices
-> MongoDB Atlas / External APIs
```

Các service public:

| Service | Type |
| --- | --- |
| `frontend` | `LoadBalancer` |
| `api-gateway` | `LoadBalancer` |

Các service nội bộ:

- `auth-service`
- `users-service`
- `tours-service`
- `bookings-service`
- `reviews-service`
- `blog-service`
- `chat-service`

Các service nội bộ chỉ dùng `ClusterIP`, không expose trực tiếp ra Internet.

## Cách triển khai hạ tầng

### Bước 1: Cấu hình AWS CLI

```bash
aws configure
```

Kiểm tra tài khoản AWS hiện tại:

```bash
aws sts get-caller-identity
```

### Bước 2: Khởi tạo Terraform

```bash
terraform init
```

### Bước 3: Kiểm tra kế hoạch tạo hạ tầng

```bash
terraform plan
```

### Bước 4: Tạo hạ tầng

```bash
terraform apply
```

Khi Terraform yêu cầu xác nhận, nhập:

```text
yes
```

Sau khi hoàn tất, Terraform sẽ tạo EKS cluster và worker node trên AWS.

## Kết nối kubectl với EKS

Sau khi Terraform tạo cluster thành công, chạy:

```bash
aws eks update-kubeconfig \
  --region ap-southeast-1 \
  --name kltn-eks-dev
```

Kiểm tra context:

```bash
kubectl config current-context
```

Kiểm tra node:

```bash
kubectl get nodes -o wide
```

Kết quả mong muốn:

```text
STATUS = Ready
```

## Kiểm tra ArgoCD

ArgoCD được dùng để deploy ứng dụng từ repo `k8s-manifests`.

Kiểm tra ArgoCD Application:

```bash
kubectl -n argocd get applications
```

Kết quả mong muốn:

```text
NAME       SYNC STATUS   HEALTH STATUS
kltn-dev   Synced        Healthy
```

## Kiểm tra ứng dụng sau khi deploy

Kiểm tra toàn bộ resource trong namespace `dev`:

```bash
kubectl -n dev get all -o wide
```

Kiểm tra pod:

```bash
kubectl -n dev get pods
```

Kết quả mong muốn:

```text
READY   1/1
STATUS  Running
```

Kiểm tra service:

```bash
kubectl -n dev get svc
```

Kết quả mong muốn:

```text
frontend      LoadBalancer
api-gateway   LoadBalancer
```

Các service còn lại là `ClusterIP`.

## Kiểm tra API Gateway

Lấy DNS của API Gateway:

```bash
kubectl -n dev get svc api-gateway
```

Test API:

```bash
curl http://<api-gateway-loadbalancer-dns>/tours
```

Kết quả mong muốn:

```json
[]
```

Hoặc danh sách tour nếu database đã có dữ liệu.

## Kiểm tra Frontend

Lấy DNS của frontend:

```bash
kubectl -n dev get svc frontend
```

Mở trên trình duyệt:

```text
http://<frontend-loadbalancer-dns>
```

Frontend sẽ gọi API thông qua API Gateway.

## ConfigMap và Secret

Ứng dụng dùng ConfigMap để khai báo URL nội bộ giữa API Gateway và các service.

ConfigMap chính:

```text
kltn-app-config
```

Các giá trị cần có:

```env
AUTH_SERVICE_URL=http://auth-service
USERS_SERVICE_URL=http://users-service
TOURS_SERVICE_URL=http://tours-service
BOOKINGS_SERVICE_URL=http://bookings-service
REVIEWS_SERVICE_URL=http://reviews-service
BLOG_SERVICE_URL=http://blog-service
CHAT_SERVICE_URL=http://chat-service
```

Lưu ý:

- Không đặt `PORT` trong ConfigMap dùng chung.
- Vì mỗi service có port riêng. Nếu đặt `PORT=4000` trong ConfigMap dùng chung, toàn bộ backend có thể bị ép chạy sai port.

Secret chính:

```text
kltn-app-secrets
```

Các key cần có:

```env
JWT_SECRET
MONGO_ATLAS_URI
MONGO_URL
TOGETHER_API_KEY
```

Không commit secret thật lên GitHub.

## Dừng hệ thống để tránh tốn phí AWS

Không nên stop EC2 thủ công trên AWS Console vì EKS, LoadBalancer, NAT Gateway hoặc Auto Scaling Group vẫn có thể tiếp tục phát sinh chi phí.

### Cách 1: Nghỉ ngắn

Scale node group về `0`:

```bash
aws eks list-nodegroups \
  --cluster-name kltn-eks-dev \
  --region ap-southeast-1
```

Sau đó:

```bash
aws eks update-nodegroup-config \
  --cluster-name kltn-eks-dev \
  --nodegroup-name <nodegroup-name> \
  --scaling-config minSize=0,maxSize=1,desiredSize=0 \
  --region ap-southeast-1
```

Khi cần bật lại:

```bash
aws eks update-nodegroup-config \
  --cluster-name kltn-eks-dev \
  --nodegroup-name <nodegroup-name> \
  --scaling-config minSize=1,maxSize=1,desiredSize=1 \
  --region ap-southeast-1
```

### Cách 2: Nghỉ dài

Xóa toàn bộ hạ tầng bằng Terraform:

```bash
terraform destroy
```

Đây là cách tiết kiệm chi phí nhất khi không sử dụng AWS trong thời gian dài.

## Resume sau khi destroy

Khi cần dựng lại hệ thống:

```bash
terraform init
terraform apply
```

Kết nối lại EKS:

```bash
aws eks update-kubeconfig \
  --region ap-southeast-1 \
  --name kltn-eks-dev
```

Kiểm tra:

```bash
kubectl get nodes
kubectl -n argocd get applications
kubectl -n dev get pods
kubectl -n dev get svc
```
