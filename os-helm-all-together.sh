#!/bin/bash

#Uncomment out this if you want full debug output
#set -xe

# This script can be used to setup the Kubeadm All-in-One environment on Ubuntu 16.04.
# This script should not be run as root but as a different user. Create a new user
# and give it root privileges if required.

if [[ $EUID -eq 0 ]]; then echo "This script should not be run using sudo or as the root user"; exit 1; fi

### Declare colors to use during the running of this script:
declare -r GREEN="\033[0;32m"
declare -r RED="\033[0;31m"
declare -r YELLOW="\033[0;33m"

function echo_green {
  echo -e "${GREEN}$1"; tput sgr0
}
function echo_red {
  echo -e "${RED}$1"; tput sgr0
}
function echo_yellow {
  echo -e "${YELLOW}$1"; tput sgr0
}

source os-helm-env
cd ~/

echo_green "\n Sourcing os-helm-env variables"

echo_green "\n Installing OS Helm Tiller Kubernetes Infrastructure"
source ~/os-helm-aio-installer/os-helm-kube-infrastructure.sh

echo_green "\n Installing OpenStack"

read -p "Use FQDN settings for Helm Charts installer? y/n  " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
  source ~/os-helm-aio-installer/os-helm-wFQDN.sh
else
  source ~/os-helm-aio-installer/os-helm-only.sh
fi

# Assuming OS-Helm installed first with Ingress
echo_green "\n Installing Kubernetes Infra Weave w Ingress"
source ~/os-helm-aio-installer/kube-weavescope-fqdn.sh

echo_green "\n Installing Kubernetes Infra Dashboard w Ingress"
source ~/os-helm-aio-installer/kube-dashboard-fqdn.sh