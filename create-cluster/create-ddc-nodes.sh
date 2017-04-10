#!/bin/bash

echo "Installing control plane to vSphere..."

VIC_MACHINE_BIN=$1
CREATE_CLUSTER_BIN=$2

$VIC_MACHINE_BIN create \
 --name "$(jq -r ".swarm.name" config.json)" \
 --target "$(jq -r ".vsphere.target" config.json)" \
 --thumbprint "$(jq -r ".vsphere.thumbprint" config.json)" \
 --user "$(jq -r ".vsphere.user" config.json)" \
 --image-store "$(jq -r ".storage.image" config.json)" \
 --password "$(jq -r ".vsphere.password" config.json)" \
 --no-tls \
 --container-network "$(jq -r ".network.public" config.json)" \
 --bridge-network "$(jq -r ".network.bridge" config.json)" \
 --public-network "$(jq -r ".network.public" config.json)" \
 --compute-resource "$(jq -r ".vsphere.cluster" config.json)" \
 --timeout "$(jq -r ".installer.timeout" config.json)" \
 --volume-store "$(jq -r ".storage.volume" config.json)" \
 --debug 0 \
 --force > /tmp/vic-machine-output.txt

if [ $? -ne 0 ]; then
   echo "Control plane failed to install see output here:"
   cat /tmp/vic-machine-output.txt
   exit 1
else
   DOCKER_ENDPOINT_IP=$(cat /tmp/vic-machine-output.txt | grep DOCKER_HOST | cut -d '=' -f 2)
   echo "Control plane install success to $DOCKER_ENDPOINT_IP"
fi

$CREATE_CLUSTER_BIN config.json $DOCKER_ENDPOINT_IP

