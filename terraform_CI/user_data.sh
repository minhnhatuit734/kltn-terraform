#!/bin/bash
set -eux

# Đổi về user ubuntu nếu chạy với cloud-init (nên dùng với Ubuntu 22.04 trở lên)
USER_HOME="/home/ubuntu"
export DEBIAN_FRONTEND=noninteractive

# 1. Cập nhật hệ thống & cài gói cơ bản
apt-get update -y
apt-get upgrade -y
apt-get install -y \
  apt-transport-https \
  ca-certificates \
  curl \
  wget \
  software-properties-common \
  lsb-release \
  unzip \
  git \
  gnupg2 \
  net-tools

# 2. Cài Docker & Docker Compose
curl -fsSL https://get.docker.com | bash
usermod -aG docker ubuntu

# Docker Compose v2 (standalone)
curl -SL https://github.com/docker/compose/releases/download/v2.29.1/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# 3. Cài Node.js 20 LTS
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

# 4. Cài Java 17 (OpenJDK)
apt-get install -y openjdk-17-jdk

# 5. Cài Jenkins (LTS phiên bản 2.541.2)
# Cập nhật GPG key 2026 mới nhất và trỏ về repo debian-stable
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key | tee \
  /usr/share/keyrings/jenkins-keyring.asc > /dev/null
echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian-stable binary/ | tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null

apt-get update
# Cài đặt chính xác phiên bản 2.541.2 và khóa lại (hold) để tránh tự động update
apt-get install -y jenkins=2.541.2
apt-mark hold jenkins

systemctl enable jenkins
systemctl start jenkins

# 6. Cài Snyk (qua npm)
npm install -g snyk

# 7. Cài Trivy (bảo mật container) - Đã cập nhật cách thêm key chuẩn mới
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor | tee /usr/share/keyrings/trivy.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/trivy.list
apt-get update
apt-get install -y trivy

# 8. SonarQube (qua Docker) - Dùng bản LTS Community
docker pull sonarqube:lts

# 9. Mở firewall các port cơ bản (nếu muốn dùng UFW)
ufw allow 22 || true
ufw allow 80 || true
ufw allow 443 || true
ufw allow 8080 || true   # Jenkins
ufw allow 9000 || true   # SonarQube
ufw --force enable || true

# Chạy container SonarQube
docker run -d --name sonarqube -p 9000:9000 sonarqube:lts

# 10. Ghi thông báo đăng nhập (MOTD)
echo "---------------------------
TẤT CẢ CÔNG CỤ ĐÃ CÀI XONG!

- Jenkins: http://<EC2_IP>:8080  | user: admin (lấy mật khẩu ở: sudo cat /var/lib/jenkins/secrets/initialAdminPassword)
- SonarQube: http://<EC2_IP>:9000 (đã chạy qua docker container)
- OWASP ZAP: docker run -it -p 8081:8080 owasp/zap2docker-stable
- Snyk: snyk --version
- Trivy: trivy --version
---------------------------
" > /etc/motd