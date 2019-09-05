resource "null_resource" "dependency" {
  triggers = {
    all_dependencies = "${join(",", var.dependson)}"
  }
}

data "template_file" "config_yaml" {
  template = "${file("${path.module}/templates/config.yaml.tpl")}"

  vars = {
    workerlist         = "${join("\n", formatlist("    - %v", var.worker_hostname))}"
    app_subdomain      = "${var.app_subdomain}"
    storage_class      = "${var.storage_class}"
    icp_admin_password = "${var.icp_admin_password}"
    installmcm         = "${var.installmcm}"
  }
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
    }
    depends_on = [
        "null_resource.dependency",
    ]
}

resource "null_resource" "setup_installicp" {
    connection {
      type = "ssh"
      host = "${element(var.master_ip_address, 0)}"
      user = "${var.bastion_ssh_user}"
      password = "${var.bastion_ssh_password}"
      bastion_host = "${var.bastion_ip_address}"
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
    ]
}

resource "null_resource" "write_config_yaml" {
    connection {
      type = "ssh"
      host = "${element(var.master_ip_address, 0)}"
      user = "${var.bastion_ssh_user}"
      password = "${var.bastion_ssh_password}"
      bastion_host = "${var.bastion_ip_address}"
      private_key = "${var.bastion_ssh_private_key}"
    }

    provisioner "file" {
      content = "${data.template_file.config_yaml.rendered}"
      destination = "${var.icp_install_path}/cluster/config.yaml"
    }

    provisioner "file" {
      content = "${var.bastion_ssh_private_key}"
      destination = "${var.icp_install_path}/cluster/ssh_key"
    }

    depends_on = [
        "null_resource.dependency",
        "null_resource.setup_installicp",
    ]
}

resource "null_resource" "copy_inventory_file" {
    connection {
      type = "ssh"
      host = "${var.bastion_ip_address}"
      user = "${var.bastion_ssh_user}"
      password = "${var.bastion_ssh_password}"
      private_key = "${var.bastion_ssh_private_key}"
    }

    provisioner "remote-exec" {
        inline = [
            "scp ~/inventory.cfg ${element(var.master_ip_address, 0)}:${var.icp_install_path}/cluster/hosts"
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
    depends_on = [
        "null_resource.dependency",
    ]
}

resource "null_resource" "worker_sysctl" {
    count = "${var.worker["nodes"]}"
    connection {
      type = "ssh"
      host = "${element(var.worker_ip_address, count.index)}"
      user = "${var.bastion_ssh_user}"
      password = "${var.bastion_ssh_password}"
      bastion_host = "${var.bastion_ip_address}"
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

resource "null_resource" "installicp" {
    connection {
      type = "ssh"
      host = "${element(var.master_ip_address, 0)}"
      user = "${var.bastion_ssh_user}"
      password = "${var.bastion_ssh_password}"
      bastion_host = "${var.bastion_ip_address}"
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
    ]
}
