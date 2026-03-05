#!/usr/bin/env bash

if command -v docker >/dev/null 2>&1; then
        echo "Docker is already installed ($(docker --version))."
        read -p "Would you like to uninstall it and do a clean install? (y/n): " REINSTALL
else
        echo "Docker is not installed."
        REINSTALL="n"
fi

if [[ "REINSTALL" =~ ^[Yy]$ ]]; then
        echo "Purging existing docker installation..."
        sudo systemctl stop docker.socket || true
        sudo systemctl stop docker || true
        sudo apt purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        sudo rm -rf /var/lib/docker
        sudo rm -rf /var/lib/containerd
        sudo rm -rf /etc/docker
        sudo rm -f /etcapt/sources.list.d/docker.list
        sudo rm -f /etc/apt/keyrings/docker.gpg
        echo "Cleanup done."
fi

if ! command -v docker >/dev/null 2>&1; then
        echo "Starting Installation of docker..."
        sudo apt update
        sudo apt install ca-certificates curl
        sudo install -m 0755 -d /etc/apt/keyrings
        sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
        sudo chmod a+r /etc/apt/keyrings/docker.asc

        sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc 
EOF
        sudo apt update 
        sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

fi

echo "Post installation configuration...."
sudo groupadd docker 2>/dev/null || true
if ! groups $USER | grep -q "\bdocker\b"; then
        echo "Addmin $USER to docker group..."
        sudo usermod -aG docker $USER
fi

echo "---------------------------------------------------------------------"
echo "DONE! To run Docker without sudo please restart or exit and reenter: "
echo "Command: exec su - l $USER"
echo "---------------------------------------------------------------------"
