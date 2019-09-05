output "module_completed" {
    value = "${join(",", list(null_resource.installicp.id))}"
}
