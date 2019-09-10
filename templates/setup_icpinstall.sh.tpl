#!/bin/bash
set -x

test -d ${icp_install_path} || sudo mkdir -p ${icp_install_path}
cd ${icp_install_path}

if [[ ${icp_binary} == http* ]]; then
    echo "HTTP binary found"
    hostname=$(echo ${icp_binary}|awk -F/ '{print $3}')
    filename=$(echo ${icp_binary}|awk -F$${hostname} '{print $2}')
    basename=$(basename $${filename})

    if [ ! -e "${icp_install_path}/$${basename}" ]; then
      sudo curl -k -o ${icp_install_path}/$${basename} ${icp_binary}
    fi
elif [[ ${icp_binary} == nfs* ]]; then
    echo "NFS binary found"
    hostname=$(echo ${icp_binary}|awk -F/ '{print $3}')
    filename=$(echo ${icp_binary}|awk -F$${hostname} '{print $2}')
    filepath=$(dirname $${filename})
    basename=$(basename $${filename})

    if [ ! -e "${icp_install_path}/$${basename}" ]; then
      sudo mkdir /tmp/nfsmount
      sudo mount -t nfs $${hostname}:$${filepath} /tmp/nfsmount
      sudo cp /tmp/nfsmount/$${basename} ${icp_install_path}
      sudo umount /tmp/nfsmount
      sudo rm -rf /tmp/nfsmount
    fi
elif [[ ${icp_binary} == docker* ]]; then
    echo "Docker image registry"
    inception_image=`echo ${icp_binary} | sed -e 's/docker:\/\///g'`
    image_reg_url=`echo ${icp_binary} | sed -e 's/docker:\/\///g' | awk -F/ '{print $1;}'`
    if [ ! -z "${icp_image_registry_username}" -a ! -z "${icp_image_registry_password}" ]; then
      sudo docker login $${image_reg_url} -u ${icp_image_registry_username} -p ${icp_image_registry_username}
    fi
    sudo docker pull $${inception_image}
else
    echo "Bad binary: ${icp_binary}"
    exit 1
fi

if [ ! -z "$${basename}" ]; then
  sudo tar xf ${icp_install_path}/$${basename} -O | sudo docker load
  inception_image=$(sudo docker images|grep icp-inception|awk '{print $1":"$2}')
fi

sudo docker run --rm -v $(pwd):/data:z -e LICENSE=accept --security-opt label:disable $${inception_image} cp -r cluster /data
sudo chown -R ${ssh_user} ${icp_install_path}
