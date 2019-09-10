
variable "bastion_ip_address" {}
variable "bastion_ssh_user" {}
variable "bastion_ssh_password" {}
variable "bastion_ssh_private_key" {}

variable "worker_count" {
    default = 0
}

variable "openshift_inventory" {
    default = ""
}

variable "openshift_url" {
}

variable "openshift_admin_user" {
}

variable "openshift_admin_password" {
}

variable "worker_hostname" { type = "list" }
variable "worker_ip_address" { type = "list" }
variable "app_subdomain" {}
variable "icp_admin_password" {}
variable "storage_class" { default = "glusterfs-storage" }
variable "installmcm" {
    default = false
}



variable "icp_binary" {}
# icp_binary can have the following format
# nfs://hostname/path/to/file.tgz
# http[s]://hostname/path/to/file.tgz
# docker://registry/image:tag

variable icp_image_registry_username {
    description = "if icp_binary starts with docker://, use this username for docker login"
    default = ""
}

variable icp_image_registry_password {
    description = "if icp_binary starts with docker://, use this password for docker login"
    default = ""
}

variable "icp_install_path" {
    default = "/opt/ibm-cloud-private-rhos-3.2.0"
}

variable "dependson" {
    type = "list"
    default = []
}

variable "enabled_services" {
    type = "list"
    default = [ "metering", "monitoring", "auth-idp", "cert-manager", "tiller" ]
}

variable "custom_config_yaml" {
    type = "list"
    default = []
}
