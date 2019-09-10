#!/bin/bash

cd ${icp_install_path}/cluster
inception_image=$(sudo docker images|grep icp-inception|awk '{print $1":"$2}')

docker run -t --net=host -e LICENSE=accept -v /etc/docker:/etc/docker:z -v $(pwd):/installer/cluster:z -v /var/run:/var/run:z --security-opt label:disable $${inception_image} addon -vvvv

/usr/local/bin/kubectl --kubeconfig ${icp_install_path}/cluster/kubeconfig get nodes
# moved to waitforscc.sh
