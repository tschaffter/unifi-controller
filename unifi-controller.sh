#!/usr/bin/env bash
#
#   @tschaffter
#
#   Creates and starts a service for the UniFi Controller.
#

controller_image="linuxserver/unifi-controller"
controller_version="5.12.72-ls61"

test -f /etc/systemd/system/unifi-controller.service ||
{
# Where the controller saves its configuration
docker volume create unifi-controller

cat >> /etc/systemd/system/unifi-controller.service << EOF
[Unit]
Description=Unifi Controller container from linuxserver.io
After=docker.service
Requires=docker.service

[Service]
User=$(id -u $USER)
Group=$(id -g $USER)
TimeoutStartSec=0
Restart=always
# Should this service check for container updates first?
# ExecStartPre=-/usr/bin/docker pull ${controller_image}:latest
ExecStartPre=-/usr/bin/docker stop unifi-controller
ExecStart=/usr/bin/docker start -a unifi-controller
ExecStop=/usr/bin/docker stop -t 5 unifi-controller

[Install]
WantedBy=multi-user.target
EOF
systemctl enable unifi-controller
}

# Update the docker container
# Only the ports marked as `Required` in the image documentation are mapped
docker pull linuxserver/unifi-controller:${controller_version}
docker stop unifi-controller
docker rm unifi-controller
docker create \
    --name=unifi-controller \
    --restart unless-stopped \
    -v unifi-controller:/config \
    -e PUID=$(id -u $USER) \
    -e PGID=$(id -g $USER) \
    -e MEM_LIMIT=1024M \
    -p 3478:3478/udp \
    -p 10001:10001/udp \
    -p 8080:8080 \
    -p 8443:8443 \
    linuxserver/unifi-controller:${controller_version}
docker start unifi-controller
docker image prune