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

The Unifi controller is required to run the Unifi controller in a Docker container.
The instructions to install Docker on Debian are available
[here](https://github.com/tschaffter/debian).


curl -fsSL https://download.docker.com/linux/raspbian/gpg | sudo apt-key add -



sudo add-apt-repository \
        "deb https://download.docker.com/linux/raspbian \
        $(lsb_release -cs) \
        stable"

## Start Unifi Controller

1. Clone this repository
2.


