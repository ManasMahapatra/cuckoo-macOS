# Mac-OS Guest-VM for Cuckoo Sandbox on Linux Host
Cuckoo Sandbox needs target Operating Systems loaded in Virtual Machines to initiate dynamic analysis over binaries. However, loading up VM with mac OS in it is not as straightforward as other Linux or Windows machines, because of mainly Hardware differences. This guide is to set it up in a Linux Host machine and provide a step by step guide to bootstrap it for cuckoo.

This script is based on [macos-guest-virtualbox](https://github.com/img2tab/macos-guest-virtualbox).


## Dependencies
Please resolve the following dependencies, before executing the script:
* VirtualBox≥5.2 with Extension Pack (```sudo apt-get install virtualbox-6.0```) 
* Coreutils, Unzip and wGet (```sudo apt-get install coreutils wget unzip -y```)
* dmg2img (```sudo apt-get install dmg2img -y```)

## Usage

Resolve the above mentioned dependencies, and you're good to go. Make sure you have at least 37 GB of free space for installing the virtual machine. All cleared get started by ```./setup-guest.sh```.

The script is responsible for fetching the latest version of mac-OS Mojave and install it, however, when the VM starts booting up the image, a terminal session will initiate, and the bash-script will ask you to press enter when the terminal prompts. **Be very careful while pressing enter. Be patient, and let the terminal prompt show up, and only then press for continuing**. The installation files to be fetched are significantly large, so it's recommended to have a solid internet speed before initiating the process. However, if for some reason your internet disrupts and you lose progress, enter ```./setup-guest.sh stages``` to list out the stages, identify the last stage you were on, and then ```./setup-guest.sh stages [guest_name(s)]``` to either run one module or multiple consecutively. Always keep an eye on your own terminal and carefully follow the instructions.

The script alone will setup most of the things, however as of now, you have to change the Network mode from NAT to Host-Only Adapter or Bridged. Then setup static IP (don't forget to configure DNS or the machine cant access webpages ;) and finally take the snapshot and add it to your Cuckoo configuration files. The final steps would be automated shortly.   

