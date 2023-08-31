# This file was autogenerated by the 'packer hcl2_upgrade' command. We
# recommend double checking that everything is correct before going forward. We
# also recommend treating this file as disposable. The HCL2 blocks in this
# file can be moved to other files. For example, the variable blocks could be
# moved to their own 'variables.pkr.hcl' file, etc. Those files need to be
# suffixed with '.pkr.hcl' to be visible to Packer. To use multiple files at
# once they also need to be in the same folder. 'packer inspect folder/'
# will describe to you what is in that folder.

# Avoid mixing go templating calls ( for example ```{{ upper(`string`) }}``` )
# and HCL2 calls (for example '${ var.string_value_example }' ). They won't be
# executed together and the outcome will be unknown.

# See https://www.packer.io/docs/templates/hcl_templates/blocks/packer for more info
packer {
  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = "~> 1"
    }
    ansible = {
      source  = "github.com/hashicorp/ansible"
      version = "~> 1"
    }
  }
}

# All generated input variables will be of 'string' type as this is how Packer JSON
# views them; you can change their type later on. Read the variables type
# constraints documentation
# https://www.packer.io/docs/templates/hcl_templates/variables#type-constraints for more info.
variable "access_key" {
  type      = string
  default   = "${env("AWS_ACCESS_KEY_ID")}"
  sensitive = true
}

variable "drone_build_number" {
  type    = string
  default = "${env("DRONE_BUILD_NUMBER")}"
}

variable "secret_key" {
  type      = string
  default   = "${env("AWS_SECRET_ACCESS_KEY")}"
  sensitive = true
}

# The amazon-ami data block is generated from your amazon builder source_ami_filter; a data
# from this block can be referenced in source and locals blocks.
# Read the documentation for data blocks here:
# https://www.packer.io/docs/templates/hcl_templates/blocks/data
# Read the documentation for the Amazon AMI Data Source here:
# https://www.packer.io/plugins/datasources/amazon/ami
data "amazon-ami" "autogenerated_1" {
  access_key = "${var.access_key}"
  filters = {
    name                = "EC2LaunchV2-Windows_Server-2019-English-Full-Base-*"
    virtualization-type = "hvm"
  }
  most_recent = true
  owners      = ["801119661308"]
  region      = "eu-west-2"
  secret_key  = "${var.secret_key}"
}

# source blocks are generated from your builders; a source can be referenced in
# build blocks. A build block runs provisioner and post-processors on a
# source. Read the documentation for source blocks here:
# https://www.packer.io/docs/templates/hcl_templates/blocks/source
source "amazon-ebs" "autogenerated_1" {
  access_key           = "${var.access_key}"
  ami_name             = "dq-ops-win-bastion-${var.drone_build_number}"
  ami_users            = ["483846886818", "337779336338"]
  communicator         = "winrm"
  iam_instance_profile = "packer_builder"
  instance_type        = "t3.xlarge"
  launch_block_device_mappings {
    delete_on_termination = true
    device_name           = "/dev/sda1"
    volume_size           = 200
    volume_type           = "gp2"
  }
  imds_support         = "v2.0"
  metadata_options = {
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 1
    http_tokens                 = "required"
  }
  region         = "eu-west-2"
  secret_key     = "${var.secret_key}"
  source_ami     = "${data.amazon-ami.autogenerated_1.id}"
  user_data_file = "./scripts/setupwrm.ps1"
  winrm_insecure = true
  winrm_port     = 5986
  winrm_use_ssl  = true
  winrm_username = "Administrator"
}

# a build block invokes sources and runs provisioning steps on them. The
# documentation for build blocks can be found here:
# https://www.packer.io/docs/templates/hcl_templates/blocks/build
build {
  sources = ["source.amazon-ebs.autogenerated_1"]

  provisioner "ansible" {
    ansible_env_vars = ["ANSIBLE_HOST_KEY_CHECKING=False", "ANSIBLE_SSH_ARGS='-o ControlMaster=auto -o ControlPersist=60s -o ControlPath=/dev/shm/cp%%h-%%p-%%r'", "ANSIBLE_NOCOLOR=True", "ANSIBLE_TIMEOUT=30"]
    extra_arguments  = ["-e", "ansible_winrm_server_cert_validation=ignore", "--extra-vars", "ansible_shell_type=powershell ansible_shell_executable=None", "--ssh-extra-args", "-o IdentitiesOnly=yes -o 'HostKeyAlgorithms=+ssh-rsa' -o 'PubkeyAcceptedAlgorithms=+ssh-rsa'"]
    playbook_file    = "./playbook.yml"
    use_proxy        = false
    user             = "Administrator"
  }

  provisioner "powershell" {
    scripts = ["./scripts/disable-esc-and-uac.ps1"]
  }

  provisioner "powershell" {
    inline = ["Set-Location $env:programfiles/amazon/ec2launch", "./ec2launch.exe reset --clean --block", "./ec2launch.exe sysprep --clean --block"]
  }

}
