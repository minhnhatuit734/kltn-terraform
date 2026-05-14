#!/bin/bash
set -e

echo "=========================================="
echo "  KLTN - Cài đặt K3s + ArgoCD"
echo "=========================================="

# Cập nhật hệ thống
apt-get update -y
apt-get install -y curl wget git

# ─────────────────────────────────────────
# 1. Cài K3s
# ─────────────────────────────────────────
echo "[1/4] Cài đặt K3s..."
curl -sfL https://get.k3s.io | sh -s - \
  --write-kubeconfig-mode 644 \
  --disable traefik

# Chờ K3s sẵn sàng
echo "Chờ K3s khởi động..."
sleep 30
until kubectl get nodes 2>/dev/null | grep -q "Ready"; do
  echo "  Đang chờ node Ready..."
  sleep 5
done
echo "K3s đã sẵn sàng!"

# Copy kubeconfig cho user ubuntu
mkdir -p /home/ubuntu/.kube
cp /etc/rancher/k3s/k3s.yaml /home/ubuntu/.kube/config
# Thay localhost bằng public IP để kubectl remote được
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
sed -i "s/127.0.0.1/$PUBLIC_IP/g" /home/ubuntu/.kube/config
chown ubuntu:ubuntu /home/ubuntu/.kube/config
chmod 600 /home/ubuntu/.kube/config

# Export KUBECONFIG cho root
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# ─────────────────────────────────────────
# 2. Fix CoreDNS (tránh loop với systemd-resolved)
# ─────────────────────────────────────────
echo "[2/4] Fix CoreDNS DNS loop..."
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
data:
  Corefile: |
    .:53 {
        errors
        health
        ready
        kubernetes cluster.local in-addr.arpa ip6.arpa {
          pods insecure
          fallthrough in-addr.arpa ip6.arpa
        }
        hosts /etc/coredns/NodeHosts {
          ttl 60
          reload 15s
          fallthrough
        }
        prometheus :9153
        forward . 8.8.8.8 8.8.4.4
        cache 30
        loop
        reload
        loadbalance
    }
EOF
kubectl rollout restart deployment coredns -n kube-system
sleep 15

# ─────────────────────────────────────────
# 3. Cài ArgoCD
# ─────────────────────────────────────────
echo "[3/4] Cài đặt ArgoCD..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Chờ ArgoCD pods sẵn sàng
echo "Chờ ArgoCD pods khởi động (có thể mất 2-3 phút)..."
kubectl wait --for=condition=available deployment/argocd-server \
  -n argocd --timeout=300s

# ─────────────────────────────────────────
# 4. Expose ArgoCD qua NodePort
# ─────────────────────────────────────────
echo "[4/4] Expose ArgoCD UI qua NodePort..."
kubectl patch svc argocd-server -n argocd \
  -p '{"spec": {"type": "NodePort", "ports": [{"port": 80, "targetPort": 8080, "nodePort": 30080, "name": "http"}, {"port": 443, "targetPort": 8080, "nodePort": 30443, "name": "https"}]}}'

# ─────────────────────────────────────────
# 5. Cài ArgoCD CLI
# ─────────────────────────────────────────
echo "Cài đặt ArgoCD CLI..."
ARGOCD_VERSION=$(curl -sL https://api.github.com/repos/argoproj/argo-cd/releases/latest | grep tag_name | cut -d'"' -f4)
curl -sSL -o /usr/local/bin/argocd \
  https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_VERSION}/argocd-linux-amd64
chmod +x /usr/local/bin/argocd

# ─────────────────────────────────────────
# Lưu thông tin sau khi cài xong
# ─────────────────────────────────────────
echo "=========================================="
echo "  Cài đặt hoàn tất!"
echo "=========================================="
echo ""
echo "Public IP: $PUBLIC_IP"
echo "ArgoCD UI: http://$PUBLIC_IP:30080"
echo ""
echo "Lấy mật khẩu admin ArgoCD:"
echo "  kubectl -n argocd get secret argocd-initial-admin-secret \\"
echo "    -o jsonpath='{.data.password}' | base64 -d"
echo ""

# Ghi log vào file để dễ kiểm tra sau
cat > /home/ubuntu/argocd-info.txt <<INFO
=== KLTN ArgoCD Server ===
Public IP: $PUBLIC_IP
ArgoCD UI: http://$PUBLIC_IP:30080
ArgoCD gRPC: $PUBLIC_IP:30443
K3s API: https://$PUBLIC_IP:6443

SSH: ssh -i ~/.ssh/id_rsa ubuntu@$PUBLIC_IP

Lấy mật khẩu admin:
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
INFO
chown ubuntu:ubuntu /home/ubuntu/argocd-info.txt

echo "Thông tin đã lưu tại /home/ubuntu/argocd-info.txt"
