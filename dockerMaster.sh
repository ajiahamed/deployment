#!/usr/bin/env bash
set -e

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (sudo $0)"
    exit 1
fi

# 1. Detect Package Manager
if command -v apt-get >/dev/null 2>&1; then
    PKG_MANAGER="apt"
elif command -v dnf >/dev/null 2>&1; then
    PKG_MANAGER="dnf"
elif command -v yum >/dev/null 2>&1; then
    PKG_MANAGER="yum"
else
    echo "Unsupported package manager. Please install Docker manually."
    exit 1
fi

echo "Detected package manager: $PKG_MANAGER"

# 2. Cleanup Function
cleanup_docker() {
    echo "Purging existing docker installation..."
    systemctl stop docker.socket docker.service || true
    
    if [[ "$PKG_MANAGER" == "apt" ]]; then
        apt purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        rm -rf /var/lib/docker /var/lib/containerd /etc/docker
        rm -f /etc/apt/sources.list.d/docker.list /etc/apt/keyrings/docker.asc
    else
        # dnf/yum
        dnf remove -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        rm -rf /var/lib/docker /var/lib/containerd /etc/docker
        rm -f /etc/yum.repos.d/docker-ce.repo
    fi
    echo "Cleanup complete."
}

# 3. Check for existing installation
if command -v docker >/dev/null 2>&1; then
    read -p "Docker is already installed. Reinstall? (y/n): " choice
    [[ "$choice" =~ ^[Yy]$ ]] && cleanup_docker
fi

# 4. Install Docker
if ! command -v docker >/dev/null 2>&1; then
    echo "Installing Docker..."
    if [[ "$PKG_MANAGER" == "apt" ]]; then
        apt update && apt install -y ca-certificates curl
        install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
        chmod a+r /etc/apt/keyrings/docker.asc
        . /etc/os-release
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $UBUNTU_CODENAME stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
        apt update && apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    else
        dnf install -y dnf-plugins-core
        dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    fi
fi

# 5. Post-Install
systemctl enable --now docker
groupadd docker 2>/dev/null || true
usermod -aG docker "${SUDO_USER:-$USER}"

echo "---------------------------------------------------------------------"
echo "Installation complete. Please run 'newgrp docker' to refresh groups."
echo "---------------------------------------------------------------------"
