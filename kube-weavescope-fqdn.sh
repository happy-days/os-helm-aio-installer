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
cd ~/os-helm-installer



#Remove the kubernetes/charts directory and all of its contents
#TODO: Make this idempotent
rm -rf charts

echo_green "----- Clones the repository that holds Charter scripts"
#git clone https://github.com/kubernetes/charts.git ##TODO
cd charts/stable


echo_green "----- Install WeaveScope with FQDN"

# replace placeholder with actually fdqn from os-helm-env
sed -i -e "s/fqdn_host/weave.$FQDN/g" scope.yaml

kubectl apply --namespace kube-system -f scope.yaml
while true; do
  running_count=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | grep "weave-scope-app" | grep "Running" | grep "1/1" | wc -l)
  if [ "$running_count" -ge 1 ]; then
    break
  fi
  echo -n "."
  sleep 1
done
echo_green "SUCCESS"
echo_green "Kuberenetes WeaveScope Now Ready!"
echo ""

#Once the install commands have been issued, executing the following will
#provide insight into the services deployment status.
#watch kubectl get pods --namespace=openstack
