#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
set -e

# Ensure script is run with sudo/root
if [ "$EUID" -ne 0 ]; then 
  echo "Please run as root (sudo $0)"
  exit 1
fi

REINSTALL="n"

if command -v docker >/dev/null 2>&1; then
    echo "Docker is already installed ($(docker --version))."
    read -p "Would you like to uninstall it and do a clean install? (y/n): " choice
    if [[ "$choice" =~ ^[Yy]$ ]]; then
        REINSTALL="y"
    fi
fi

if [[ "$REINSTALL" == "y" ]]; then
    echo "Purging existing docker installation..."
    # Stop services
    systemctl stop docker.socket docker.service || true
    
    # Remove packages
    apt purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras
    
    # Remove data directories
    rm -rf /var/lib/docker /var/lib/containerd /etc/docker
    rm -f /etc/apt/sources.list.d/docker.list /etc/apt/sources.list.d/docker.sources
    rm -f /etc/apt/keyrings/docker.asc
    echo "Cleanup done."
fi

# Installation Logic
if ! command -v docker >/dev/null 2>&1; then
    echo "Starting Installation of docker..."
    apt update
    apt install -y ca-certificates curl
    install -m 0755 -d /etc/apt/keyrings
    
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc

    echo "Adding Docker repository..."
    . /etc/os-release
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $VERSION_CODENAME stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    apt update 
    apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

# Post-installation
echo "Post-installation configuration...."
groupadd docker 2>/dev/null || true

# Get the original user (in case script was run with sudo)
TARGET_USER=${SUDO_USER:-$USER}
usermod -aG docker "$TARGET_USER"

echo "---------------------------------------------------------------------"
echo "DONE! Docker is installed."
echo "To apply group changes, logout and log back in, or run:"
echo "newgrp docker"
echo "---------------------------------------------------------------------"
