#!/bin/bash
set -e

LOG_FILE="/var/log/kltn-argocd-install.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=========================================="
echo "  KLTN - Install K3s + ArgoCD"
echo "=========================================="

echo "[0/6] Update system packages..."
apt-get update -y
apt-get install -y curl wget git unzip ca-certificates jq

# ─────────────────────────────────────────
# 1. Install K3s
# ─────────────────────────────────────────
echo "[1/6] Installing K3s..."

curl -sfL https://get.k3s.io | sh -s - server \
  --write-kubeconfig-mode=644 \
  --disable=traefik

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "Waiting for K3s service..."
systemctl enable k3s
systemctl restart k3s

sleep 20

echo "Waiting for K3s node to become Ready..."
until kubectl get nodes 2>/dev/null | grep -q " Ready "; do
  echo "  Node is not Ready yet. Waiting..."
  sleep 5
done

echo "K3s is ready."
kubectl get nodes -o wide

# ─────────────────────────────────────────
# 2. Prepare kubeconfig for ubuntu user
# ─────────────────────────────────────────
echo "[2/6] Preparing kubeconfig for ubuntu user..."

mkdir -p /home/ubuntu/.kube
cp /etc/rancher/k3s/k3s.yaml /home/ubuntu/.kube/config

PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 || true)

if [ -n "$PUBLIC_IP" ]; then
  sed -i "s/127.0.0.1/$PUBLIC_IP/g" /home/ubuntu/.kube/config
fi

chown -R ubuntu:ubuntu /home/ubuntu/.kube
chmod 600 /home/ubuntu/.kube/config

# ─────────────────────────────────────────
# 3. Fix CoreDNS forwarder
# ─────────────────────────────────────────
echo "[3/6] Fixing CoreDNS forwarder..."

echo "Waiting for CoreDNS ConfigMap to be created..."
for i in {1..60}; do
  if kubectl -n kube-system get configmap coredns >/dev/null 2>&1; then
    echo "CoreDNS ConfigMap found."
    break
  fi

  echo "  CoreDNS ConfigMap not found yet. Waiting... ($i/60)"
  sleep 5
done

if kubectl -n kube-system get configmap coredns >/dev/null 2>&1; then
  kubectl -n kube-system get configmap coredns -o yaml > /tmp/coredns.yaml

  if grep -q "forward . /etc/resolv.conf" /tmp/coredns.yaml; then
    sed -i 's|forward . /etc/resolv.conf|forward . 8.8.8.8 1.1.1.1|g' /tmp/coredns.yaml
    kubectl apply -f /tmp/coredns.yaml
  else
    echo "CoreDNS forwarder is already customized or different from expected."
  fi

  kubectl -n kube-system rollout restart deployment coredns || true
  kubectl -n kube-system rollout status deployment coredns --timeout=180s || true
else
  echo "WARNING: CoreDNS ConfigMap was not found after waiting. Skipping CoreDNS patch."
fi

# ─────────────────────────────────────────
# 4. Install ArgoCD
# ─────────────────────────────────────────
echo "[4/6] Installing ArgoCD..."

kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -n argocd --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "Waiting for ArgoCD deployments..."

kubectl -n argocd rollout status deployment/argocd-redis --timeout=300s || true
kubectl -n argocd rollout status deployment/argocd-repo-server --timeout=300s || true
kubectl -n argocd rollout status deployment/argocd-server --timeout=300s || true
kubectl -n argocd rollout status deployment/argocd-applicationset-controller --timeout=300s || true
kubectl -n argocd rollout status deployment/argocd-dex-server --timeout=300s || true

kubectl -n argocd get pods -o wide

# ─────────────────────────────────────────
# 5. Expose ArgoCD through NodePort
# ─────────────────────────────────────────
echo "[5/6] Exposing ArgoCD UI through NodePort..."

kubectl -n argocd patch svc argocd-server \
  -p '{
    "spec": {
      "type": "NodePort",
      "ports": [
        {
          "name": "http",
          "port": 80,
          "protocol": "TCP",
          "targetPort": 8080,
          "nodePort": 30080
        },
        {
          "name": "https",
          "port": 443,
          "protocol": "TCP",
          "targetPort": 8080,
          "nodePort": 30443
        }
      ]
    }
  }'

kubectl -n argocd get svc argocd-server

# ─────────────────────────────────────────
# 6. Install ArgoCD CLI and save access info
# ─────────────────────────────────────────
echo "[6/6] Installing ArgoCD CLI and saving access information..."

ARGOCD_VERSION=$(curl -sL https://api.github.com/repos/argoproj/argo-cd/releases/latest | jq -r '.tag_name')

if [ -n "$ARGOCD_VERSION" ] && [ "$ARGOCD_VERSION" != "null" ]; then
  curl -sSL -o /usr/local/bin/argocd \
    "https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_VERSION}/argocd-linux-amd64"
  chmod +x /usr/local/bin/argocd
  argocd version --client || true
else
  echo "Could not detect latest ArgoCD CLI version. Skipping CLI installation."
fi

echo "Saving ArgoCD initial admin password..."

for i in {1..30}; do
  if kubectl -n argocd get secret argocd-initial-admin-secret >/dev/null 2>&1; then
    kubectl -n argocd get secret argocd-initial-admin-secret \
      -o jsonpath="{.data.password}" | base64 -d > /home/ubuntu/argocd-admin-password.txt
    echo "" >> /home/ubuntu/argocd-admin-password.txt
    break
  fi

  echo "  Waiting for argocd-initial-admin-secret..."
  sleep 10
done

if [ ! -f /home/ubuntu/argocd-admin-password.txt ]; then
  echo "WARNING: Could not save ArgoCD initial admin password automatically." > /home/ubuntu/argocd-admin-password.txt
fi

chown ubuntu:ubuntu /home/ubuntu/argocd-admin-password.txt
chmod 600 /home/ubuntu/argocd-admin-password.txt

cat > /home/ubuntu/argocd-info.txt <<INFO
=== KLTN ArgoCD Server ===

Public IP detected during EC2 boot:
$PUBLIC_IP

ArgoCD UI HTTP:
http://$PUBLIC_IP:30080

ArgoCD UI HTTPS:
https://$PUBLIC_IP:30443

K3s API:
https://$PUBLIC_IP:6443

SSH:
ssh -i ~/.ssh/kltn-argocd ubuntu@$PUBLIC_IP

Get ArgoCD admin password:
sudo cat /home/ubuntu/argocd-admin-password.txt

Check K3s:
sudo kubectl get nodes
sudo kubectl get pods -A

Check ArgoCD:
sudo kubectl -n argocd get pods
sudo kubectl -n argocd get svc

Installation log:
sudo cat /var/log/kltn-argocd-install.log
INFO

chown ubuntu:ubuntu /home/ubuntu/argocd-info.txt

echo "=========================================="
echo "  Installation completed!"
echo "=========================================="
echo "ArgoCD UI HTTP: http://$PUBLIC_IP:30080"
echo "ArgoCD UI HTTPS: https://$PUBLIC_IP:30443"
echo "Username: admin"
echo "Password file: /home/ubuntu/argocd-admin-password.txt"
echo "Info file: /home/ubuntu/argocd-info.txt"
echo "Log file: $LOG_FILE"