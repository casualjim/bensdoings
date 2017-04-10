#!/bin/bash 

set -e -o pipefail

brgren="$(tput setaf 10)"
brblue="$(tput setaf 12)"
bryllw="$(tput setaf 11)"
creset="$(tput sgr0)"

yarrow="${bryllw}=>${creset} "
barrow="${brblue}==>${creset} "
garrow="${brgren}  ->${creset} "


CONFIG_FILE=$1
export DOCKER_HOST=$2

MASTER_NAME="manager1"
NODE_CREATE_RETRY="3"

EXTERNAL_NET="$(jq -r ".network.public" $CONFIG_FILE)"
CONTAINER_NET="$(jq -r ".network.nsx" $CONFIG_FILE)"
NODE_IMAGE="$(jq -r ".image.node" $CONFIG_FILE)"
MASTER_IMAGE="$(jq -r ".image.master" $CONFIG_FILE)"
SWARM_ADMIN="$(jq -r ".ucp.admin.name" $CONFIG_FILE)"
SWARM_ADMIN_PWD="$(jq -r ".ucp.admin.password" $CONFIG_FILE)"
SWARM_CLUSTER="$(jq -r ".swarm.name" $CONFIG_FILE)"
SWARM_NODE_MEM="$(jq -r ".swarm.node.mem" $CONFIG_FILE)"
SWARM_NODE_VCPU="$(jq -r ".swarm.node.cpus" $CONFIG_FILE)"
SWARM_NODE_IMAGE_CACHE="$(jq -r ".swarm.node.image_cache" $CONFIG_FILE)"
MANAGER_COUNT="$(jq -r ".swarm.manager_count" $CONFIG_FILE)"
WORKER_COUNT="$(jq -r ".swarm.worker_count" $CONFIG_FILE)"
DOCKER_OPTS="$(jq -r ".swarm.docker_opts" $CONFIG_FILE)"
UCP_VERSION="$(jq -r ".ucp.version" $CONFIG_FILE)"
NCP_MANAGER="$(jq -r ".ncp.nsx_manager" $CONFIG_FILE)"
NCP_MANAGER_USER="$(jq -r ".ncp.nsx_user" $CONFIG_FILE)"
NCP_MANAGER_PWD="$(jq -r ".ncp.nsx_password" $CONFIG_FILE)"
NCP_OVERLAY_TZ=$(jq -r ".ncp.overlay_tz" $CONFIG_FILE)
NCP_TIER0_ROUTER=$(jq -r ".ncp.tier0_router" $CONFIG_FILE)
NCP_IP_BLOCK_ID=$(jq -r ".ncp.ip_block_id" $CONFIG_FILE)
export GOVC_URL=$(jq -r ".vsphere.target" $CONFIG_FILE)
export GOVC_USERNAME=$(jq -r ".vsphere.user" $CONFIG_FILE)
export GOVC_PASSWORD=$(jq -r ".vsphere.password" $CONFIG_FILE)
export GOVC_INSECURE=1

# Params:
#   volume name
#   node name
#   image name
create_node()
{
   echo "${barrow}Creating node $2..."
   docker volume create --name=$1 --opt Capacity="$SWARM_NODE_IMAGE_CACHE" &> /dev/null
   local n=0
   until [ $n -ge $NODE_CREATE_RETRY ]
   do
      docker create -e DOCKER_OPTS=$DOCKER_OPTS --name=$2 -v $1:/var/lib/docker -m "$SWARM_NODE_MEM" --cpuset-cpus $SWARM_NODE_VCPU --net=$EXTERNAL_NET $3 &> /dev/null &&\
      govc vm.network.add --vm "$(docker inspect -f '{{ index (split .Name "/") 1 }}-{{ .Config.Hostname }}' "$2")" --net "$CONTAINER_NET" -net.adapter=vmxnet3 &&\
      docker start $2 &> /dev/null &&\
      break

      n=$[$n+1]
      sleep 1
      docker rm $2
   done

   ip=$(docker inspect --format "{{ .NetworkSettings.Networks.$EXTERNAL_NET.IPAddress }}" $2)
   echo -n "${garrow}Waiting for SSH to become available"
   while ! nc -q 1 $ip 22 </dev/null &> /dev/null
   do
      sleep 1
      echo -n "."
   done
   echo "."

   echo "${garrow}Copying root SSH key to $2"
   ssh-keyscan $ip >> ~/.ssh/known_hosts 2> /dev/null
   sshpass -p vmware ssh vmware@$ip "sudo /usr/bin/adduserkey root \"$4\"" > /dev/null

   echo -n "${garrow}Waiting for docker to become available"
   while ! ssh $ip test -e /var/run/docker.sock &>/dev/null
   do
     sleep 1
     echo -n "."
   done
   echo "."
   
   echo "${garrow}Installing vSphere volume driver"
   ssh $ip "docker plugin install --grant-all-permissions --alias vsphere vmware/docker-volume-vsphere:0.13 2>&1 > /dev/null"
}

# Params:
#   node name
#   swarm token
#   manager IP
join_swarm_node()
{
   echo "${barrow}Joining $1 to Swarm"
   ip=$(docker inspect --format "{{ .NetworkSettings.Networks.$EXTERNAL_NET.IPAddress }}" $1)
   msg=$(ssh $ip "docker swarm join --token $2 $3:2377")
   echo "${garrow}$msg"
   echo "${garrow}Installing NSX plugin"
   ssh $ip "docker plugin install --grant-all-permissions --alias nsx viddc-nsx.eng.vmware.local/nsx:ivan" &> /dev/null
}

echo "${yarrow}Pulling node images..."

docker pull $MASTER_IMAGE > /dev/null 2>&1
if [ "$NODE_IMAGE" != "$MASTER_IMAGE" ]; then
  docker pull $NODE_IMAGE > /dev/null 2>&1
fi

echo "${yarrow}Deploying docker datacenter"
echo "${barrow}Creating root SSH key to $MASTER_NAME"
ssh-keygen -b 2048 -t rsa -f ~/.ssh/id_rsa -q -N ""
ssh_key=$(cat /root/.ssh/id_rsa.pub)
create_node "m1-vol" "$MASTER_NAME" "$MASTER_IMAGE" "$ssh_key"

export MANAGER1_IP=$(docker inspect --format "{{ .NetworkSettings.Networks.$EXTERNAL_NET.IPAddress }}" manager1)

# needs to happen before create node so that the network plugin has access to NCP for registration
echo "${barrow}Installing NCP to $MANAGER1_IP"
cat <<EOF > /tmp/ncp.ini
[DEFAULT]

[coe]
adaptor = docker
cluster = $SWARM_CLUSTER

[docker]
# If true, sends the logs to local syslog daemon
# use_syslog = True
# If true, sends the logs to stderr
use_stderr = True

[k8s]

[nsx_v3]
nsx_api_user = $NCP_MANAGER_USER
nsx_api_password = $NCP_MANAGER_PWD
nsx_api_managers = $NCP_MANAGER
default_overlay_tz = $NCP_OVERLAY_TZ
insecure = true
default_tier0_router = $NCP_TIER0_ROUTER
ip_block_id = $NCP_IP_BLOCK_ID
subnet_prefix = 24
EOF
ssh $MANAGER1_IP "mkdir -p /etc/nsx-ujo"
scp /tmp/ncp.ini $MANAGER1_IP:/etc/nsx-ujo/ncp.ini &> /dev/null
ssh $MANAGER1_IP "docker run -d --name ncp --volume /etc/nsx-ujo:/etc/nsx-ujo --network host viddc-nsx.eng.vmware.local/ncp:docker" &> /dev/null

echo -n "${garrow}Waiting for NCP to become available"
while ! nc -q 1 $MANAGER1_IP 6798 </dev/null &> /dev/null
do
  sleep 1
  echo -n "."
done
echo "."

for ((i=2; i<=$MANAGER_COUNT; i++))
do
   create_node "m"$i"-vol" "manager"$i"" "$NODE_IMAGE" "$ssh_key"
done

for ((i=1; i<=$WORKER_COUNT; i++))
do
   create_node "w"$i"-vol" "worker"$i"" "$NODE_IMAGE" "$ssh_key"
done

echo "${barrow}Installing UCP $UCP_VERSION to $MANAGER1_IP"
echo "${garrow}Pull docker/ucp:$UCP_VERSION" 
ssh $MANAGER1_IP "docker pull docker/ucp:$UCP_VERSION" &> /dev/null
echo "${garrow}Configure UCP"
ssh $MANAGER1_IP "docker run --rm --name ucp -v /var/run/docker.sock:/var/run/docker.sock docker/ucp:$UCP_VERSION install --host-address $MANAGER1_IP --admin-username $SWARM_ADMIN --admin-password $SWARM_ADMIN_PWD"
echo "${garrow}Install NSX network plugin"
ssh $MANAGER1_IP "docker plugin install --grant-all-permissions --alias nsx viddc-nsx.eng.vmware.local/nsx:ivan" &> /dev/null

export MTOKEN=$(ssh $MANAGER1_IP docker swarm join-token -q manager)
export WTOKEN=$(ssh $MANAGER1_IP docker swarm join-token -q worker)

for ((i=2; i<=$MANAGER_COUNT; i++))
do
   join_swarm_node "manager"$i"" $MTOKEN $MANAGER1_IP
done

for ((i=1; i<=$WORKER_COUNT; i++))
do
   join_swarm_node "worker"$i"" $WTOKEN $MANAGER1_IP
done

