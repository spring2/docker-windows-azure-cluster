#!/bin/bash
set -e

# https://docs.docker.com/engine/installation/linux/docker-ce/ubuntu/#install-using-the-convenience-script
curl -fsSL get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker docker
