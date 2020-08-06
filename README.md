# Setup Unifi controller

## Hardware

- Raspberry Pi 4 Model B 2019 8GB
- SanDisk Extreme 32GB MicroSDHC UHS-3 Card

## Build Linux kerner with SE support

```console
docker run \
    --rm \
    -v $PWD/output:/output \
    tschaffter/raspberry-pi-kernel-hardened \
        --kernel-branch rpi-5.4.y \
        --kernel-defconfig bcm2711_defconfig \
        --kernel-localversion 5.4.y-20200804-hardened
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

1. Flash the SD card using [Raspberry Pi Imager](https://www.raspberrypi.org/documentation/installation/installing-images/README.md)
2. Enable ssh by adding the empty file `ssh` to the boot partition of the SD card

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

1. Connect the Pi to the network using an Ethernet cable
2. SSH into the Pi: `ssh pi@<ip address>` (default password is "raspberry")
3. Change the password: `passwd`
4. Update the Pi: `sudo apt update && sudo apt -y upgrade && sudo apt autoremove`

## Create new user

1. Create the new user `tschaffter` and set its password

    ```console
    sudo -s
    export user=tschaffter
    useradd -m ${user} \
        && usermod -a -G sudo ${user} \
        && echo "${user} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${user} \
        && chmod 0440 /etc/sudoers.d/${user}
    passwd ${user}
    ```

2. Logout of the Pi and reconnect using the user `tschaffter`
3. Delete the user `pi`: `sudo deluser -remove-home pi`

## Install Linux kernel with SELinux support

1. Create the folder `/home/${user}/kernel` on the Pi
2. SSH kernel files to the Pi: `scp linux-*-5.4.y-20200804-hardened*.deb tschaffter@<ip address>:./kernel`
3. SSH into the pi
4. Install the new kernel

    ```console
    sudo dpkg -i ~/kernel/linux-*-5.4.y-20200804-hardened*.deb
    sudo sh -c "echo 'kernel=vmlinuz-5.4.51-5.4.y-20200804-hardened+' >> /boot/config.txt"
    sudo reboot
    $ uname -a
    Linux raspberrypi 5.4.51-5.4.y-20200804-hardened+ #1 SMP Wed Aug 5 04:37:44 UTC 2020 armv7l GNU/Linux
    ```

5. Install SELinux. The reboot will take some time as the label of all the files
 are updated.

    ```console
    sudo apt-get install -y selinux-basics selinux-policy-default auditd
    sudo sh -c "sed -i '$ s/$/ selinux=1 security=selinux/' /boot/cmdline.txt"
    sudo touch /.autorelabel
    sudo reboot
    sestatus
    ```

6. Enable SELinux: `sudo vim /etc/selinux/config` and set the mode to `enforcing`

## Install Docker

Docker is required to run the UniFi controller in a Docker container. Run the
following command to install the Docker engine.

```console
curl -fsSL get.docker.com -o get-docker.sh && sudo sh get-docker.sh
```

The Docker engine provides the program `docker`, which is all we need.
Additional programs can be installed by registering the Docker repo:

Note: As of 2020-08-06, the second command does not work because Docker does not
provide yet a release for Raspbian Buster (only up to Stretch).

```console
curl -fsSL https://download.docker.com/linux/raspbian/gpg | sudo apt-key add -
sudo add-apt-repository \
        "deb https://download.docker.com/linux/raspbian \
        $(lsb_release -cs) \
        stable"
sudo apt-get update
```

References:

- [Happy Pi Day with Docker and Raspberry Pi](https://www.docker.com/blog/happy-pi-day-docker-raspberry-pi/)

## Start Unifi Controller

Clone this GitHub repository on the Pi, then run `sudo ./unifi-controller.sh`.
This script creates a Docker container named `unifi-controller` and a Docker
volume with the same name where the UniFi controller saves its configuration.
A systemd service named `unifi-controller` is also created and configured so
that the UniFi controller is started at boot time.

Running the script again will stop and remove the running Docker container, and
pull the `latest` version of the Docker image and run it.

Show the log of the container to check that the controller has successfully
started (`docker logs unifi-controller`). If run just after starting the
container, the "lsio" logo must appear and the last lines should look like:

```console
[cont-init.d] done.
[services.d] starting services
[services.d] done.
```

If SELinux is enabled and its mode is set to `enforcing`, the logs should show a
repetition of messages that say:

> OpenJDK Client VM warning: INFO: os::commit_memory(0xb31ab000, 163840, 1) failed; error='Permission denied' (errno=13)

Use `sudo audit2allow -w -a` to translates SELinux audit messages into a
description of why the access was denied.

The current solution is to enable the boolean `allow_execmem`. This solution is
too permissive and should ideally be more restrictive, for example by tagetting
only Java programs.

```console
getsebool -a | grep allow_execmem  # is off
sudo setsebool -P allow_execmem 1
getsebool -a | grep allow_execmem  # is on
```

The command `docker logs unifi-controller` should not show that the UniFi
controller has successfully started (see above).

References:

- [There is insufficient memory for the Java Runtime Environment to continue. #2298](https://github.com/syslog-ng/syslog-ng/issues/2298)

## Setup UFW

Install and configure UFW (Uncomplicated Firewall). The ports to open include
SSH and the ports [required by the UniFi controller](https://hub.docker.com/r/linuxserver/unifi-controller)
(see [UniFi - Ports Used](https://help.ui.com/hc/en-us/articles/218506997-UniFi-Ports-Used)).

```console
sudo apt-get install -y ufw
sudo ufw status
sudo ufw allow ssh
sudo ufw allow 3478,10001,8080,8443
sudo ufw enable
```

## Access UniFi Controller web interface

The web interface of the UniFi controller should now be available:

<!-- markdownlint-disable MD034 -->
- https://<ip_address>:8443
- http://<ip_address>:8080
