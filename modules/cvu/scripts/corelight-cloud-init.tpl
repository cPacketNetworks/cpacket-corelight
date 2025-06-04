#!/bin/bash
# shellcheck disable=SC2154
set -ex

mtu_size="9000"
ip li set mtu "$mtu_size" dev eth0

# Wait until outbound connection...
until wget -q --spider http://cpacket.com; do
  sleep 10
done

# Install or update dependencies
export DEBIAN_FRONTEND=noninteractive
apt update
apt install -y \
  apt-transport-https \
  ca-certificates \
  curl \
  gnupg \
  jq \
  lsb-release \
  software-properties-common

# Install Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg |
  gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" |
  tee /etc/apt/sources.list.d/docker.list >/dev/null

apt update
apt-cache policy docker-ce
apt install -y docker-ce

usermod -aG docker ubuntu

# Install Azure CLI
# https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-linux?pivots=apt
sudo mkdir -p /etc/apt/keyrings
curl -sLS https://packages.microsoft.com/keys/microsoft.asc |
  gpg --dearmor |
  sudo tee /etc/apt/keyrings/microsoft.gpg >/dev/null
chmod go+r /etc/apt/keyrings/microsoft.gpg

AZ_DIST="$(lsb_release -cs)"
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/azure-cli/ $AZ_DIST main" |
  tee /etc/apt/sources.list.d/azure-cli.list

sudo apt update
sudo apt install -y azure-cli

az login --identity
az acr login --name "${registry}"
docker pull "${registry}.azurecr.io/${corelight_softsensor_image}:${image_tag}"

docker run --net host --detach "${registry}.azurecr.io/${corelight_softsensor_image}:${image_tag}"
