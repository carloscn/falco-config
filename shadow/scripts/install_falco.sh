#!/usr/bin/env bash
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update
sudo apt-get install -y curl apt-transport-https gnupg lsb-release
curl -s https://falco.org/repo/falcosecurity-packages.asc | sudo gpg --dearmor -o /usr/share/keyrings/falco-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/falco-archive-keyring.gpg] https://download.falco.org/packages/deb stable main" | sudo tee /etc/apt/sources.list.d/falcosecurity.list
sudo apt-get update
sudo apt-get install -y falco
sudo rm -f /etc/falco/config.d/falco.container_plugin.yaml
