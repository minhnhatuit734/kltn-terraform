# KLTN Terraform Infrastructure

Repo này chứa mã Terraform dùng để triển khai hạ tầng AWS cho hệ thống khóa luận tốt nghiệp.

Hạ tầng chính được triển khai trên AWS EKS, sau đó ứng dụng microservices được deploy bằng ArgoCD theo mô hình GitOps.

---

## 
1. Tổng quan hệ thống

Hệ thống KLTN được triển khai theo luồng:

```text
Terraform
→ AWS Infrastructure
→ EKS Cluster
→ ArgoCD
→ k8s-manifests
→ Frontend + Microservices

Trong đó:

kltn-terraform: tạo hạ tầng AWS/EKS.
k8s-manifests: chứa Kubernetes manifests.
KLTN-dev: chứa source code frontend và microservices.
DockerHub: chứa Docker image của các service.
ArgoCD: tự động sync manifests vào EKS.
2. Các repository liên quan
Repository	Vai trò
kltn-terraform	Tạo hạ tầng AWS/EKS bằng Terraform
k8s-manifests	Chứa Kubernetes Deployment, Service, ConfigMap
KLTN-dev	Source code frontend và backend microservices
Chatbot	Rasa/Chatbot/MLOps, xử lý ở giai đoạn sau
3. Hạ tầng được tạo bởi Terraform

Repo này dùng Terraform để tạo các thành phần chính:

VPC
Subnets
Internet Gateway
Route Tables
Security Groups
EKS Cluster
EKS Managed Node Group
Worker Node EC2

Thông tin cluster hiện tại:

Cluster name: kltn-eks-dev
Region: ap-southeast-1
Namespace ứng dụng: dev
Namespace ArgoCD: argocd
4. Kiến trúc ứng dụng

Hệ thống gồm các service chính:

Service	Vai trò	Port
frontend	Giao diện người dùng	3000
api-gateway	Cổng giao tiếp chính giữa frontend và backend	4000
users-service	Quản lý người dùng	3001
auth-service	Xác thực, đăng nhập, JWT	3002
tours-service	Quản lý tour du lịch	3003
bookings-service	Quản lý đặt tour	3004
reviews-service	Quản lý đánh giá	3005
blog-service	Quản lý blog/bài viết	3006
chat-service	Service chat	3007
5. Luồng request

Luồng truy cập hiện tại:

User Browser
→ Frontend LoadBalancer
→ API Gateway LoadBalancer
→ Internal Microservices
→ MongoDB Atlas / External APIs

Các service public:

frontend      → LoadBalancer
api-gateway   → LoadBalancer

Các service nội bộ:

auth-service
users-service
tours-service
bookings-service
reviews-service
blog-service
chat-service

Các service nội bộ chỉ dùng ClusterIP, không expose trực tiếp ra Internet.

6. Cách triển khai hạ tầng
Bước 1: Cấu hình AWS CLI
aws configure

Kiểm tra tài khoản AWS hiện tại:

aws sts get-caller-identity
Bước 2: Khởi tạo Terraform
terraform init
Bước 3: Kiểm tra kế hoạch tạo hạ tầng
terraform plan
Bước 4: Tạo hạ tầng
terraform apply

Nhập:

yes

Sau khi hoàn tất, Terraform sẽ tạo EKS cluster và worker node trên AWS.

7. Kết nối kubectl với EKS

Sau khi Terraform tạo cluster thành công, chạy:

aws eks update-kubeconfig \
  --region ap-southeast-1 \
  --name kltn-eks-dev

Kiểm tra context:

kubectl config current-context

Kiểm tra node:

kubectl get nodes -o wide

Kết quả mong muốn:

STATUS = Ready
8. Kiểm tra ArgoCD

ArgoCD được dùng để deploy ứng dụng từ repo k8s-manifests.

Kiểm tra ArgoCD Application:

kubectl -n argocd get applications

Kết quả mong muốn:

NAME       SYNC STATUS   HEALTH STATUS
kltn-dev   Synced        Healthy
9. Kiểm tra ứng dụng sau khi deploy

Kiểm tra toàn bộ resource trong namespace dev:

kubectl -n dev get all -o wide

Kiểm tra pod:

kubectl -n dev get pods

Kết quả mong muốn:

READY   1/1
STATUS  Running

Kiểm tra service:

kubectl -n dev get svc

Kết quả mong muốn:

frontend      LoadBalancer
api-gateway   LoadBalancer

Các service còn lại là ClusterIP.

10. Kiểm tra API Gateway

Lấy DNS của API Gateway:

kubectl -n dev get svc api-gateway

Test API:

curl http://<api-gateway-loadbalancer-dns>/tours

Kết quả mong muốn:

[]

Hoặc danh sách tour nếu database đã có dữ liệu.

11. Kiểm tra Frontend

Lấy DNS của frontend:

kubectl -n dev get svc frontend

Mở trên trình duyệt:

http://<frontend-loadbalancer-dns>

Frontend sẽ gọi API thông qua API Gateway.

12. ConfigMap và Secret

Ứng dụng dùng ConfigMap để khai báo URL nội bộ giữa API Gateway và các service.

ConfigMap chính:

kltn-app-config

Các giá trị cần có:

AUTH_SERVICE_URL=http://auth-service
USERS_SERVICE_URL=http://users-service
TOURS_SERVICE_URL=http://tours-service
BOOKINGS_SERVICE_URL=http://bookings-service
REVIEWS_SERVICE_URL=http://reviews-service
BLOG_SERVICE_URL=http://blog-service
CHAT_SERVICE_URL=http://chat-service

Lưu ý:

Không đặt PORT trong ConfigMap dùng chung.

Vì mỗi service có port riêng. Nếu đặt PORT=4000 trong ConfigMap dùng chung, toàn bộ backend có thể bị ép chạy sai port.

Secret chính:

kltn-app-secrets

Các key cần có:

JWT_SECRET
MONGO_ATLAS_URI
MONGO_URL
TOGETHER_API_KEY

Không commit secret thật lên GitHub.

13. Dừng hệ thống để tránh tốn phí AWS

Không nên stop EC2 thủ công trên AWS Console vì EKS, LoadBalancer, NAT Gateway hoặc Auto Scaling Group vẫn có thể tiếp tục phát sinh chi phí.

Cách 1: Nghỉ ngắn

Scale node group về 0:

aws eks list-nodegroups \
  --cluster-name kltn-eks-dev \
  --region ap-southeast-1

Sau đó:

aws eks update-nodegroup-config \
  --cluster-name kltn-eks-dev \
  --nodegroup-name <nodegroup-name> \
  --scaling-config minSize=0,maxSize=1,desiredSize=0 \
  --region ap-southeast-1

Khi cần bật lại:

aws eks update-nodegroup-config \
  --cluster-name kltn-eks-dev \
  --nodegroup-name <nodegroup-name> \
  --scaling-config minSize=1,maxSize=1,desiredSize=1 \
  --region ap-southeast-1
Cách 2: Nghỉ dài

Xóa toàn bộ hạ tầng bằng Terraform:

terraform destroy

Đây là cách tiết kiệm chi phí nhất khi không sử dụng AWS trong thời gian dài.

14. Resume sau khi destroy

Khi cần dựng lại hệ thống:

terraform init
terraform apply

Kết nối lại EKS:

aws eks update-kubeconfig \
  --region ap-southeast-1 \
  --name kltn-eks-dev

Kiểm tra:

kubectl get nodes
kubectl -n argocd get applications
kubectl -n dev get pods
kubectl -n dev get svc