#!/usr/bin/env bash
set -e

# --- Ensure we are root ---
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (sudo $0)"
    exit 1
fi

# --- Detection ---
detect_os() {
    if command -v apt-get >/dev/null 2>&1; then echo "debian";
    elif command -v dnf >/dev/null 2>&1 || command -v yum >/dev/null 2>&1; then echo "rhel";
    else echo "unknown"; fi
}

OS_TYPE=$(detect_os)

# --- Logic Functions ---
install_docker() {
    echo "--- Installing Docker ($OS_TYPE) ---"
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
    usermod -aG docker "${SUDO_USER:-$USER}"
    echo "Verification: Running hello-world..."
    docker run --rm hello-world
}

uninstall_docker() {
    echo "--- Purging Docker ---"
    systemctl stop docker.socket docker.service || true
    if [[ "$OS_TYPE" == "debian" ]]; then
        apt purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    else
        dnf remove -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    fi
    rm -rf /var/lib/docker /var/lib/containerd /etc/docker
}

# --- Argument/Menu Handling ---
case "$1" in
    --install)   install_docker ;;
    --uninstall) uninstall_docker ;;
    --reinstall) uninstall_docker; install_docker ;;
    --check)     docker --version && systemctl status docker --no-pager | head -n 5 ;;
    *)
        PS3="Select an action: "
        options=("Install Docker" "Uninstall Docker" "Reinstall Docker" "Check Status" "Quit")
        select opt in "${options[@]}"; do
            case $opt in
                "Install Docker") install_docker ;;
                "Uninstall Docker") uninstall_docker ;;
                "Reinstall Docker") uninstall_docker; install_docker ;;
                "Check Status") docker --version && systemctl status docker --no-pager | head -n 5 || echo "Not installed." ;;
                "Quit") break ;;
                *) echo "Invalid option." ;;
            esac
        done
        ;;
esac
