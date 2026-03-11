#!/usr/bin/env bash
set -e

# --- Utility: Detect OS ---
detect_os() {
    if command -v apt-get >/dev/null 2>&1; then
        echo "debian"
    elif command -v dnf >/dev/null 2>&1 || command -v yum >/dev/null 2>&1; then
        echo "rhel"
    else
        echo "unknown"
    fi
}

OS_TYPE=$(detect_os)
TARGET_USER=${SUDO_USER:-$USER}

# --- Functions ---
install_docker() {
    echo "Installing Docker for $OS_TYPE..."
    if [[ "$OS_TYPE" == "debian" ]]; then
        apt update && apt install -y ca-certificates curl
        install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
        chmod a+r /etc/apt/keyrings/docker.asc
        . /etc/os-release
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $UBUNTU_CODENAME stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
        apt update && apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    elif [[ "$OS_TYPE" == "rhel" ]]; then
        dnf install -y dnf-plugins-core
        dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    fi
    systemctl enable --now docker
    usermod -aG docker "$TARGET_USER"
    echo "Docker installed successfully."
}

uninstall_docker() {
    echo "Purging Docker..."
    systemctl stop docker.socket docker.service || true
    if [[ "$OS_TYPE" == "debian" ]]; then
        apt purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    else
        dnf remove -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    fi
    rm -rf /var/lib/docker /var/lib/containerd /etc/docker
    echo "Docker uninstalled."
}

# --- Menu Loop ---
while true; do
    echo -e "\n--- Docker Manager (Detected OS: $OS_TYPE) ---"
    echo "1) Install Docker"
    echo "2) Uninstall Docker"
    echo "3) Reinstall Docker"
    echo "4) Check Docker Status"
    echo "5) Exit"
    read -p "Select an option [1-5]: " opt

    case $opt in
        1) install_docker ;;
        2) uninstall_docker ;;
        3) uninstall_docker; install_docker ;;
        4) 
            if command -v docker >/dev/null 2>&1; then
                docker --version && systemctl status docker --no-pager | head -n 5
            else
                echo "Docker is not installed."
            fi
            ;;
        5) exit 0 ;;
        *) echo "Invalid option." ;;
    esac
done
