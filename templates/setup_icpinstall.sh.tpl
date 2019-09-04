#!/bin/bash
set -x

test -e ${icp_install_path} || mkdir ${icp_install_path}
cd ${icp_install_path}


if [[ ${icp_binary} == http* ]]; then
    echo "HTTP binary found"
    hostname=$(echo ${icp_binary}|awk -F/ '{print $3}')
    filename=$(echo ${icp_binary}|awk -F$${hostname} '{print $2}')
    basename=$(basename $${filename})
    curl -k -o ${icp_install_path}/$${basename} ${icp_binary}
elif [[ ${icp_binary} == nfs* ]]; then
    echo "NFS binary found"
    hostname=$(echo ${icp_binary}|awk -F/ '{print $3}')
    filename=$(echo ${icp_binary}|awk -F$${hostname} '{print $2}')
    filepath=$(dirname $${filename})
    basename=$(basename $${filename})
    mkdir /tmp/nfsmount
    mount -t nfs $${hostname}:$${filepath} /tmp/nfsmount
    cp /tmp/nfsmount/$${basename} ${icp_install_path}
    umount /tmp/nfsmount
    rm -rf /tmp/nfsmount
elif [[ ${icp_binary} == docker* ]]; then
    echo "Docker image registry"
else
    echo "Bad binary: ${icp_binary}"
    exit 1
fi

sudo tar xf ${icp_install_path}/$${basename} -O | sudo docker load

inception_image=$(sudo docker images|grep icp-inception-amd64|awk '{print $1":"$2}')
sudo docker run --rm -v $(pwd):/data:z -e LICENSE=accept --security-opt label:disable $${inception_image} cp -r cluster /data
sudo cp /etc/origin/master/admin.kubeconfig ${icp_install_path}/cluster/kubeconfig
sudo chown -R ${ssh_user} ${icp_install_path}
sudo chmod +w ${icp_install_path}/cluster/ssh_key
