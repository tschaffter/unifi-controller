# UniFi Controller

[![GitHub Stars](https://img.shields.io/github/stars/tschaffter/unifi-controller.svg?color=94398d&labelColor=555555&logoColor=ffffff&style=for-the-badge&logo=github)](https://github.com/tschaffter/unifi-controller)
[![GitHub License](https://img.shields.io/github/license/tschaffter/unifi-controller.svg?color=94398d&labelColor=555555&logoColor=ffffff&style=for-the-badge&logo=github)](https://github.com/tschaffter/unifi-controller)

Deploy the [UniFi Controller][unifi_controller] on an hardened Raspberry Pi for
enhanced security.

## Motivation

This article describes how to configure an hardened Raspberry Pi to run the
[UniFi Controller][unifi_controller] in a Docker container. This solution is a
secure alternative to buying a [Cloud Key][unifi_cloud_key] from Ubiquiti.

## Hardware

- Raspberry Pi 4 Model B 2019 8GB
- SanDisk Extreme 32GB MicroSDHC UHS-3 Card

## What is SELinux?

Security-Enhanced Linux (SELinux) is a mandatory access control (MAC) security
mechanism implemented in the kernel. By default under a strict `enforcing` setting,
everything is denied and then a series of exceptions policies are written that
give each element of the system (a service, program or user) only the access
required to function. If a service, program or user subsequently tries to access
or modify a file or resource (e.g. memory) not necessary for it to function,
then access is denied and the action is logged.

A more in-depth descirption of SELinux is available [here][selinux].

## Build the Linux kerner with SELinux support

As of August 2020, the linux kernel shipped with the Raspberry Pi OS does not
include the security module SELinux. Here we are going to cross-compile the kernel
with SELinux enabled using the tool [tschaffter/raspberry-pi-kernel-hardened][gh_hardened_kernel].

This single command builds the kernel for a Raspberry Pi 4. This command can be
run on any computer that has the Docker installed. Note that this tool uses all
the CPU cores available to the container to speed up the cross-compilation of the
kernel, which by default are all the CPU cores of the host.

    mkdir -p output && docker run \
        --rm \
        -v $PWD/output:/output \
        tschaffter/raspberry-pi-kernel-hardened \
            --kernel-branch rpi-5.4.y \
            --kernel-defconfig bcm2711_defconfig \
            --kernel-localversion $(date '+%Y%m%d')-hardened

    Moving .deb packages to /output
    SUCCESS The kernel has been successfully packaged.

    INSTALL
    sudo dpkg -i linux-*-20200804-hardened*.deb
    sudo sh -c "echo 'kernel=vmlinuz-5.4.51-20200804-hardened+' >> /boot/config.txt"
    sudo reboot

    ENABLE SELinux
    sudo apt-get install selinux-basics selinux-policy-default auditd
    sudo sh -c "sed -i '$ s/$/ selinux=1 security=selinux/' /boot/cmdline.txt"
    sudo touch /.autorelabel
    sudo reboot
    sestatus

See the GitHub repo of this tool to learn how to customize the build for other
versions of the Pi.

## Install Raspberry Pi OS

Install Raspberry Pi OS Lite (preferred) or the distribution of your choice by
following the instructions given [here][pi_imager]. After installing the OS on
the SD card, create an empty file named `ssh` on the boot partition to enable
remote connection to the Pi using SSH.

On Mac OS:

    cd /Volumes/boot && touch ssh

On Windows 10 using Windows Subsystem for Linux (WSL):

    sudo mkdir /mnt/d
    sudo mount -t drvfs D: /mnt/d
    touch /mnt/d/ssh
    sudo umount /mnt/d/

## First login

After placing the SD card into the Pi and connecting it to the network using an
Ethernet cable:

1. SSH into the Pi: `ssh pi@<ip_address>` (default password is "raspberry")
2. Change the password: `passwd`
3. Update the Pi: `sudo apt update && sudo apt -y upgrade`

### Change your username

The default user on the Pi is named `pi`. It is recommended to create a new user
before removing the user `pi` for better security.

1. Create the new user (replace `bob` by your own username).

        sudo -s
        export user=bob
        useradd -m ${user} \
            && usermod -a -G sudo ${user} \
            && echo "${user} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${user} \
            && chmod 0440 /etc/sudoers.d/${user}
        passwd ${user}

2. Logout of the Pi and reconnect using the new user.
3. Delete the default user `pi`: `sudo deluser -remove-home pi`.

## Install the Linux kernel with SELinux support

1. Create the folder `/home/<user>/kernel` on the Pi and place the `*deb` packages
   of the hardened kernel there (e.g. using `scp`).
2. Install the new kernel (copy/paste the commands given by the kernel builder).

        sudo dpkg -i ~/kernel/linux-*-20200804-hardened*.deb
        sudo sh -c "echo 'kernel=vmlinuz-5.4.51-20200804-hardened+' >> /boot/config.txt"
        sudo reboot
        $ uname -a
        Linux raspberrypi 5.4.51-20200804-hardened+ #1 SMP Wed Aug 5 04:37:44 UTC 2020 armv7l GNU/Linux

3. Install SELinux (copy/paste the commands given by the kernel builder). The
   reboot will take some time as the label of all the files are updated.

        sudo apt-get install -y selinux-basics selinux-policy-default auditd
        sudo sh -c "sed -i '$ s/$/ selinux=1 security=selinux/' /boot/cmdline.txt"
        sudo touch /.autorelabel
        sudo reboot
        sestatus

4. Set SELinux mode to `enforcing` in `/etc/selinux/config`.
5. Check the active configuration of SELinux with `sestatus`.

## Install Docker

Docker is needed to run the UniFi Controller in a Docker container. Run the
following command to install the Docker engine on the Pi.

    curl -fsSL get.docker.com -o get-docker.sh && sudo sh get-docker.sh

The command below enables the Docker service to start automatically at boot:

    sudo systemctl enable docker.service

We add the current user to the group `docker` so that we can run docker commands
without having to prefix them with `sudo`.

    sudo usermod -aG docker $(whoami)

## Deploy the UniFi Controller

Clone this GitHub repository on the Pi, then run `./unifi-controller.sh` as the
current (non-root) user for enhanced security. This command start the UniFi
Controller in a Docker container and creates a systemd service. This service
ensures that the controller is started at boot and properly stopped when the Pi
is turned off.

After running `./unifi-controller.sh`, check that the controller has successfully
started by looking at the logs of the Docker container (stdout).

    $ docker logs unifi-controller
    ...
    [cont-init.d] done.
    [services.d] starting services
    [services.d] done.

See the section [Known issues](#known-issues) if any error messages show up.

### Never turn off the Pi by unplugging its power adapter

The controller uses a MongoDB instance to manage its data. These data may become
corrupted if the controller is not stopped properly. The command below can be
used to shut down the system now and then halt it.

    sudo shutdown -h now

## Update the UniFi Controller

1. Update the version of the controller in `unifi-controller.sh`
2. `./unifi-controller.sh`

## Check the runtime logs

    docker exec -it unifi-controller tail -f /usr/lib/unifi/logs/server.log
    docker exec -it unifi-controller tail -f /usr/lib/unifi/logs/mongod.log

## Backup your controller data

Loosing the controller or its data means that you will no longer be able to
manage your network. Consider implementing one or more of the following backup
strategies:

- Save the content of the Docker volume `unifi-controller` to a remote location
- Create a copy of the SD card

## Setup UFW

Install and configure UFW (Uncomplicated Firewall) to protect the Pi against
unauthorized remote connections. The ports opened below include SSH and the ports
[required by the UniFi controller](https://hub.docker.com/r/linuxserver/unifi-controller).

    sudo apt-get install -y ufw
    sudo ufw status
    sudo ufw allow ssh
    sudo ufw allow 3478,10001,8080,8443  # required by the controller
    sudo ufw enable

## Make your Raspberry Pi even more secure

This excellent [article][secure_pi] from raspberrypi.org provides additional
tips to secure your Pi.

## Access Unifi Controller web interface

The web interface of the UniFi controller should now be available at the addresses:

<!-- markdownlint-disable MD034 -->
- https://<controller_address>:8443
- http://<controller_address>:8080

## Known issues

- ["OpenJDK Client VM warning: INFO: os::commit_memory"][issue_6]
- ["OpenJDK Client VM warning: libubnt_webrtc_jni.so"][issue_7]

## Contributing change

Please read the [`CONTRIBUTING.md`](CONTRIBUTING.md) for details on how to
contribute to this project.

<!-- Definitions -->

[unifi_controller]: https://help.ui.com/hc/en-us/articles/360012282453-UniFi-How-to-Set-Up-a-UniFi-Network-Controller
[unifi_cloud_key]: https://www.ui.com/unifi/unifi-cloud-key/
[gh_hardened_kernel]: https://github.com/tschaffter/raspberry-pi-kernel-hardened
[selinux]: https://wiki.centos.org/HowTos/SELinux
[pi_imager]: https://www.raspberrypi.org/documentation/installation/installing-images/README.md
[unifi_controller_docker]: https://hub.docker.com/r/linuxserver/unifi-controller
[issue_6]: https://github.com/tschaffter/unifi-controller/issues/6
[issue_7]: https://github.com/tschaffter/unifi-controller/issues/7
[secure_pi]: https://www.raspberrypi.org/documentation/configuration/security.md