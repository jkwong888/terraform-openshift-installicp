#!/bin/bash
while ! $(oc get scc icp-scc > /dev/null 2>&1);do
    echo WAITING FOR ipc-scc
    sleep 5
done

kubectl --kubeconfig /etc/origin/master/admin.kubeconfig patch scc icp-scc -p '{"allowPrivilegedContainer": true}'
kubectl --kubeconfig /etc/origin/master/admin.kubeconfig get scc icp-scc
echo "ICP-SCC PATCHED"
