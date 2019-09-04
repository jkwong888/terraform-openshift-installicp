# Licensed Materials - Property of IBM
# IBM Cloud private
# @ Copyright IBM Corp. 2019 All Rights Reserved
# US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.

---

# A list of OpenShift nodes that used to run ICP components
cluster_nodes:
  master:
${workerlist}
  proxy:
${workerlist}
  management:
${workerlist}

storage_class: ${storage_class}

openshift:
  console:
    host: console.${app_subdomain}
    port: 443
  router:
    cluster_host: icp-console.${app_subdomain}
    proxy_host: icp-proxy.${app_subdomain}

password_rules:
- '(.*)'

default_admin_password: ${icp_admin_password}

## You must have different ports if you deploy nginx ingress to OpenShift master node
# ingress_http_port: 80
# ingress_https_port: 443

kubernetes_cluster_type: openshift
## You can disable following services if they are not needed
## Disabling services may impact the installation of IBM CloudPaks.
## Proceed with caution and refer to the Knowledge Center document for specific considerations.
# auth-idp
# auth-pap
# auth-pdp
# catalog-ui
# helm-api
# helm-repo
# icp-management-ingress
# metering
# metrics-server
# mgmt-repo
# monitoring
# nginx-ingress
# oidcclient-watcher
# platform-api
# platform-ui
# secret-watcher
# security-onboarding
# web-terminal

management_services:
  monitoring: enabled
  metering: enabled
  logging: enabled
  custom-metrics-adapter: disabled
  platform-pod-security: enabled
#  multicluster-hub: ${installmcm}
#  multicluster-endpoint: ${installmcm}
# single_cluster_mode: ${installmcm}
