#!/bin/bash

cd ${icp_install_path}/cluster
inception_image=$(sudo docker images|grep icp-inception-amd64|awk '{print $1":"$2}')

while true; do
    # echo "WAITING FOR ICP-SCC"
    if $(oc get scc icp-scc > /dev/null 2>&1); then
        kubectl --kubeconfig /etc/origin/master/admin.kubeconfig patch scc icp-scc -p '{"allowPrivilegedContainer": true}'
        kubectl --kubeconfig /etc/origin/master/admin.kubeconfig get scc icp-scc
        echo "ICP-SCC PATCHED"
        break
    else
        sleep 5
    fi
done &

docker run -t --net=host -e LICENSE=accept -v $(pwd):/installer/cluster:z -v /var/run:/var/run:z --security-opt label:disable $${inception_image} install-with-openshift

kubectl --kubeconfig /etc/origin/master/admin.kubeconfig get nodes
# moved to waitforscc.sh
