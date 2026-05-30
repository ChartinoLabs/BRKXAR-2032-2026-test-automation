module "iosxe" {
  source  = "git::https://github.com/netascode/terraform-iosxe-nac-iosxe.git?ref=main"

  # This tells the module to look for YAML files in the 'data/' subdirectory.
  yaml_directories = ["./data"]
}
