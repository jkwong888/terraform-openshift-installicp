resource "null_resource" "dependency" {
  triggers = {
    all_dependencies = "${join(",", var.dependson)}"
  }
}

locals {
  bastion_ip = "${var.bastion_ip_address}"
  # for enabled services map generation
  default_enabled_list = [
    "enabled",
    "enabled",
    "enabled",
    "enabled",
    "enabled",
    "enabled",
    "enabled",
    "enabled",
    "enabled",
    "enabled",
    "enabled",
    "enabled",
    "enabled",
    "enabled",
    "enabled",
    "enabled",
    "enabled",
    "enabled"
  ]

  default_disabled_services_map = {
    "auth-idp" = "disabled"
    "auth-pap" = "disabled"
    "auth-pdp" = "disabled"
    "catalog-ui" = "disabled"
    "helm-api" = "disabled"
    "helm-repo" = "disabled"
    "icp-management-ingress" = "disabled"
    "metering" = "disabled"
    "metrics-server" = "disabled"
    "mgmt-repo" = "disabled"
    "monitoring" = "disabled"
    "nginx-ingress" = "disabled"
    "oidcclient-watcher" = "disabled"
    "platform-api" = "disabled"
    "platform-ui" = "disabled"
    "secret-watcher" = "disabled"
    "security-onboarding" = "disabled"
    "web-terminal" = "disabled"
  }

  enabled_services_map = "${zipmap(var.enabled_services, slice(local.default_enabled_list, 0, length(var.enabled_services)))}"
  management_services_map = "${merge(local.default_disabled_services_map, local.enabled_services_map)}"
}

data "template_file" "config_yaml" {
  template = <<EOF
# Licensed Materials - Property of IBM
# IBM Cloud private
# @ Copyright IBM Corp. 2019 All Rights Reserved
# US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.

---

# A list of OpenShift nodes that used to run ICP components
cluster_nodes:
  master:
${join("\n", formatlist("    - %v", var.worker_hostname))}
  proxy:
${join("\n", formatlist("    - %v", var.worker_hostname))}
  management:
${join("\n", formatlist("    - %v", var.worker_hostname))}

storage_class: ${var.storage_class}

openshift:
  console:
    host: console.${var.app_subdomain}
    port: 443
  router:
    cluster_host: icp-console.${var.app_subdomain}
    proxy_host: icp-proxy.${var.app_subdomain}

password_rules:
- '(.*)'

default_admin_password: ${var.icp_admin_password}

## You must have different ports if you deploy nginx ingress to OpenShift master node
# ingress_http_port: 80
# ingress_https_port: 443

kubernetes_cluster_type: openshift

management_services:
${join("\n", formatlist("  %v: %v", keys(local.management_services_map), values(local.management_services_map) ))}"

multicluster-hub: ${var.installmcm}
multicluster-endpoint: ${var.installmcm}
single_cluster_mode: ${var.installmcm}

EOF

  depends_on = [
      "null_resource.dependency",
  ]
}

data "template_file" "setup_icpinstall" {
    template = "${file("${path.module}/templates/setup_icpinstall.sh.tpl")}"
    vars = {
        icp_binary = "${var.icp_binary}"
        icp_install_path = "${var.icp_install_path}"
        ssh_user = "${var.bastion_ssh_user}"
        icp_image_registry_username = "${var.icp_image_registry_username}"
        icp_image_registry_password = "${var.icp_image_registry_password}"
    }
    depends_on = [
        "null_resource.dependency",
    ]
}

resource "null_resource" "install_docker" {
    connection {
      type = "ssh"

      host = "${local.bastion_ip}"
      user = "${var.bastion_ssh_user}"
      password = "${var.bastion_ssh_password}"
      private_key = "${var.bastion_ssh_private_key}"
    }

    provisioner "remote-exec" {
        inline = [
            "sudo yum -y install docker",
            "sudo systemctl start docker"
        ]
    }

    depends_on = [
      "null_resource.dependency",
    ]
}

resource "null_resource" "openshift_client" {
  depends_on = [
    "null_resource.dependency",
  ]

  connection {
    type        = "ssh"

    host = "${local.bastion_ip}"
    user = "${var.bastion_ssh_user}"
    password = "${var.bastion_ssh_password}"
    private_key = "${var.bastion_ssh_private_key}"
  }

  provisioner "remote-exec" {
    inline = [
      "set -e",
      "wget -r -l1 -np -nd https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/ -P /tmp -A 'openshift-client-linux-4*.tar.gz'",
      "sudo tar zxvf /tmp/openshift-client-linux-4*.tar.gz -C /usr/local/bin",
    ]
  }
}

resource "null_resource" "setup_installicp" {
    connection {
      type = "ssh"

      host = "${local.bastion_ip}"
      user = "${var.bastion_ssh_user}"
      password = "${var.bastion_ssh_password}"
      private_key = "${var.bastion_ssh_private_key}"
    }

    provisioner "file" {
      content = "${data.template_file.setup_icpinstall.rendered}"
      destination = "/tmp/setup_icpinstall.sh"
    }

    provisioner "remote-exec" {
        inline = [
            "sudo chmod +x /tmp/setup_icpinstall.sh",
            "sudo /tmp/setup_icpinstall.sh"
        ]
    }

    depends_on = [
        "null_resource.dependency",
        "null_resource.install_docker",
        "null_resource.openshift_client"
    ]
}

resource "null_resource" "write_config_yaml" {
    triggers = {
        config_yaml = "${data.template_file.config_yaml.rendered}"
    }

    connection {
      type = "ssh"

      host = "${local.bastion_ip}"
      user = "${var.bastion_ssh_user}"
      password = "${var.bastion_ssh_password}"
      private_key = "${var.bastion_ssh_private_key}"
    }

    provisioner "file" {
      content = "${data.template_file.config_yaml.rendered}"
      destination = "${var.icp_install_path}/cluster/config.yaml"
    }

    depends_on = [
        "null_resource.dependency",
        "null_resource.setup_installicp",
    ]
}

resource "null_resource" "copy_inventory_file" {
    triggers = {
        inventory = "${var.openshift_inventory}"
    }

    connection {
      type        = "ssh"

      host = "${local.bastion_ip}"
      user = "${var.bastion_ssh_user}"
      password = "${var.bastion_ssh_password}"
      private_key = "${var.bastion_ssh_private_key}"
    }

    provisioner "file" {
        when = "create"
        content     = "${var.openshift_inventory}"
        destination = "${var.icp_install_path}/cluster/hosts"
    }

    depends_on = [
        "null_resource.dependency",
        "null_resource.setup_installicp",
    ]
}

resource "null_resource" "kubeconfig_gen" {
  # TODO if passed in, then we can skip
  triggers = {
    inventory = "${var.openshift_inventory}"
    openshift_admin = "${var.openshift_admin_user}"
    openshift_password = "${var.openshift_admin_password}"
    config_yaml = "${data.template_file.config_yaml.rendered}"
  }

  connection {
    type        = "ssh"

    host = "${local.bastion_ip}"
    user = "${var.bastion_ssh_user}"
    password = "${var.bastion_ssh_password}"
    private_key = "${var.bastion_ssh_private_key}"
  }

  provisioner "remote-exec" {
    inline = [
      "export KUBECONFIG=${var.icp_install_path}/cluster/kubeconfig",
      "/usr/local/bin/oc login --insecure-skip-tls-verify ${var.openshift_url} -u ${var.openshift_admin_user} -p ${var.openshift_admin_password}"
    ]
  }

  depends_on = [
      "null_resource.dependency",
      "null_resource.setup_installicp",
  ]
}

data "template_file" "installicp" {
    template = "${file("${path.module}/templates/installicp.sh.tpl")}"
    vars = {
        icp_install_path = "${var.icp_install_path}"
    }
}

resource "null_resource" "worker_sysctl" {
    count = "${var.worker_count}"
    connection {
      type = "ssh"

      host = "${local.bastion_ip}"
      user = "${var.bastion_ssh_user}"
      password = "${var.bastion_ssh_password}"
      private_key = "${var.bastion_ssh_private_key}"
    }

    provisioner "remote-exec" {
        inline = [
            "sudo sysctl -w vm.max_map_count=262144",
            "echo vm.max_map_count=262144 | sudo tee -a /etc/sysctl.conf"
        ]
    }
    depends_on = [
        "null_resource.dependency",
    ]
}

resource "null_resource" "wait_for_scc" {
    triggers = {
        inventory = "${var.openshift_inventory}"
        config_yaml = "${data.template_file.config_yaml.rendered}"
    }

    connection {
      type = "ssh"

      host = "${local.bastion_ip}"
      user = "${var.bastion_ssh_user}"
      password = "${var.bastion_ssh_password}"
      private_key = "${var.bastion_ssh_private_key}"
    }

    provisioner "remote-exec" {
        inline = [
          "while ! /usr/local/bin/oc --config=${var.icp_install_path}/cluster/kubeconfig get scc icp-scc; do sleep 5; done",
          "kubectl --kubeconfig=${var.icp_install_path}/cluster/kubeconfig patch scc icp-scc -p '{\"allowPrivilegedContainer\": true}'",
        ]
    }

    depends_on = [
      "null_resource.dependency",
      "null_resource.write_config_yaml",
      "null_resource.setup_installicp",
      "null_resource.copy_inventory_file",
      "null_resource.worker_sysctl",
      "null_resource.kubeconfig_gen",
    ]
}

resource "null_resource" "installicp" {
    triggers = {
        inventory = "${var.openshift_inventory}"
        config_yaml = "${data.template_file.config_yaml.rendered}"
    }

    connection {
      type = "ssh"

      host = "${local.bastion_ip}"
      user = "${var.bastion_ssh_user}"
      password = "${var.bastion_ssh_password}"
      private_key = "${var.bastion_ssh_private_key}"
    }

    provisioner "file" {
      content = "${data.template_file.installicp.rendered}"
      destination = "/tmp/installicp.sh"
    }

    provisioner "remote-exec" {
      inline = [
        "chmod +x /tmp/installicp.sh",
        "sudo /tmp/installicp.sh",
      ]
    }

    depends_on = [
      "null_resource.dependency",
      "null_resource.write_config_yaml",
      "null_resource.setup_installicp",
      "null_resource.copy_inventory_file",
      "null_resource.worker_sysctl",
      "null_resource.kubeconfig_gen",
    ]
}
