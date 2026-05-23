#!/bin/bash

set -euo pipefail

############################################
# Version variables
############################################
export OWNER="openfaas"
export REPO="faasd"
export CNI_VERSION="v1.9.1"        # latest stable CNI plugins
export CONTAINERD_VERSION="1.7.27" # latest containerd with CVE fixes

############################################
# Utility functions
############################################
fatal() { echo "ERROR: $1"; exit 1; }

SUDO=sudo
if [ "$(id -u)" -eq 0 ]; then SUDO=; fi

############################################
# Detect latest faasd release
############################################
echo "Finding latest faasd version from GitHub..."
FAASD_VERSION=$(curl -sI https://github.com/$OWNER/$REPO/releases/latest \
 | grep -i "location:" | awk -F"/" '{print $NF}' | tr -d '\r')

echo "Latest faasd version: $FAASD_VERSION"
[ -z "$FAASD_VERSION" ] && fatal "Failed to detect faasd version"

############################################
# Verify system
############################################
arch=$(uname -m)
[ "$arch" == "armv7l" ] && fatal "faasd requires a 64-bit OS"
[ ! -d /run/systemd ] && fatal "systemd not detected"

############################################
# Install base dependencies
############################################
if command -v apt-get >/dev/null 2>&1; then
  $SUDO apt-get update -y
  $SUDO apt-get install -y curl runc bridge-utils iptables
elif command -v dnf >/dev/null 2>&1; then
  $SUDO dnf install -y curl runc iptables-services bridge-utils
elif command -v pacman >/dev/null 2>&1; then
  $SUDO pacman -Syy
  $SUDO pacman -Sy curl runc bridge-utils
else
  fatal "Unsupported package manager"
fi

############################################
# Install arkade
############################################
if ! command -v arkade >/dev/null 2>&1; then
  echo "Installing arkade..."
  curl -sLS https://get.arkade.dev | $SUDO sh
fi

############################################
# Install CNI plugins
############################################
$SUDO arkade system install cni \
  --version ${CNI_VERSION} \
  --path /opt/cni/bin \
  --progress=false

############################################
# Install containerd
############################################
$SUDO systemctl unmask containerd || true
$SUDO arkade system install containerd \
  --systemd \
  --version v${CONTAINERD_VERSION} \
  --progress=false
sleep 5

############################################
# Install faasd
############################################
suffix=""
[ "$arch" == "aarch64" ] && suffix="-arm64"

$SUDO curl -fSLs "https://github.com/$OWNER/$REPO/releases/download/${FAASD_VERSION}/faasd${suffix}" \
  -o "/usr/local/bin/faasd"
$SUDO chmod a+x "/usr/local/bin/faasd"

mkdir -p /tmp/faasd-${FAASD_VERSION}-installation/hack
cd /tmp/faasd-${FAASD_VERSION}-installation

$SUDO curl -fSLs "https://raw.githubusercontent.com/$OWNER/$REPO/${FAASD_VERSION}/docker-compose.yaml" -o "docker-compose.yaml"
$SUDO curl -fSLs "https://raw.githubusercontent.com/$OWNER/$REPO/${FAASD_VERSION}/prometheus.yml" -o "prometheus.yml"
$SUDO curl -fSLs "https://raw.githubusercontent.com/$OWNER/$REPO/${FAASD_VERSION}/resolv.conf" -o "resolv.conf"
$SUDO curl -fSLs "https://raw.githubusercontent.com/$OWNER/$REPO/${FAASD_VERSION}/hack/faasd-provider.service" -o "hack/faasd-provider.service"
$SUDO curl -fSLs "https://raw.githubusercontent.com/$OWNER/$REPO/${FAASD_VERSION}/hack/faasd.service" -o "hack/faasd.service"

$SUDO /usr/local/bin/faasd install

############################################
# Enable networking + services
############################################
$SUDO sysctl -w net.ipv4.conf.all.forwarding=1
grep -q "net.ipv4.conf.all.forwarding=1" /etc/sysctl.conf || \
  echo "net.ipv4.conf.all.forwarding=1" | $SUDO tee -a /etc/sysctl.conf

$SUDO systemctl daemon-reload
$SUDO systemctl enable containerd faasd
$SUDO systemctl start containerd faasd

echo "--------------------------------------"
echo "FAASD platform installed successfully"
echo "Gateway available at: http://127.0.0.1:8080"
echo "--------------------------------------"
