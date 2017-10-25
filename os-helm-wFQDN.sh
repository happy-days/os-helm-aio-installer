#!/bin/bash

#Uncomment out this if you want full debug output
#set -xe

# This script can be used to setup OpenStack Helm WITH Ingress/FQDN support


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
cd ~/openstack-helm

echo_green "\n Sourcing os-helm-env variables"

#The provided Makefile in OpenStack-Helm will perform the following:
#Lint: Validate that your helm charts have no basic syntax errors.
#Package: Each chart will be compiled into a helm package that will contain
#all of the resource definitions necessary to run an application,tool,
#or service inside of a Kubernetes cluster.
#Push: Push the Helm packages to your local Helm repository.
make

#Using the Helm packages previously pushed to the local Helm repository,
#run the following commands to instruct tiller to create an instance of
#the given chart. During installation, the helm client will print useful
#information about resources created, the state of the Helm releases,
#and whether any additional configuration steps are necessary.
helm install --name=mariadb local/mariadb --set volume.size=${MARIADB_SIZE} --namespace=openstack
echo -e -n "Waiting for all MariaDB members to come online..."
while true; do
  running_count=$(kubectl get pods -n openstack --no-headers 2>/dev/null | grep "mariadb" | grep "Running" | grep "1/1" | wc -l)
  if [ "$running_count" -ge 3 ]; then
    break
  fi
  echo -n "."
  sleep 2
done
echo_green "SUCCESS"
echo_green "MariaDB deployed!"
echo ""
helm install --name=memcached local/memcached --namespace=openstack
helm install --name=etcd-rabbitmq local/etcd --namespace=openstack
helm install --name=rabbitmq local/rabbitmq --namespace=openstack
echo -e -n "Waiting for RabbitMQ members to come online..."
while true; do
  running_count=$(kubectl get pods -n openstack --no-headers 2>/dev/null | grep "rabbitmq" | grep "Running" | grep "1/1" | wc -l)
  if [ "$running_count" -ge 3 ]; then
    break
  fi
  echo -n "."
  sleep 2
done
echo_green "SUCCESS"
echo_green "RabbitMQ deployed!"
echo ""

helm install --name=ingress local/ingress --namespace=openstack
echo -e -n "Waiting for ingress to come online..."
while true; do
  running_count=$(kubectl get pods -n openstack --no-headers 2>/dev/null | grep "ingress" | grep "Running" | grep "1/1" | wc -l)
  if [ "$running_count" -ge 2 ]; then
    break
  fi
  echo -n "."
  sleep 1
done
echo_green "SUCCESS"
echo_green "Ingress is now ready!"
echo ""

#Once the OpenStack infrastructure components are installed and running,
#the OpenStack services can be installed. In the below examples the default
#values that would be used in a production-like environment have been
#overridden with more sensible values for the All-in-One environment using
#the --values and --set options.
helm install --name=keystone local/keystone --namespace=openstack \
  --set endpoints.identity.host_fqdn_override.public=keystone.$FQDN
while true; do
  running_count=$(kubectl get pods -n openstack --no-headers 2>/dev/null | grep "keystone" | grep "Running" | grep "1/1" | wc -l)
  if [ "$running_count" -ge 1 ]; then
    break
  fi
  echo -n "."
  sleep 1
done
echo_green "SUCCESS"
echo_green "keystone is now ready!"
echo ""

helm install --name=glance local/glance --namespace=openstack \
  --set storage=pvc \
  --set endpoints.image.host_fqdn_override.public=glance.$FQDN \
  --set endpoints.identity.host_fqdn_override.public=keystone.$FQDN
while true; do
  running_count=$(kubectl get pods -n openstack --no-headers 2>/dev/null | grep "glance" | grep "Running" | grep "1/1" | wc -l)
  if [ "$running_count" -ge 2 ]; then
    break
  fi
  echo -n "."
  sleep 1
done
echo_green "SUCCESS"
echo_green "glance is now ready!"
echo ""

helm install --name=libvirt local/libvirt --namespace=openstack \
  --set=ceph.enabled=false

echo_green "SUCCESS"
echo_green "libvirt is now ready!"
echo ""



if [ -z ${OVS_EXTERNAL_INTERFACE+x} ]; then
 helm install --name=openvswitch local/openvswitch --namespace=openstack
else
 helm install --name=openvswitch local/openvswitch \
 --namespace=openstack --set=network.interface.external=$OVS_EXTERNAL_INTERFACE 
fi

echo_green "SUCCESS"
echo_green "openvswitch is now ready!"
echo ""


helm install --name=nova local/nova --namespace=openstack \
  --values=./tools/overrides/mvp/nova.yaml \
  --set conf.nova.libvirt.virt_type=qemu \
  --set endpoints.compute.host_fqdn_override.public=nova.$FQDN \
  --set endpoints.compute_metadata.host_fqdn_override.public=metadata.$FQDN \
  --set endpoints.image.host_fqdn_override.public=glance.$FQDN \
  --set endpoints.network.host_fqdn_override.public=neutron.$FQDN \
  --set endpoints.identity.host_fqdn_override.public=keystone.$FQDN
while true; do
  running_count=$(kubectl get pods -n openstack --no-headers 2>/dev/null | grep "nova" | grep "Running" | grep "1/1" | wc -l)
  if [ "$running_count" -ge 6 ]; then
    break
  fi
  echo -n "."
  sleep 1
done
echo_green "SUCCESS"
echo_green "nova is now ready!"
echo ""


if [ -z ${NEUTRON_PROVIDER_SUBNET+x} ]; then
  helm install --name=neutron local/neutron \
  --namespace=openstack --values=./tools/overrides/mvp/neutron-ovs.yaml \
  --set endpoints.network.host_fqdn_override.public=neutron.$FQDN \
  --set endpoints.compute.host_fqdn_override.public=nova.$FQDN \
  --set endpoints.identity.host_fqdn_override.public=keystone.$FQDN
else
  helm install --name=neutron local/neutron \
  --namespace=openstack --values=./tools/overrides/mvp/neutron-ovs.yaml \
  --set endpoints.network.host_fqdn_override.public=neutron.$FQDN \
  --set endpoints.compute.host_fqdn_override.public=nova.$FQDN \
  --set endpoints.identity.host_fqdn_override.public=keystone.$FQDN \
  --set=network.interface.external=$OVS_EXTERNAL_INTERFACE \
  --set=conf.ml2_conf.ml2_type_vlan.neutron.ml2.network_vlan_ranges=$NEUTRON_ML2_EXTERNAL_NETWORK:$NEUTRON_PROVIDER_VLAN:$NEUTRON_PROVIDER_VLAN \
  --set=bootstrap.enabled=true \
  --set=bootstrap.script="
  neutron agent-list

  openstack network list

  openstack subnet list

  openstack network create --share --provider-physical-network $NEUTRON_ML2_EXTERNAL_NETWORK --provider-network-type vlan  --provider-segment $NEUTRON_PROVIDER_VLAN  provider-$NEUTRON_PROVIDER_VLAN

  openstack subnet create --subnet-range $NEUTRON_PROVIDER_SUBNET --gateway $NEUTRON_PROVIDER_GATEWAY --network provider-$NEUTRON_PROVIDER_VLAN --allocation-pool start=$NEUTRON_PROVIDER_IP_START\,end=$NEUTRON_PROVIDER_IP_END --dns-nameserver $DNS_NAMESERVER provider-subnet

  openstack network list

  openstack subnet list
"
fi

while true; do
  running_count=$(kubectl get pods -n openstack --no-headers 2>/dev/null | grep "neutron" | grep "Running" | grep "1/1" | wc -l)
  if [ "$running_count" -ge 4 ]; then
    break
  fi
  echo -n "."
  sleep 1
done
echo_green "SUCCESS"
echo_green "neutron is now ready!"
echo ""

helm install --name=horizon local/horizon --namespace=openstack \
  --set=network.enable_node_port=true \
  --set endpoints.dashboard.host_fqdn_override.public=horizon.$FQDN \
  --set endpoints.identity.host_fqdn_override.public=keystone.$FQDN
while true; do
  running_count=$(kubectl get pods -n openstack --no-headers 2>/dev/null | grep "horizon" | grep "Running" | grep "1/1" | wc -l)
  if [ "$running_count" -ge 1 ]; then
    break
  fi
  echo -n "."
  sleep 1
done
echo_green "SUCCESS"
echo_green "horizon is now ready!"
echo ""

echo_green  "The Openstack Cloud has been installed successfully!"
echo ""

#Once the install commands have been issued, executing the following will
#provide insight into the services deployment status.
#watch kubectl get pods --namespace=openstack

