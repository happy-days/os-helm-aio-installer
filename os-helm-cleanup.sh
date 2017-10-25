#!/bin/bash
#This program cleans up the deployed helm charts for OpenStack

helm delete --purge magnum
helm delete --purge mistral
helm delete --purge senlin
helm delete --purge barbican
helm delete --purge horizon
helm delete --purge neutron
helm delete --purge openvswitch
helm delete --purge libvirt
helm delete --purge nova
helm delete --purge cinder
helm delete --purge heat
helm delete --purge glance
helm delete --purge keystone
helm delete --purge memcached
helm delete --purge ingress
helm delete --purge etcd-rabbitmq
helm delete --purge rabbitmq
helm delete --purge mariadb
helm delete --purge bootstrap-openstack
helm delete --purge bootstrap-ceph
helm delete --purge ceph

kubectl delete namespace openstack


