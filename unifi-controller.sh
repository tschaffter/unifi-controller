#!/usr/bin/env bash
#
#   @tschaffter
#
#   Runs the latest version of the unifi controller.
#
test -f /etc/systemd/system/unifi-controller.service ||
{
apt-get update && apt-get install docker.io
docker volume create unifi-controller

cat >> /etc/systemd/system/unifi-controller.service << EOF
[Unit]
Description=Unifi Controller container from linuxserver.io
After=docker.service
Requires=docker.service

[Service]
TimeoutStartSec=0
Restart=always
#Should this service check for container updates first?
#ExecStartPre=-/usr/bin/docker pull unifi-controller
ExecStartPre=-/usr/bin/docker stop unifi-controller
ExecStart=/usr/bin/docker start -a unifi-controller
ExecStop=/usr/bin/docker stop -t 2 unifi-controller

[Install]
WantedBy=multi-user.target
EOF
systemctl enable unifi-controller
}

#Update service
docker pull linuxserver/unifi-controller
docker stop unifi-controller
docker rm unifi-controller
docker create \
    --name=unifi-controller \
    --restart unless-stopped \
    -v unifi-controller:/config \
    -e PUID=$(id -u $USER) -e PGID=$(id -g $USER) \
    -e MEM_LIMIT=1024M \
    -p 3478:3478/udp \
    -p 10001:10001/udp \
    -p 8080:8080 \
    -p 8443:8443 \
    linuxserver/unifi-controller:latest
docker start unifi-controller
docker image prune
