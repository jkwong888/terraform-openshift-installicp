
variable "bastion_ip_address" {}
variable "bastion_ssh_user" {}
variable "bastion_ssh_password" {}
variable "bastion_ssh_private_key" {}

variable "worker" { type = "map" }
variable "worker_hostname" { type = "list" }
variable "worker_ip_address" { type = "list" }
variable "master_hostname"   { type = "list" }
variable "master_ip_address" { type = "list" }
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
variable "icp_install_path" {
    default = "/opt/ibm-cloud-private-rhos-3.2.0"
}

variable "dependson" {
    type = "list"
    default = []
}
