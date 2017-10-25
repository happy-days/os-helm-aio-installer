# About
This is a Kubernetes-All-In-One setup that includes all host updates, installing Helm, Tiller,
OpenStack apps via Helm and other Kubernetes apps. Based off of the 
[OpenStack-Helm AIO documents](http://openstack-helm.readthedocs.io/en/latest/install/developer/all-in-one.html). 

# Assumptions
These scripts are assuming a **Ubuntu 16.04** base host. Ideally two or more interfaces,
one as management and the other(s) as provider networks.

The user must not be root but have sudoers access. 

# Installation Instructions

__1. _Ignore if from Github_ - Disable https certificate verification for GIT__
    
    git config --global http.sslVerify "false"

__2. Clone the repository__
    
    git clone https://github.com/charter-ctec/os-helm-aio-installer.git

__3. Change to the installer directory__
    
    cd os-helm-aio-installer

__4. Optionally, edit the following variables in the os-helm-env file to setup the openstack provider networks and add a network interface to the OVS external bridge__
    
    export OVS_EXTERNAL_INTERFACE='eth1' ### MODIFY FOR YOUR ENVIRONMENT ###  
    export NEUTRON_PROVIDER_SUBNET='44.24.0.0/22'  
    export NEUTRON_PROVIDER_GATEWAY='44.24.0.1'  
    export NEUTRON_PROVIDER_VLAN='282'  
    export NEUTRON_PROVIDER_IP_START='44.24.0.100'  
    export NEUTRON_PROVIDER_IP_END='44.24.3.250'  
    export DNS_NAMESERVER='44.128.12.15'  
    export NEUTRON_ML2_EXTERNAL_NETWORK='public'

__4.1 Optionally Set up FDQN for Ingress__

Edit os-helm-env with your base FQDN

    export FQDN=os.spoc.linux ### MODIFY FOR YOUR ENVIRONMENT ###
    
Go to FreeIPA, Networks, DNS Zones - find your zone (i.e. spoc.linux)
and add A records for your Host

https://spoc-ipa.spoc.linux/ipa/ui/#/e/dnszone/records/spoc.linux.

    horizon.os          44.128.25.9
    dashboard.os        44.128.25.9
    
etc..

__5.  Run the openstack helm installer for all infrastructure and charts__
    
    ./os-helm-all-together.sh
    
__6.  Optionally, run scripts for any sub-component__

Install Infrastructure - apt-get packages, Docker, Kubernetes All-In-One, 
Helm, Tiller

    ./os-helm-kube-infrastructure.sh

Install OpenStack without FQDN (ingress settings)
    
    ./os-helm-only.sh

Install OpenStack with FQDN (ingress settings)
    
    ./os-helm-wFQDN.sh
    
Install Dashboard

    ./kube-dashboard-fqdn.sh
    
Install Weavescope

    ./kube-weavescope-fqdn.sh


__7. Cleanup__

Remove all Helm apps and settings

    ./cleanup_all.sh
    
Remove only OpenStack Helm apps

    ./os-helm-cleanup.sh
    


# Credit
Special credit and thanks to @mpednekar and @slarimore02 for all the initial work