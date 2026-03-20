#!/bin/bash
set -euo pipefail

# ============================================================
# EC2 Setup Script for sish tunnel server
# Run this on a fresh Amazon Linux 2023 / Ubuntu 22.04 EC2
# ============================================================

echo "=== [1/5] Updating system ==="
if command -v dnf &>/dev/null; then
    sudo dnf update -y
elif command -v apt-get &>/dev/null; then
    sudo apt-get update -y && sudo apt-get upgrade -y
fi

echo "=== [2/5] Installing Docker ==="
if ! command -v docker &>/dev/null; then
    if command -v dnf &>/dev/null; then
        # Amazon Linux 2023
        sudo dnf install -y docker
        sudo systemctl enable docker
        sudo systemctl start docker
    else
        # Ubuntu
        curl -fsSL https://get.docker.com | sudo sh
        sudo systemctl enable docker
        sudo systemctl start docker
    fi
    sudo usermod -aG docker "$USER"
    echo "Docker installed. You may need to re-login for group changes."
else
    echo "Docker already installed."
fi

echo "=== [3/5] Installing Docker Compose ==="
if ! command -v docker-compose &>/dev/null && ! docker compose version &>/dev/null 2>&1; then
    COMPOSE_VERSION="v2.27.0"
    sudo curl -fsSL "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
        -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    echo "Docker Compose installed."
else
    echo "Docker Compose already installed."
fi

echo "=== [4/5] Configuring firewall ==="
# Open required ports: SSH(22), HTTP(80), HTTPS(443), sish SSH(2222)
if command -v ufw &>/dev/null; then
    sudo ufw allow 22/tcp
    sudo ufw allow 80/tcp
    sudo ufw allow 443/tcp
    sudo ufw allow 2222/tcp
    sudo ufw --force enable
    echo "UFW configured."
elif command -v firewall-cmd &>/dev/null; then
    sudo firewall-cmd --permanent --add-port=22/tcp
    sudo firewall-cmd --permanent --add-port=80/tcp
    sudo firewall-cmd --permanent --add-port=443/tcp
    sudo firewall-cmd --permanent --add-port=2222/tcp
    sudo firewall-cmd --reload
    echo "firewalld configured."
else
    echo "No firewall manager found. Make sure AWS Security Group allows ports: 22, 80, 443, 2222"
fi

echo "=== [5/5] Setting up project ==="
APP_DIR="/opt/aws-sish"
if [ ! -d "$APP_DIR" ]; then
    sudo mkdir -p "$APP_DIR"
    sudo chown "$USER:$USER" "$APP_DIR"
fi

echo ""
echo "============================================================"
echo "  EC2 setup complete!"
echo ""
echo "  Next steps:"
echo "  1. Copy project files to $APP_DIR"
echo "     scp -r ./* ec2-user@<EC2_IP>:$APP_DIR/"
echo ""
echo "  2. Configure .env file"
echo "     cp .env.example .env && vim .env"
echo ""
echo "  3. Set up Route 53 wildcard DNS"
echo "     ./scripts/setup-dns.sh"
echo ""
echo "  4. Start the tunnel server"
echo "     docker compose up -d"
echo ""
echo "  AWS Security Group required inbound rules:"
echo "    - TCP 22   (SSH admin)"
echo "    - TCP 80   (HTTP tunnel)"
echo "    - TCP 443  (HTTPS tunnel)"
echo "    - TCP 2222 (SSH tunnel connections)"
echo "============================================================"
