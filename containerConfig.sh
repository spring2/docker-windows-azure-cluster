#!/bin/bash
set -e

# to see output:
# ls /var/lib/waagent/custom-script/download/0/
# cat /var/log/azure/custom-script/handler.log

# https://docs.docker.com/engine/installation/linux/docker-ce/ubuntu/#install-using-the-convenience-script
curl -fsSL get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker docker
