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
echo "----- Setup etc/hosts"
#Setup etc/hosts
HOST_IFACE=$(ip route | grep "^default" | head -1 | awk '{ print $5 }')
LOCAL_IP=$(ip addr | awk "/inet/ && /${HOST_IFACE}/{sub(/\/.*$/,\"\",\$2); print \$2}")
cat << EOF | sudo tee -a /etc/hosts
${LOCAL_IP} $(hostname)
EOF


#Installs the latest verisions of vim, curl, git, nfs-common, make, and docker.io
#Installing docker.io this way rather than from the base is required because of api changes within docker that break osh

echo_green "\nPhase I: Installing system prerequisites:"

echo $PREREQ_PACKAGES

for pkg in $PREREQ_PACKAGES; do
    if sudo dpkg --get-selections | grep -q "^$pkg[[:space:]]*install$" >/dev/null; then
        echo_yellow "$pkg is already installed"
    else
        sudo apt-get update && sudo apt-get -qq install $pkg
        echo_green "Successfully installed $pkg"
    fi
done

#Start and enable docker if it isn't already running
echo "---- check if docker running"
if sudo docker ps
then
	echo "----- skip docker"
else
	echo "----- start docker"
	sudo systemctl start docker
  sudo systemctl enable docker
fi

echo "----- Downloads and installs kubectl, the command line interface for running"
#Downloads and installs kubectl, the command line interface for running
#commands against your Kubernetes cluster.
export TMP_DIR=$(mktemp -d)

curl -sSL https://storage.googleapis.com/kubernetes-release/release/${KUBE_VERSION}/bin/linux/amd64/kubectl -o ${TMP_DIR}/kubectl
chmod +x ${TMP_DIR}/kubectl
sudo mv ${TMP_DIR}/kubectl /usr/local/bin/kubectl

echo "----- #Downloads and installs Helm, the package manager for Kubernetes"
curl -sSL https://storage.googleapis.com/kubernetes-helm/helm-${HELM_VERSION}-linux-amd64.tar.gz | tar -zxv --strip-components=1 -C ${TMP_DIR}
sudo mv ${TMP_DIR}/helm /usr/local/bin/helm
rm -rf ${TMP_DIR}

#Remove the copenstack-helm directory and all of its contents
#TODO: Make this idempotent
rm -rf openstack-helm

echo "----- #Clones the repository that holds all of the OpenStack service charts."
git clone https://github.com/openstack/openstack-helm.git
cd openstack-helm
git checkout ${OSH_VER}

#Kill the helm serve process
pkill -f 'helm serve'

#Remove the .helm directory and all of it's contents
rm -rf ~/.helm

echo "----- #Initialize the helm client and start listening on localhost:8879."
helm init --client-only

#Using the Dockerfile defined in tools/kubeadm-aio directory,
#this builds the openstackhelm/kubeadm-aio:v1.6.8 image.
#sudo docker build --pull -t ${KUBEADM_IMAGE} $(pwd)/tools/kubeadm-aio
sudo docker pull ${KUBEADM_IMAGE}

### WAIT FOR KUBERNETES ENVIRONMENT TO COME UP:
echo -e -n "Waiting for Kubeadm-AIO container to build..."
while true; do
  aio_exist=$(sudo docker images 2>/dev/null | grep "openstackhelm/kubeadm-aio" | wc -l)
  ### Expect all components to be out of a "ContainerCreating" state before collecting log data (this includes CrashLoopBackOff states):
  if [ "$aio_exist" -ge 1 ]; then
    break
  fi
  echo -n "."
  sleep 2
done
echo_green "SUCCESS"
echo_green "Container built!"
echo ""


#After the image is built, execute the kubeadm-aio-launcher script
#which creates a single node Kubernetes environment by default with Helm,
#Calico, an NFS PVC provisioner with appropriate RBAC rules and node labels
#to start developing. The following deploys the Kubeadm-AIO environment.
# Optionally uncomment sed line to extend the time-outs if you have a slower environment

#sed -i -e 's/480/3000/g' tools/kubeadm-aio/kubeadm-aio-launcher.sh

./tools/kubeadm-aio/kubeadm-aio-launcher.sh
if [ $? -ne 0 ]; then
    echo_red "kubeadm-aio-launcher script Failed!"
    exit
fi

mkdir -p  ${HOME}/.kube
cat ${KUBECONFIG} > ${HOME}/.kube/config



### WAIT FOR TILLER DEPLOYEMENT TO COME UP:
echo -e -n "Waiting for Tiller pods to build..."
while true; do
  tiller_exist=$(sudo kubectl get pods --namespace kube-system | grep "tiller" | grep "Running" | grep "1/1" | wc -l)
  if [ "$tiller_exist" -ge 1 ]; then
    echo "Tiller Running!!"
    break
  fi
  echo -n "."
  sleep 2
done

#Once the helm client is available, add the local repository to the helm client.
helm serve &
sleep 30
helm repo add local http://localhost:8879/charts
helm repo remove stable


#The provided Makefile in OpenStack-Helm will perform the following:
#Lint: Validate that your helm charts have no basic syntax errors.
#Package: Each chart will be compiled into a helm package that will contain
#all of the resource definitions necessary to run an application,tool,
#or service inside of a Kubernetes cluster.
#Push: Push the Helm packages to your local Helm repository.
make


