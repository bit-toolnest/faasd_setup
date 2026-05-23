#!/bin/bash

set -euo pipefail

############################################
# Version variables (match install.sh)
############################################
export OWNER="bitresearch2006"
export REPO="faasd"
export CNI_VERSION="v1.9.1"
export CONTAINERD_VERSION="1.7.27"

SUDO=sudo
if [ "$(id -u)" -eq 0 ]; then SUDO=; fi

############################################
# Stop services
############################################
echo "➡ Stopping faasd services..."
$SUDO systemctl stop faasd || true
$SUDO systemctl disable faasd || true

echo "➡ Stopping containerd..."
$SUDO systemctl stop containerd || true
$SUDO systemctl disable containerd || true

############################################
# Remove faasd binary + configs
############################################
echo "➡ Removing faasd binary..."
$SUDO rm -f /usr/local/bin/faasd

echo "➡ Removing faasd configs..."
$SUDO rm -rf /etc/faasd
$SUDO rm -rf /var/lib/faasd
$SUDO rm -rf /tmp/faasd-*installation

############################################
# Remove systemd unit files
############################################
echo "➡ Removing systemd unit files..."
$SUDO rm -f /etc/systemd/system/faasd.service
$SUDO rm -f /etc/systemd/system/faasd-provider.service

############################################
# Remove CNI plugins
############################################
echo "➡ Removing CNI plugins..."
$SUDO rm -rf /opt/cni/bin

############################################
# Remove containerd (optional)
############################################
echo "➡ Removing containerd..."
$SUDO apt-get remove -y containerd runc || true
$SUDO apt-get autoremove -y
$SUDO apt-get clean

############################################
# Remove arkade + faas-cli (optional)
############################################
echo "➡ Removing arkade and faas-cli..."
$SUDO rm -f /usr/local/bin/arkade
$SUDO rm -f /usr/local/bin/faas-cli
rm -rf $HOME/.arkade || true

############################################
# Final cleanup
############################################
echo "✅ faasd platform uninstalled successfully"
