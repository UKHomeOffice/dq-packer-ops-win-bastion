# dq-packer-ops-win-bastion
This AMI is used as a bastion/jump box and has got various tools installed required to manage various services within the DQ environment.

## Features

### `packer.json`
Packer creates an AMI based on a vanilla AWS Windows Server 2019 image (with EC2Launch v2 - the latest version at present).
Packer uses Ansible to configure (provision) the target machine.
Ansible connects without proxy (the approach currently recommended by Hashicorp).
Ansible connects to Windows Remote Manager (WinRM) on the target machine.
Packer uses Powershell to further configure and Sysprep the target machine (to allow it to be reused to spin up other machines).
Modified to create new administrator with name of dqsupport and disable administrator user as normal user

### `playbook.yml`
Ansible playbook installing the following:
- PSTools
- Chocolatey package manager
- Python2.7
- Python3.9
- VSCode
- DBeaver
- Google Chrome
- Putty
- AWS CLI
- AWS Toolkit for Powershell
- PGAdmin4
- Notepad++
- Microsoft SQL Management Studio

### `connection_plugins` (Removed)
Hashicorp now recommends _directly_ connecting Packer (with the WinRM Communicator) from the Control Node (Drone) to the Target Node being configured (Packer Builder EC2 Instance) rather than via the Communicator proxy provided by the connection plugin. <br>
If the proxy is to be used the latest version of `packer.py` must be downloaded from https://github.com/ansible/ansible/blob/devel/lib/ansible/plugins/connection/ssh.py


#### `scripts`
- `disable-esc-and-iac.ps1` turn off annoying Windows pop-ups (Internet Explorer Enhanced Security Configuration)
- `born-in-the-UK.ps1` helper script for end users to run - to configure their account settings to UK/British (not default US/USA)
- `monitor_stopped_win_services.ps1` checks if there are any service in the *stopped* state where they are set to *automatic* startup
- `setupwrm.ps1` enable WRM service so packer can interact with the instance
- `sysprep-bundleconfig.ps1` turn on sysprep using a custom xml config file
- `sysprep-ec2config.ps1` add EC2 specific sysprep values

## Deploying / Publishing
Drone is needed to deploy with `.drone.yml` file

## Contributing

If you'd like to contribute, please fork the repository and use a feature
branch. Pull requests are warmly welcome.

More information in [`CONTRIBUTING`](./CONTRIBUTING)

## Licensing
The code in this project is licensed under this [`LICENSE`](./LICENSE)
