#!/bin/bash
# Semi-automatic installer of macOS on VirtualBox
# (c) myspaghetti, licensed under GPL2.0 or higher
# url: https://github.com/img2tab/macos-guest-virtualbox
# version 0.71.4

# Requirements: 40GB available storage on host
# Dependencies: bash >= 4.0, unzip, wget, dmg2img,
#               VirtualBox with Extension Pack >= 5.2.2

# Customize the installation by setting these variables:
vmname="macOS"                   # name of the VirtualBox virtual machine
storagesize=22000                # VM disk image size in MB. minimum 22000
cpucount=2                       # VM CPU cores, minimum 2
memorysize=4096                  # VM RAM in MB, minimum 2048
gpuvram=128                      # VM video RAM in MB, minimum 34, maximum 128
resolution="1280x800"            # VM display resolution

# The following commented commands may provide the values for the parameters
# required by iCloud, iMessage, and other connected Apple applications.
# Parameters taken from a genuine Mac will result in a "Call customer support"
# message because one required parameter, 'system-id' (UUID), is still not
# being passed to the virtual machine. That said, non-genuine parameters work.

# system_profiler SPHardwareDataType
DmiSystemFamily="MacBook Pro"        # Model Name
DmiSystemProduct="MacBookPro11,2"    # Model Identifier
DmiSystemSerial="NO_DEVICE_SN"       # Serial Number (system)
DmiSystemUuid="CAFECAFE-CAFE-CAFE-CAFE-DECAFFDECAFF" # Hardware UUID
DmiOEMVBoxVer="string:1"             # Apple ROM Info
DmiOEMVBoxRev="string:.23456"        # Apple ROM Info
DmiBIOSVersion="string:MBP7.89"      # Boot ROM Version
# ioreg -l | grep -m 1 board-id
DmiBoardProduct="Mac-3CBD00234E554E41"
# nvram 4D1EDE05-38C7-4A6A-9CC6-4BCCA8B38C14:MLB | awk '{ print $NF }'
DmiBoardSerial="NO_LOGIC_BOARD_SN"
MLB="bytes:$(echo -n "${DmiBoardSerial}" | base64)"
# nvram 4D1EDE05-38C7-4A6A-9CC6-4BCCA8B38C14:ROM | awk '{ print $NF }'
ROM='%aa*%bbg%cc%dd'
# ioreg -l -p IODeviceTree | grep \"system-id
UUID="aabbccddeeff00112233445566778899"
# The if statement below converts the Mac output into VBox-readable values
# This is only necessary if you want to run connected Apple applications
# such as iCloud, iMessage, etc.
# Make sure the package xxd is installed, otherwise the conversion will fail.
if [ -n "$(echo -n "aabbccddee" | xxd -r -p 2>/dev/null)" ]; then
    # Apologies for the one-liner below; it convers the mixed-ASCII-and-base16
    # ROM value above into an ASCII string that represents a base16 number.
    ROM_b16="$(for (( i=0; i<${#ROM}; )); do let j=i+1; if [ "${ROM:${i}:1}" == "%" ]; then echo -n "${ROM:${j}:2}"; let i=i+3; else x="$(echo -n "${ROM:${i}:1}" | od -t x1 -An | tr -d ' ')"; echo -n "${x}"; let i=i+1; fi; done)"
    ROM_b64="$(echo -n "${ROM_b16}" | xxd -r -p | base64)"
    ROM="bytes:${ROM_b64}"
    UUID_b64="$(echo -n "${UUID}" | xxd -r -p | base64)"
    UUID="bytes:${UUID_b64}"
else
    ROM="bytes:qiq7Z8zd"                  # base64 of the example ROM
    UUID="bytes:qrvM3e7/ABEiM0RVZneImQ==" # base64 of the example UUID
fi

# welcome message
white_on_red="\e[48;2;255;0;0m\e[38;2;255;255;255m"
white_on_black="\e[48;2;0;0;9m\e[38;2;255;255;255m"
default_color="\033[0m"

function welcome() {
printf '
Semi-automatic installer script for configuring Cuckoo Sandbox for macOS machines
-------------------------------------------------------------------------------

This script installs only open-source software and unmodified Apple binaries.

The script checks for dependencies and will prompt to install them if unmet.
Some stages may fail due to errant keyboard presses; run the script with
"'${white_on_black}"${0}"' stages'${default_color}'" to see how to run only certain stages.

For iCloud and iMessage connectivity, the script needs to be edited with genuine or genuine-like
Apple parameters. macOS will work without these parameters, but not Apple-connected apps.

The installation requires about '${white_on_red}'40GB'${default_color}' of available storage, 25GB for
temporary installation files and 15GB for the virtual machine. Deleting the
temporary files when prompted reduces the storage requirement by about 10GB.

'${white_on_black}'Press enter to review the script settings.'${default_color}
read

# custom settings prompt
printf '
vmname="'"${vmname}"'"             # name of the VirtualBox virtual machine
storagesize='"${storagesize}"'          # VM disk image size in MB. minimum 22000
cpucount='"${cpucount}"'                 # VM CPU cores, minimum 2
memorysize='"${memorysize}"'            # VM RAM in MB, minimum 2048
gpuvram='"${gpuvram}"'                # VM video RAM in MB, minimum 34, maximum 128
resolution="'"${resolution}"'"      # VM display resolution

These values may be customized by editing them at the top of the script file.

'${white_on_black}'Press enter to continue, CTRL-C to exit.'${default_color}
read
}

# check dependencies
function check_dependencies() {
# check if running on macOS
if [ -n "$(sw_vers 2>/dev/null)" ]; then
    printf '\nThis script is not tested on macOS hosts. Exiting.\n'
    exit
fi

# check Bash version
if [ -z "${BASH_VERSION}" ]; then
    echo "Can't determine BASH_VERSION. Exiting."
    exit
elif [ "${BASH_VERSION:0:1}" -lt 4 ]; then
    echo "Please run this script on BASH 4.0 or higher."
    exit
fi

# check for unzip, coreutils, wget
if [ -z "$(unzip -hh 2>/dev/null)" \
     -o -z "$(head --version 2>/dev/null)" \
     -o -z "$(wget --version 2>/dev/null)" ]; then
    echo "Please make sure the following packages are installed:"
    echo "coreutils   unzip   wget"
    exit
fi

# wget supports --show-progress from version 1.16
if [[ "$(wget --version 2>/dev/null | head -n 1)" =~ 1\.1[6-9]|1\.2[0-9] ]]; then
    wgetargs="--quiet --continue --show-progress"  # pretty
else
    wgetargs="--continue"  # ugly
fi

# VirtualBox in ${PATH}
# Cygwin
if [ -n "$(cygcheck -V 2>/dev/null)" ]; then
    if [ -n "$(cmd.exe /d /s /c call VBoxManage.exe -v 2>/dev/null)" ]; then
        function VBoxManage() {
            cmd.exe /d /s /c call VBoxManage.exe "$@"
        }
    else
        cmd_path_VBoxManage='C:\Program Files\Oracle\VirtualBox\VBoxManage.exe'
        echo "Can't find VBoxManage in PATH variable,"
        echo "checking ${cmd_path_VBoxManage}"
        if [ -n "$(cmd.exe /d /s /c call "${cmd_path_VBoxManage}" -v 2>/dev/null)" ]; then
            function VBoxManage() {
                cmd.exe /d /s /c call "${cmd_path_VBoxManage}" "$@"
            }
            echo "Found VBoxManage"
        else
            echo "Please make sure VirtualBox version 5.2.2 or higher is installed, and that"
            echo "the path to the VBoxManage.exe executable is in the PATH variable, or assign"
            echo "in the script the full path including the name of the executable to"
            printf 'the variable '"${white_on_black}"'cmd_path_VBoxManage'"${default_color}"
            exit
        fi
    fi
# Windows Subsystem for Linux (WSL)
elif [[ "$(cat /proc/sys/kernel/osrelease 2>/dev/null)" =~ Microsoft ]]; then
    if [ -n "$(VBoxManage.exe -v 2>/dev/null)" ]; then
        function VBoxManage() {
            VBoxManage.exe "$@"
        }
    else
        wsl_path_VBoxManage='/mnt/c/Program Files/Oracle/VirtualBox/VBoxManage.exe'
        echo "Can't find VBoxManage in PATH variable,"
        echo "checking ${wsl_path_VBoxManage}"
        if [ -n "$("${wsl_path_VBoxManage}" -v 2>/dev/null)" ]; then
            function VBoxManage() {
                "${wsl_path_VBoxManage}" "$@"
            }
            echo "Found VBoxManage"
        else
            echo "Please make sure VirtualBox is installed on Windows, and that the path to the"
            echo "VBoxManage.exe executable is in the PATH variable, or assigned in the script"
            printf 'to the variable '${white_on_black}'wsl_path_VBoxManage'${default_color}' including the name of the executable.'
            exit
        fi
    fi
# everything else (not cygwin and not wsl)
elif [ -z "$(VBoxManage -v 2>/dev/null)" ]; then
    echo "Please make sure VirtualBox version 5.2.2 or higher is installed,"
    echo "and that the path to the VBoxManage executable is in the PATH variable."
    exit
fi

# VirtualBox version
vbox_version="$(VBoxManage -v 2>/dev/null)"
if [ -z "${vbox_version}" ]; then
    echo "Can't determine VirtualBox version. Exiting."
    exit
elif [[ ! ${vbox_version:0:1} == 6 && ! "${vbox_version:0:6}" =~ 5\.2\.1[0-9] && ! "${vbox_version:0:5}" =~ 5\.2\.[2-9] && ! "${vbox_version:0:3}" =~ 5\.[3-9] ]]; then
    echo "Please make sure VirtualBox version 5.2.2 or higher is installed."
    exit
fi

# Oracle VM VirtualBox Extension Pack
extpacks="$(VBoxManage list extpacks 2>/dev/null)"
if [ "$(expr match "${extpacks}" '.*Oracle VM VirtualBox Extension Pack')" -le "0" \
    -o "$(expr match "${extpacks}" '.*Usable:[[:blank:]]*false')" -gt "0" ]; then
    echo "Please make sure Oracle VM VirtualBox Extension Pack is installed, and that"
    echo "all installed VirtualBox extensions are listed as usable in \"VBoxManage list extpacks\""
    exit
fi

# dmg2img
if [ -z "$(dmg2img -d 2>/dev/null)" ]; then
    if [ -z "$(cygcheck -V 2>/dev/null)" ]; then
        echo "Please install the package dmg2img."
        exit
    elif [ -z "$(${PWD}/dmg2img -d 2>/dev/null)" ]; then
        echo "Locally installing dmg2img"
        wget "http://vu1tur.eu.org/tools/dmg2img-1.6.6-win32.zip" \
             ${wgetargs} \
             --output-document="dmg2img-1.6.6-win32.zip"
        if [ ! -s dmg2img-1.6.6-win32.zip ]; then
             echo "Error downloading dmg2img. Please provide the package manually."
             exit
        fi
        unzip -oj "dmg2img-1.6.6-win32.zip" "dmg2img.exe"
        rm "dmg2img-1.6.6-win32.zip"
        chmod +x "dmg2img.exe"
    fi
fi

# prompt for macOS version
HighSierra_sucatalog='https://swscan.apple.com/content/catalogs/others/index-10.13-10.12-10.11-10.10-10.9-mountainlion-lion-snowleopard-leopard.merged-1.sucatalog'
Mojave_sucatalog='https://swscan.apple.com/content/catalogs/others/index-10.14-10.13-10.12-10.11-10.10-10.9-mountainlion-lion-snowleopard-leopard.merged-1.sucatalog'
Catalina_beta_sucatalog='https://swscan.apple.com/content/catalogs/others/index-10.15seed-10.15-10.14-10.13-10.12-10.11-10.10-10.9-mountainlion-lion-snowleopard-leopard.merged-1.sucatalog'
# Catalina public release not yet available
# Catalina_sucatalog='https://swscan.apple.com/content/catalogs/others/index-10.15-10.14-10.13-10.12-10.11-10.10-10.9-mountainlion-lion-snowleopard-leopard.merged-1.sucatalog'
printf "${white_on_black}"'
Press a key to select the macOS version to install on the virtual machine:'"${default_color}"'
 [H]igh Sierra (10.13)
 [M]ojave (10.14)
 [C]atalina (10.15 beta)

'
read -n 1 -p " [H/M/C] " macOS_release_name 2>/dev/tty
echo ""
if [ "${macOS_release_name^^}" == "H" ]; then
    macOS_release_name="HighSierra"
    CFBundleShortVersionString="10.13"
    sucatalog="${HighSierra_sucatalog}"
elif [ "${macOS_release_name^^}" == "M" ]; then
    macOS_release_name="Mojave"
    CFBundleShortVersionString="10.14"
    sucatalog="${Mojave_sucatalog}"
else
    macOS_release_name="Catalina"
    CFBundleShortVersionString="10.15"
    sucatalog="${Catalina_beta_sucatalog}"
fi
echo "${macOS_release_name} selected"
}
# Done with dependencies

function prompt_delete_existing_vm() {
if [ -n "$(VBoxManage showvminfo "${vmname}" 2>/dev/null)" ]; then
    printf '\n"'"${vmname}"'" virtual machine already exists.
'${white_on_red}'Delete existing virtual machine "'"${vmname}"'"?'${default_color}
    delete=""
    read -n 1 -p " [y/n] " delete 2>/dev/tty
    echo ""
    if [ "${delete,,}" == "y" ]; then
        VBoxManage unregistervm "${vmname}" --delete
    else
        printf '
'"${white_on_black}"'Please assign a different VM name to variable "vmname" by editing the script,'"${default_color}"'
or skip this check manually as described in "'"${0}"' stages".\n'
        exit
    fi
fi
}

# Attempt to create new virtual machine named "${vmname}"
function create_vm() {
if [ -n "$(VBoxManage createvm --name "${vmname}" --ostype "MacOS1013_64" --register 2>&1 1>/dev/null)" ]; then
    printf '\nError: Could not create virtual machine "'"${vmname}"'".
'${white_on_black}'Please delete exising "'"${vmname}"'" VirtualBox configuration files '${white_on_red}'manually'${default_color}'.

Error message:
'
    VBoxManage createvm --name "${vmname}" --ostype "MacOS1013_64" --register 2>/dev/tty
    exit
fi
}

function prepare_macos_installation_files() {
# Find the correct download URL in the Apple catalog
echo ""
echo "Downloading Apple macOS ${macOS_release_name} software update catalog"
wget "${sucatalog}" \
     ${wgetargs} \
     --output-document="${macOS_release_name}_sucatalog"

# if file was not downloaded correctly
if [ ! -s "${macOS_release_name}_sucatalog" ]; then
    wget --debug -O /dev/null -o "${macOS_release_name}_wget.log" "${sucatalog}"
    echo ""
    echo "Couldn't download the Apple software update catalog."
    if [ "$(expr match "$(cat "${macOS_release_name}_wget.log")" '.*ERROR[[:print:]]*is not trusted')" -gt "0" ]; then
        printf '
Make sure certificates from a certificate authority are installed.
Certificates are often installed through the package manager with
a package named '"${white_on_black}"'ca-certificates'"${default_color}"
    fi
    echo "Exiting."
    exit
fi
echo "Trying to find macOS ${macOS_release_name} InstallAssistant download URL"
tac "${macOS_release_name}_sucatalog" | csplit - '/InstallAssistantAuto.smd/+1' '{*}' -f "${macOS_release_name}_sucatalog_" -s
for catalog in "${macOS_release_name}_sucatalog_"* "error"; do
    if [[ "${catalog}" == error ]]; then
        rm "${macOS_release_name}_sucatalog"*
        printf "Couldn't find the requested download URL in the Apple catalog. Exiting."
       exit
    fi
    urlbase="$(tail -n 1 "${catalog}" 2>/dev/null)"
    urlbase="$(expr match "${urlbase}" '.*\(http://[^<]*/\)')"
    wget "${urlbase}InstallAssistantAuto.smd" \
    ${wgetargs} \
    --output-document="${catalog}_InstallAssistantAuto.smd"
    found_version="$(head -n 6 "${catalog}_InstallAssistantAuto.smd" | tail -n 1)"
    if [[ "${found_version}" == *${CFBundleShortVersionString}* ]]; then
        echo "Found download URL: ${urlbase}"
        echo ""
        rm "${macOS_release_name}_sucatalog"*
        break
    fi
done
echo "Downloading macOS installation files from swcdn.apple.com"
for filename in "BaseSystem.chunklist" \
                "InstallInfo.plist" \
                "AppleDiagnostics.dmg" \
                "AppleDiagnostics.chunklist" \
                "BaseSystem.dmg" \
                "InstallESDDmg.pkg"; \
    do wget "${urlbase}${filename}" \
            ${wgetargs} \
            --output-document "${macOS_release_name}_${filename}"
done
echo ""
echo "Downloading open-source APFS EFI drivers"
wget 'https://github.com/acidanthera/AppleSupportPkg/releases/download/2.0.4/AppleSupport-v2.0.4-RELEASE.zip' \
    ${wgetargs} \
    --output-document 'AppleSupport-v2.0.4-RELEASE.zip'
unzip -oj 'AppleSupport-v2.0.4-RELEASE.zip'
echo ""
echo "Creating EFI startup script"
echo 'echo -off
load fs0:\EFI\driver\AppleImageLoader.efi
load fs0:\EFI\driver\AppleUiSupport.efi
load fs0:\EFI\driver\ApfsDriverLoader.efi
map -r
for %a run (1 5)
  fs%a:
  cd "macOS Install Data\Locked Files\Boot Files"
  boot.efi
  cd "System\Library\CoreServices"
  boot.efi
endfor' > "startup.nsh"
}

function create_macos_installation_files_viso() {
echo "Crating VirtualBox 6 virtual ISO containing the"
echo "installation files from swcdn.apple.com"
echo ""
echo "Splitting the several-GB InstallESDDmg.pkg into 1GB parts because"
echo "VirtualBox hasn't implemented UDF/HFS VISO support yet and macOS"
echo "doesn't support ISO 9660 Level 3 with files larger than 2GB."
split -a 2 -d -b 1000000000 "${macOS_release_name}_InstallESDDmg.pkg" "${macOS_release_name}_InstallESD.part"
echo "--iprt-iso-maker-file-marker-bourne-sh 57c0ec7d-2112-4c24-a93f-32e6f08702b9
--volume-id=${macOS_release_name:0:5}-files
/AppleDiagnostics.chunklist=${macOS_release_name}_AppleDiagnostics.chunklist
/AppleDiagnostics.dmg=${macOS_release_name}_AppleDiagnostics.dmg
/BaseSystem.chunklist=${macOS_release_name}_BaseSystem.chunklist
/BaseSystem.dmg=${macOS_release_name}_BaseSystem.dmg
/InstallInfo.plist=${macOS_release_name}_InstallInfo.plist
/ApfsDriverLoader.efi=ApfsDriverLoader.efi
/AppleImageLoader.efi=AppleImageLoader.efi
/AppleUiSupport.efi=AppleUiSupport.efi
/startup.nsh=startup.nsh" > "${macOS_release_name}_installation_files.viso"
for part in "${macOS_release_name}_InstallESD.part"*; do
    echo "/InstallESD${part##*InstallESD}=${part}" >> "${macOS_release_name}_installation_files.viso"
done

}

# Create the macOS base system virtual disk image:
function create_basesystem_vdi() {
if [ -s "${macOS_release_name}_BaseSystem.vdi" ]; then
    echo "${macOS_release_name}_BaseSystem.vdi bootstrap virtual disk image ready."
elif [ ! -s "${macOS_release_name}_BaseSystem.dmg" ]; then
    echo ""
    echo "Could not find ${macOS_release_name}_BaseSystem.dmg; exiting."
    exit
else
    echo "Converting to BaseSystem.dmg to BaseSystem.img"
    if [ -n "$("${PWD}/dmg2img.exe" -d 2>/dev/null)" ]; then
        "${PWD}/dmg2img.exe" "${macOS_release_name}_BaseSystem.dmg" "${macOS_release_name}_BaseSystem.img"
    else
        dmg2img "${macOS_release_name}_BaseSystem.dmg" "${macOS_release_name}_BaseSystem.img"
    fi
    VBoxManage convertfromraw --format VDI "${macOS_release_name}_BaseSystem.img" "${macOS_release_name}_BaseSystem.vdi"
    if [ -s "${macOS_release_name}_BaseSystem.vdi" ]; then
        rm "${macOS_release_name}_BaseSystem.img" 2>/dev/null
    fi
fi
}

# Create the target virtual disk image:
function create_target_vdi() {
if [ -w "${vmname}.vdi" ]; then
    echo "${vmname}.vdi target system virtual disk image ready."
elif [ "${storagesize}" -lt 22000 ]; then
    echo "Attempting to install macOS on a disk smaller than 22000MB will fail."
    echo "Please assign a larger virtual disk image size. Exiting."
    exit
else
    echo "Creating ${vmname} target system virtual disk image."
    VBoxManage createmedium --size="${storagesize}" \
                            --filename "${vmname}.vdi" \
                            --variant standard 2>/dev/tty
fi
}

# Create the installation media virtual disk image:
function create_install_vdi() {
if [ -w "Install ${macOS_release_name}.vdi" ]; then
    echo "Installation media virtual disk image ready."
else
    echo "Creating ${macOS_release_name} installation media virtual disk image."
    VBoxManage createmedium --size=12000 \
                            --filename "Install ${macOS_release_name}.vdi" \
                            --variant standard 2>/dev/tty
fi
}

# Attach virtual disk images of the base system, installation, and target
# to the virtual machine
function attach_initial_storage() {
VBoxManage storagectl "${vmname}" --add sata --name SATA --hostiocache on
VBoxManage storageattach "${vmname}" --storagectl SATA --port 0 \
           --type hdd --nonrotational on --medium "${vmname}.vdi"
VBoxManage storageattach "${vmname}" --storagectl SATA --port 1 \
           --type hdd --nonrotational on --medium "Install ${macOS_release_name}.vdi"
VBoxManage storageattach "${vmname}" --storagectl SATA --port 2 \
           --type hdd --nonrotational on --medium "${macOS_release_name}_BaseSystem.vdi"
VBoxManage storageattach "${vmname}" --storagectl SATA --port 3 \
           --type dvddrive --medium "${macOS_release_name}_installation_files.viso"
}

function configure_vm() {
VBoxManage modifyvm "${vmname}" --cpus "${cpucount}" --memory "${memorysize}" \
 --vram "${gpuvram}" --pae on --boot1 dvd --boot2 disk --boot3 none \
 --boot4 none --firmware efi --rtcuseutc on --usbxhci on --chipset ich9 \
 --mouse usbtablet --keyboard usb --audiocontroller hda --audiocodec stac9221

VBoxManage setextradata "${vmname}" \
 "VBoxInternal/Devices/efi/0/Config/DmiSystemFamily" "${DmiSystemFamily}"
VBoxManage setextradata "${vmname}" \
 "VBoxInternal/Devices/efi/0/Config/DmiSystemProduct" "${DmiSystemProduct}"
VBoxManage setextradata "${vmname}" \
 "VBoxInternal/Devices/efi/0/Config/DmiSystemSerial" "${DmiSystemSerial}"
VBoxManage setextradata "${vmname}" \
 "VBoxInternal/Devices/efi/0/Config/DmiSystemUuid" "${DmiSystemUuid}"
VBoxManage setextradata "${vmname}" \
 "VBoxInternal/Devices/efi/0/Config/DmiOEMVBoxVer" "${DmiOEMVBoxVer}"
VBoxManage setextradata "${vmname}" \
 "VBoxInternal/Devices/efi/0/Config/DmiOEMVBoxRev" "${DmiOEMVBoxRev}"
VBoxManage setextradata "${vmname}" \
 "VBoxInternal/Devices/efi/0/Config/DmiBIOSVersion" "${DmiBIOSVersion}"
VBoxManage setextradata "${vmname}" \
 "VBoxInternal/Devices/efi/0/Config/DmiBoardProduct" "${DmiBoardProduct}"
VBoxManage setextradata "${vmname}" \
 "VBoxInternal/Devices/efi/0/Config/DmiBoardSerial" "${DmiBoardSerial}"
VBoxManage setextradata "${vmname}" \
 "VBoxInternal/Devices/efi/0/LUN#0/Config/Vars/0000/Uuid" "4D1EDE05-38C7-4A6A-9CC6-4BCCA8B38C14"
VBoxManage setextradata "${vmname}" \
 "VBoxInternal/Devices/efi/0/LUN#0/Config/Vars/0000/Name" "MLB"
VBoxManage setextradata "${vmname}" \
 "VBoxInternal/Devices/efi/0/LUN#0/Config/Vars/0000/Value" "${MLB}"
VBoxManage setextradata "${vmname}" \
 "VBoxInternal/Devices/efi/0/LUN#0/Config/Vars/0001/Uuid" "4D1EDE05-38C7-4A6A-9CC6-4BCCA8B38C14"
VBoxManage setextradata "${vmname}" \
 "VBoxInternal/Devices/efi/0/LUN#0/Config/Vars/0001/Name" "ROM"
VBoxManage setextradata "${vmname}" \
 "VBoxInternal/Devices/efi/0/LUN#0/Config/Vars/0001/Value" "${ROM}"
VBoxManage setextradata "${vmname}" \
 "VBoxInternal/Devices/efi/0/Config/UUID" "${UUID}"
VBoxManage setextradata "${vmname}" \
 "VBoxInternal/Devices/efi/0/Config/DmiSystemVendor" "Apple Inc."
VBoxManage setextradata "${vmname}" \
 "VBoxInternal/Devices/efi/0/Config/DmiSystemVersion" "1.0"
VBoxManage setextradata "${vmname}" \
 "VBoxInternal/Devices/smc/0/Config/DeviceKey" \
  "ourhardworkbythesewordsguardedpleasedontsteal(c)AppleComputerInc"
VBoxManage setextradata "${vmname}" \
 "VBoxInternal/Devices/smc/0/Config/GetKeyFromRealSMC" 0
VBoxManage setextradata "${vmname}" \
 "VBoxInternal2/EfiGraphicsResolution" "${resolution}"
}

# QWERTY-to-scancode dictionary. Hex scancodes, keydown and keyup event.
# Virtualbox Mac scancodes found here:
# https://wiki.osdev.org/PS/2_Keyboard#Scan_Code_Set_1
# First half of hex code - press, second half - release, unless otherwise specified
declare -A ksc=(
    ["ESC"]="01 81"
    ["1"]="02 82"
    ["2"]="03 83"
    ["3"]="04 84"
    ["4"]="05 85"
    ["5"]="06 86"
    ["6"]="07 87"
    ["7"]="08 88"
    ["8"]="09 89"
    ["9"]="0A 8A"
    ["0"]="0B 8B"
    ["-"]="0C 8C"
    ["="]="0D 8D"
    ["BKSP"]="0E 8E"
    ["TAB"]="0F 8F"
    ["q"]="10 90"
    ["w"]="11 91"
    ["e"]="12 92"
    ["r"]="13 93"
    ["t"]="14 94"
    ["y"]="15 95"
    ["u"]="16 96"
    ["i"]="17 97"
    ["o"]="18 98"
    ["p"]="19 99"
    ["["]="1A 9A"
    ["]"]="1B 9B"
    ["ENTER"]="1C 9C"
    ["CTRLprs"]="1D"
    ["CTRLrls"]="9D"
    ["a"]="1E 9E"
    ["s"]="1F 9F"
    ["d"]="20 A0"
    ["f"]="21 A1"
    ["g"]="22 A2"
    ["h"]="23 A3"
    ["j"]="24 A4"
    ["k"]="25 A5"
    ["l"]="26 A6"
    [";"]="27 A7"
    ["'"]="28 A8"
    ['`']="29 A9"
    ["LSHIFTprs"]="2A"
    ["LSHIFTrls"]="AA"
    ['\']="2B AB"
    ["z"]="2C AC"
    ["x"]="2D AD"
    ["c"]="2E AE"
    ["v"]="2F AF"
    ["b"]="30 B0"
    ["n"]="31 B1"
    ["m"]="32 B2"
    [","]="33 B3"
    ["."]="34 B4"
    ["/"]="35 B5"
    ["RSHIFTprs"]="36"
    ["RSHIFTrls"]="B6"
    ["ALTprs"]="38"
    ["ALTrls"]="B8"
    ["LALT"]="38 B8"
    ["SPACE"]="39 B9"
    [" "]="39 B9"
    ["CAPS"]="3A BA"
    ["CAPSLOCK"]="3A BA"
    ["F1"]="3B BB"
    ["F2"]="3C BC"
    ["F3"]="3D BD"
    ["F4"]="3E BE"
    ["F5"]="3F BF"
    ["F6"]="40 C0"
    ["F7"]="41 C1"
    ["F8"]="42 C2"
    ["F9"]="43 C3"
    ["F10"]="44 C4"
    ["UP"]="E0 48 E0 C8"
    ["RIGHT"]="E0 4D E0 CD"
    ["LEFT"]="E0 4B E0 CB"
    ["DOWN"]="E0 50 E0 D0"
    ["HOME"]="E0 47 E0 C7"
    ["END"]="E0 4F E0 CF"
    ["PGUP"]="E0 49 E0 C9"
    ["PGDN"]="E0 51 E0 D1"
    ["CMDprs"]="E0 5C"
    ["CMDrls"]="E0 DC"
    # all codes below start with LSHIFTprs as commented in first item:
    ["!"]="2A 02 82 AA" # LSHIFTprs 1prs 1rls LSHIFTrls
    ["@"]="2A 03 83 AA"
    ["#"]="2A 04 84 AA"
    ["$"]="2A 05 85 AA"
    ["%"]="2A 06 86 AA"
    ["^"]="2A 07 87 AA"
    ["&"]="2A 08 88 AA"
    ["*"]="2A 09 89 AA"
    ["("]="2A 0A 8A AA"
    [")"]="2A 0B 8B AA"
    ["_"]="2A 0C 8C AA"
    ["+"]="2A 0D 8D AA"
    ["Q"]="2A 10 90 AA"
    ["W"]="2A 11 91 AA"
    ["E"]="2A 12 92 AA"
    ["R"]="2A 13 93 AA"
    ["T"]="2A 14 94 AA"
    ["Y"]="2A 15 95 AA"
    ["U"]="2A 16 96 AA"
    ["I"]="2A 17 97 AA"
    ["O"]="2A 18 98 AA"
    ["P"]="2A 19 99 AA"
    ["{"]="2A 1A 9A AA"
    ["}"]="2A 1B 9B AA"
    ["A"]="2A 1E 9E AA"
    ["S"]="2A 1F 9F AA"
    ["D"]="2A 20 A0 AA"
    ["F"]="2A 21 A1 AA"
    ["G"]="2A 22 A2 AA"
    ["H"]="2A 23 A3 AA"
    ["J"]="2A 24 A4 AA"
    ["K"]="2A 25 A5 AA"
    ["L"]="2A 26 A6 AA"
    [":"]="2A 27 A7 AA"
    ['"']="2A 28 A8 AA"
    ["~"]="2A 29 A9 AA"
    ["|"]="2A 2B AB AA"
    ["Z"]="2A 2C AC AA"
    ["X"]="2A 2D AD AA"
    ["C"]="2A 2E AE AA"
    ["V"]="2A 2F AF AA"
    ["B"]="2A 30 B0 AA"
    ["N"]="2A 31 B1 AA"
    ["M"]="2A 32 B2 AA"
    ["<"]="2A 33 B3 AA"
    [">"]="2A 34 B4 AA"
    ["?"]="2A 35 B5 AA"
)

# hacky way to clear input buffer before sending scancodes
function clear_input_buffer() {
    while read -d '' -r -t 0; do read -d '' -t 0.1 -n 10000; break; done
}

# read variable kbstring and convert string to scancodes and send to guest vm
function send_keys() {
    scancode=$(for (( i=0; i < ${#kbstring}; i++ ));
               do c[i]=${kbstring:i:1}; echo -n ${ksc[${c[i]}]}" "; done)
    scancode="${scancode} ${ksc['ENTER']}"
    clear_input_buffer
    VBoxManage controlvm "${vmname}" keyboardputscancode ${scancode}
}

# read variable kbspecial and send keystrokes by name,
# for example "CTRLprs c CTRLrls", and send to guest vm
function send_special() {
    scancode=""
    for keypress in ${kbspecial}; do
        scancode="${scancode}${ksc[${keypress}]}"" "
    done
    clear_input_buffer
    VBoxManage controlvm "${vmname}" keyboardputscancode ${scancode}
}

function send_enter() {
    kbspecial="ENTER"
    send_special
}

function prompt_lang_utils() {
    printf ${white_on_black}'
Press enter when the Language window is ready.'${default_color}
    read -p ""
    send_enter

    printf ${white_on_black}'
Press enter when the macOS Utilities window is ready.'${default_color}
    read -p ""

    kbspecial='CTRLprs F2 CTRLrls u ENTER t ENTER'
    send_special
}

function prompt_terminal_ready() {
    printf ${white_on_black}'
Press enter when the Terminal command prompt is ready.'${default_color}
    read -p ""
}

# Start the virtual machine. This should take a couple of minutes.
function populate_virtual_disks() {
echo "Starting virtual machine ${vmname}. This should take a couple of minutes."
VBoxManage startvm "${vmname}" 2>/dev/null

prompt_lang_utils
prompt_terminal_ready

echo ""
echo "Partitioning target virtual disk."

# get "physical" disks from largest to smallest
kbstring='disks="$(diskutil list | grep -o "[0-9][^ ]* GB *disk[012]$" | sort -gr | grep -o disk[012])"; disks=(${disks[@]})'
send_keys
prompt_terminal_ready

# partition largest disk as APFS
kbstring='diskutil partitionDisk "/dev/${disks[0]}" 1 GPT APFS "'"${vmname}"'" R'
send_keys
prompt_terminal_ready
echo ""
echo "Partitioning installer virtual disk."

# partition second-largest disk as JHFS+
kbstring='diskutil partitionDisk "/dev/${disks[1]}" 1 GPT JHFS+ "Install" R'
send_keys
prompt_terminal_ready

echo ""
echo "Loading base system onto installer virtual disk"

# Create secondary base system and shut down the virtual machine
kbstring='asr restore --source "/Volumes/'"${macOS_release_name:0:5}-files"'/BaseSystem.dmg" --target /Volumes/Install --erase --noprompt'
send_keys

prompt_terminal_ready

kbstring='shutdown -h now'
send_keys

printf ${white_on_black}'
Shutting down the virtual machine.
Press enter when the virtual machine shutdown is complete.'${default_color}
read -p ""
echo ""
echo "Detaching initial base system and starting virtual machine."
# Detach the original 2GB BaseSystem.vdi
VBoxManage storageattach "${vmname}" --storagectl SATA --port 2 --medium none
}

function prepare_the_installer_app() {
#Boot from "Install.vdi" that contains the 2GB BaseSystem and 10GB free space
echo "The VM will boot from the new base system on the installer virtual disk."
VBoxManage startvm "${vmname}" 2>/dev/null

prompt_lang_utils
prompt_terminal_ready
echo ""
echo "Moving installation files to installer virtual disk."
echo "The virtual machine may report that disk space is critically low; this is fine."
kbstring='app_path="$(ls -d /Install*.app)" && mount -rw / && install_path="${app_path}/Contents/SharedSupport/" && mkdir -p "${install_path}" && cd "/Volumes/'"${macOS_release_name:0:5}-files/"'" && cp *.chunklist *.plist *.dmg "${install_path}" && cat InstallESD.part* > "${install_path}/InstallESD.dmg"'
send_keys

# update InstallInfo.plist
prompt_terminal_ready
kbstring='sed -i.bak -e "s/InstallESDDmg\.pkg/InstallESD.dmg/" -e "s/pkg\.InstallESDDmg/dmg.InstallESD/" "${install_path}InstallInfo.plist" && sed -i.bak2 -e "/InstallESD\.dmg/{n;N;N;N;d;}" "${install_path}InstallInfo.plist"'
send_keys

# reboot, because the installer does not work when the partition is remounted
prompt_terminal_ready
kbstring='shutdown -h now'
send_keys
printf ${white_on_black}'
Shutting down virtual machine.
Press enter when the virtual machine shutdown is complete.'${default_color}
read -p ""
}

function start_the_installer_app() {
VBoxManage startvm "${vmname}" 2>/dev/null
prompt_lang_utils
prompt_terminal_ready

# Start the installer.
kbstring='app_path="$(ls -d /Install*.app)" && cd "/${app_path}/Contents/Resources/"; ./startosinstall --volume "/Volumes/'"${vmname}"'"'
send_keys
printf ${white_on_black}'
Installer started. Please wait for the license prompt to appear at
the bottom of the virtual machine terminal, then press enter here.
This will accept the license on the virtual machine.'${default_color}
read -p ""
kbspecial="A ENTER"
send_special

echo ""
echo "When the installer finishes preparing, the virtual machine will reboot"
echo "into the base system, not the installer."
}

function place_efi_apfs_drivers {
printf ${white_on_black}'
After the VM boots, press enter when either the Language window'${default_color}'
'${white_on_black}'or Utilities window is ready.'${default_color}
read -p ""
send_enter

printf ${white_on_black}'
Press enter when the macOS Utilities window is ready.'${default_color}
read -p ""
kbspecial='CTRLprs F2 CTRLrls u ENTER t ENTER'
send_special
prompt_terminal_ready

# find largest drive
kbstring='disks="$(diskutil list | grep -o "[0-9][^ ]* GB *disk[012]$" | sort -gr | grep -o disk[012])"; disks=(${disks[@]})'
send_keys
prompt_terminal_ready

echo ""
echo "Copying open-source APFS drivers to EFI partition"

# move drivers into path on EFI partition
kbstring='mkdir -p "/Volumes/'"${vmname}"'/mount_efi" && mount_msdos /dev/${disks[0]}s1 "/Volumes/'"${vmname}"'/mount_efi" && mkdir -p "/Volumes/'"${vmname}"'/mount_efi/EFI/driver/" && cp "/Volumes/'"${macOS_release_name:0:5}-files"'/"*.efi "/Volumes/'"${vmname}"'/mount_efi/EFI/driver/"'
send_keys
prompt_terminal_ready

# place startup.nsh EFI script
echo ""
echo "Placing EFI startup script that searches for boot.efi on the EFI partition"
kbstring='cp "/Volumes/'"${macOS_release_name:0:5}-files"'/startup.nsh" "/Volumes/'"${vmname}"'/mount_efi/startup.nsh"'
send_keys

}

function detach_installer_vdi_and_viso() {
# Shut down the virtual machine
printf ${white_on_black}'
Press enter when the terminal is ready.'${default_color}
read -p ""
kbstring='shutdown -h now'
send_keys

echo ""
echo "Shutting down virtual machine."
printf ${white_on_black}'
Press enter when the virtual machine shutdown is complete.'${default_color}
read -p ""

# detach installer from virtual machine
VBoxManage storageattach "${vmname}" --storagectl SATA --port 1 --medium none
VBoxManage storageattach "${vmname}" --storagectl SATA --port 3 --medium none
}

function boot_macos_and_clean_up() {
echo "The VM will boot from the target virtual disk image."
VBoxManage startvm "${vmname}"
echo ""
echo "macOS will now install and start up."
echo ""

# temporary files cleanup
VBoxManage closemedium "${macOS_release_name}_BaseSystem.vdi" 2>/dev/null
VBoxManage closemedium "Install ${macOS_release_name}.vdi" 2>/dev/null
printf 'Temporary files are safe to delete. '${white_on_red}'Delete temporary files?'${default_color}
delete=""
read -n 1 -p " [y/n] " delete 2>/dev/tty
echo ""
if [ "${delete,,}" == "y" ]; then
    rm "${macOS_release_name}_"* \
       "Install ${macOS_release_name}.vdi" \
       "ApfsDriverLoader.efi" "AppleImageLoader.efi" \
       "AppleSupport-v2.0.4-RELEASE.zip" "AppleUiSupport.efi" \
       "startup.nsh"
    rm "dmg2img.exe" 2>/dev/null
fi

printf 'macOS installation should complete in a few minutes.

Once the system is ready, i.e when you can see the homescreen, please follow through these
steps very carefully. These are intended to enable auto-login and disable authentication 
prompt to use sudo : 
-----------------------------------------------------------------------------
1) Open System Preferences and click USers and Groups.
2) Click the lock icon on bottom and enter the password you have set.
3) Click on Login Option on the bottom of Left Panel.
4) Under Automatic Login Dropdown, select your username.
5) Close System Preferences and open Terminal.
6) edit the %admin line -> ALL = (ALL) NOPASSWD: ALL and save it.
7) Close the terminal. Reboot the VM, ensure that it auto-logins and check if sudo asks for password.
   If it is working fine and the system is ready please press Enter.
'
}
function bootstrap_cuckoo_guest() {
    #----------------------
    #Setting up ENVIRONMENT
    #----------------------
    kbspecial='CMDprs SPACE CMDrls'
    sendspecial
    kbstring='terminal'
    send_keys
    kbspecial='ENTER ENTER'
    sendspecial
    prompt_terminal_ready
    printf "Installing Homebrew"
    kbstring='ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"'
    send_keys
    kbspecial='ENTER'
    sendspecial
    prompt_terminal_ready
    printf "Installing Python"
    kbstring='HOMEBREW_NO_AUTO_UPDATE=1 brew install python'
    send_keys
    prompt_terminal_ready
    printf "Installing Pip"
    kbstring='sudo easy_install pip && pip install --upgrade pip'
    send_keys
    prompt_terminal_ready
    printf "Installing Python Library Pillow"
    kbstring='sudo pip install Pillow'
    send_keys
    prompt_terminal_ready
    printf "Installing wget"
    kbstring='HOMEBREW_NO_AUTO_UPDATE=1 brew install wget'
    send_keys
    prompt_terminal_ready
    printf "Getting the Cuckoo agent"
    kbstring='cd /Users/Shared/ && wget '"${agenturl}"
    send_keys
    prompt_terminal_ready
    printf "setting up cronjob to activate agent at every startup"
    kbstring="sudo crontab -e"
    send_keys
    prompt_terminal_ready
    kbstring="i* * * * * python /Users/Shared/agent.py"
    send_keys
    kbspecial="ESC"
    sendspecial
    kbstring=":wq"
    send_keys
    #------------------
    #Setting up XNUMON
    #------------------
    prompt_terminal_ready
    printf "Downloading xnumon"
    kbstring='wget https://mirror.roe.ch/rel/xnumon/xnumon-0.1.7.2.pkg'
    send_keys
    prompt_terminal_ready
    printf "installing xnumon. Please click on OK when the GUI prompts"
    kbstring='sudo installer -pkg xnumon-0.1.7.2.pkg -target /'
    send_keys
    prompt_terminal_ready
    printf "Downloading Xnumon configuration"
    kbsring='wget https://raw.githubusercontent.com/ManasMahapatra/cuckoo-macOS/master/configuration.plist-default'
    send_keys
    prompt_terminal_ready
    printf "Configuring xnumon"
    kbstring 'sudo mv configuration.plist-default /Library/Application\ Support/ch.roe.xnumon/'
    send_keys
    prompt_terminal_ready
    kbstring='sudo -i'
    send_keys
}


function stages() {
printf '\nUSAGE: '${white_on_black}${0}' [STAGE]...'${default_color}'

The script is divided into stages that run as separate functions.
Add one or more stage titles to the command line to run the corresponding
function. If the first argument is "stages" all others are ignored.
Some examples:
    "'"${0}"' populate_virtual_disks prepare_the_installer_app"
These stages might be useful by themselves if the VDI files and the VM are
already initialized.
    "'"${0}"' configure_vm"
This stage might be useful after copying an existing VM VDI to a different
VirtualBox installation and having the script automatically configure the VM.

Available stage titles:
    welcome
    check_dependencies
    prompt_delete_existing_vm
    create_vm
    prepare_macos_installation_files
    create_macos_installation_files_viso
    create_basesystem_vdi
    create_target_vdi
    create_install_vdi
    attach_initial_storage
    configure_vm
    populate_virtual_disks
    prepare_the_installer_app
    start_the_installer_app
    place_efi_apfs_drivers
    detach_installer_vdi_and_viso
    boot_macos_and_clean_up
    bootstrap_cuckoo_guest
'
}

if [ -z "${1}" ]; then
    welcome
    check_dependencies
    prompt_delete_existing_vm
    create_vm
    prepare_macos_installation_files
    create_macos_installation_files_viso
    create_basesystem_vdi
    create_target_vdi
    create_install_vdi
    attach_initial_storage
    configure_vm
    populate_virtual_disks
    prepare_the_installer_app
    start_the_installer_app
    place_efi_apfs_drivers
    detach_installer_vdi_and_viso
    boot_macos_and_clean_up
    bootstrap_cuckoo_guest
else
    if [ "${1}" != "stages" ]; then
        check_dependencies
        for argument in "$@"; do ${argument}; done
    else
        stages
    fi
fi
