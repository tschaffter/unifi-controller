# UniFi Controller

[![GitHub Stars](https://img.shields.io/github/stars/tschaffter/unifi-controller.svg?color=94398d&labelColor=555555&logoColor=ffffff&style=for-the-badge&logo=github)](https://github.com/tschaffter/unifi-controller)
[![GitHub License](https://img.shields.io/github/license/tschaffter/unifi-controller.svg?color=94398d&labelColor=555555&logoColor=ffffff&style=for-the-badge&logo=github)](https://github.com/tschaffter/unifi-controller)

Deploying the [UniFi Controller][unifi_controller] on an hardened Raspberry Pi for
enhanced security.

## Overview

This article describes how to setup a Raspberry Pi to run the UniFi Network
Controller in a Docker container. This solution is a cheap and secure alternative
to buying a Cloud Key from Ubiquiti.

The UniFi Controller does not need to run continuously once the network has been
configured unless you want to collect network data statistics. For improved
security, run the controller only when needed. The rest of the time, the Pi can
be used for other purposes like running [Kodi][kodi] (open-source home theater
software), [Steam Link][steamlink] and [RetroPie][retropie] on a second SD card.

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

A more in-depth descirption of SELinux can be found [here][selinux].

## Build the Linux kerner with SELinux support

As of August 2020, the linux kernel shipped with Raspberry Pi OS does not come
with the security module SELinux. We use the tool [tschaffter/raspberry-pi-kernel-hardened][gh_hardened_kernel]
to cross-compile the Linux kernel with SELinux support.

Run the following command on any host that has the Docker Engine installed to
build three .deb packages that will be used to install the hardened kernel on a
Raspberry Pi 4. Have a look at the README of [tschaffter/raspberry-pi-kernel-hardened][gh_hardened_kernel]
for detailed information about the build options and how to build an hardened
kernel for other versions of the Raspberry Pi.

```console
docker run \
    --rm \
    -v $PWD/output:/output \
    tschaffter/raspberry-pi-kernel-hardened \
        --kernel-branch rpi-5.4.y \
        --kernel-defconfig bcm2711_defconfig \
        --kernel-localversion 5.4.y-$(date '+%Y%m%d')-hardened
...

Moving .deb packages to /output
SUCCESS The kernel has been successfully packaged.

INSTALL
sudo dpkg -i linux-*-5.4.y-20200804-hardened*.deb
sudo sh -c "echo 'kernel=vmlinuz-5.4.51-5.4.y-20200804-hardened+' >> /boot/config.txt"
sudo reboot

ENABLE SELinux
sudo apt-get install selinux-basics selinux-policy-default auditd
sudo sh -c "sed -i '$ s/$/ selinux=1 security=selinux/' /boot/cmdline.txt"
sudo touch /.autorelabel
sudo reboot
sestatus
```

## Install Raspberry Pi OS Lite (32-bit)

1. Flash the SD card using [Raspberry Pi Imager][pi_imager].
2. Enable ssh by adding the empty file `ssh` to the boot partition of the SD card.

    On Mac OS:

    ```console
    cd /Volumes/boot && touch ssh
    ```

    On Windows 10 using WSL2:

    ```console
    sudo mkdir /mnt/d
    sudo mount -t drvfs D: /mnt/d
    touch /mnt/d/ssh
    sudo umount /mnt/d/
    ```

## SSH into the Pi

1. Connect the Pi to the network using an Ethernet cable.
2. SSH into the Pi: `ssh pi@<ip address>` (default password is "raspberry")
3. Change the password: `passwd`
4. Update the Pi: `sudo apt update && sudo apt -y upgrade`

## Create a new user

The Raspberry Pi comes with the default username `pi`, so changing this will
immediately make the Raspberry Pi more secure.

1. Create the new user (here `tschaffter`).

    ```console
    sudo -s
    export user=tschaffter
    useradd -m ${user} \
        && usermod -a -G sudo ${user} \
        && echo "${user} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${user} \
        && chmod 0440 /etc/sudoers.d/${user}
    passwd ${user}
    ```

2. Logout of the Pi and reconnect using the new user.
3. Delete the default user `pi`: `sudo deluser -remove-home pi`.

## Install the Linux kernel with SELinux support

1. Create the folder `/home/<user>/kernel` on the Pi and place the `*deb` packages
   of the hardened kernel there (e.g. using `scp`).
2. Install the new kernel. Copy/paste the commands given by the kernel builder.

    ```console
    sudo dpkg -i ~/kernel/linux-*-5.4.y-20200804-hardened*.deb
    sudo sh -c "echo 'kernel=vmlinuz-5.4.51-5.4.y-20200804-hardened+' >> /boot/config.txt"
    sudo reboot
    $ uname -a
    Linux raspberrypi 5.4.51-5.4.y-20200804-hardened+ #1 SMP Wed Aug 5 04:37:44 UTC 2020 armv7l GNU/Linux
    ```

3. Install SELinux. Copy/paste the commands given by the kernel builder. The
   reboot will take some time as the label of all the files are updated.

    ```console
    sudo apt-get install -y selinux-basics selinux-policy-default auditd
    sudo sh -c "sed -i '$ s/$/ selinux=1 security=selinux/' /boot/cmdline.txt"
    sudo touch /.autorelabel
    sudo reboot
    sestatus
    ```

4. Set SELinux mode to `enforcing` in `/etc/selinux/config`.
5. Check SELinux active configuration with `sestatus`.

## Install Docker

Docker is required to run the UniFi controller in a Docker container. Run the
following command to install the Docker engine.

```console
curl -fsSL get.docker.com -o get-docker.sh && sudo sh get-docker.sh
```

The Docker Engine provides the program `docker`. This is all we need to start
the controller. Additional docker tools like `docker-compose` could be installed
by adding the Docker package repository:

Note: As of 2020-08-06, this command does not work on Raspian Buster because
Docker does not yet provide a release for it (only up to Raspian Stretch).

```console
curl -fsSL https://download.docker.com/linux/raspbian/gpg | sudo apt-key add -
sudo add-apt-repository \
        "deb https://download.docker.com/linux/raspbian \
        $(lsb_release -cs) \
        stable"
sudo apt-get update
```

Make sure that the Docker service starts automatically at boot time:

```console
sudo systemctl start docker.service
```

Finally add the user to the group `docker` to run Docker commands without
prefixing them with `sudo`.

```console
sudo usermod -aG docker $(whoami)
```

References:

- [Happy Pi Day with Docker and Raspberry Pi](https://www.docker.com/blog/happy-pi-day-docker-raspberry-pi/)

## Deploy the UniFi Controller

Clone this GitHub repository on the Pi, then run `./unifi-controller.sh` as a
non-root user for enhanced security.

This script creates the following entities:

- a Docker container named `unifi-controller` based on the
Docker image [linuxserver/unifi-controller][unifi_controller_docker],
- a volume named `unifi-controller` where the controller will save its
configuration,
- a systemd service named `unifi-controller` to ensure that the Docker container
is stopped gracefully when the host is turned off.

After running `./unifi-controller.sh`, check that the controller has successfully
started by checking the logs of the Docker container.

```console
$ docker logs unifi-controller
...
[cont-init.d] done.
[services.d] starting services
[services.d] done.
```

## Check the controller logs

TODO

## Fix "OpenJDK Client VM warning: INFO: os::commit_memory"

If SELinux is enabled and its mode is set to `enforcing`, the controller should
have failed to start. A look at `/var/log/messages` should reveal the following
error:

> OpenJDK Client VM warning: INFO: os::commit_memory(0xb31ab000, 163840, 1) failed; error='Permission denied' (errno=13)

The command `sudo audit2allow -w -a` can be used to translates the SELinux audit
messages into a description of why the access was denied.

The current solution is to enable the boolean `allow_execmem`. This solution is
probably too permissive and should ideally be more restrictive, for example by
targetting a single Java program.

```console
sudo setsebool -P allow_execmem 1
getsebool -a | grep allow_execmem  # should be "on"
```

Restart the container (`docker restart unifi-controller`) and then check its logs
to check that the controller has successfully started (`docker logs unifi-controller`).

References:

- [There is insufficient memory for the Java Runtime Environment to continue. #2298](https://github.com/syslog-ng/syslog-ng/issues/2298)

## Fix "OpenJDK Client VM warning: libubnt_webrtc_jni.so"

This error has been encountered in the version `5.12.72-ls61` of the Docker image
[linuxserver/unifi-controller][unifi_controller_docker]. This error prevents the
controller to communicate with Ubiquiti servers, for example to check and download
the latest firmware for the UniFi devices (USG, Switch, AP, etc.).

The following command will fix the running container:

```console
docker exec -it unifi-controller /bin/bash -c "apt-get update && apt-get install execstack && execstack -c /usr/lib/unifi/lib/native/Linux/armv7/libubnt_webrtc_jni.so"
```

## Setup UFW

Install and configure UFW (Uncomplicated Firewall). The ports to open include
SSH and the ports [required by the UniFi controller](https://hub.docker.com/r/linuxserver/unifi-controller)
(see [UniFi - Ports Used](https://help.ui.com/hc/en-us/articles/218506997-UniFi-Ports-Used)).

```console
sudo apt-get install -y ufw
sudo ufw status
sudo ufw allow ssh
sudo ufw allow 3478,10001,8080,8443  # required by the controller
sudo ufw enable
```

## Access Unifi Controller web interface

The web interface of the UniFi controller should now be available at the addresses:

<!-- markdownlint-disable MD034 -->
- https://<controller_address>:8443
- http://<controller_address>:8080

## Best practices

- Always stop the Pi properly and never turn it off by unplugging the power
  adapter. The controller use a MongDB instance to manage its data. These data
  may become corrupted if the controller is not stopped properly. Use
  `sudo shutdown -h now` to instruct the system to shut down and then halt.
- Loosing the controller or its data means that you will no longer be able to
  manage your network and will need to recreate it. Consider keeping a copy of the
  SD card of the Raspberry Pi or a copy of the Docker volume `unifi-controller`.

## TODO

- Describes how to check the controller (live) logs.
- Check that all the data required to manage the network are saved to the Docker
  volume `unifi-controller`.

<!-- Definitions -->

[unifi_controller]: https://help.ui.com/hc/en-us/articles/360012282453-UniFi-How-to-Set-Up-a-UniFi-Network-Controller
[gh_hardened_kernel]: https://github.com/tschaffter/raspberry-pi-kernel-hardened
[selinux]: https://wiki.centos.org/HowTos/SELinux
[kodi]: https://kodi.tv/
[steamlink]: https://store.steampowered.com/steamlink/about/
[retropie]: https://retropie.org.uk/
[pi_imager]: https://www.raspberrypi.org/documentation/installation/installing-images/README.md
[unifi_controller_docker]: https://hub.docker.com/r/linuxserver/unifi-controller