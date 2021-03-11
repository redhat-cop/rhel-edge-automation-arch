# set locale defaults for the Install
lang en_US.UTF-8
keyboard us
timezone UTC

# initialize any invalid partition tables and destroy all of their contents
zerombr

# erase all disk partitions and create a default label
clearpart --all --initlabel

# automatically create xfs partitions with no LVM and no /home partition
autopart --type=plain --fstype=xfs --nohome

# reboot after installation is successfully completed
reboot

# installation will run in text mode
text

# activate network devices and configure with DHCP
network --bootproto=dhcp

# create default user with sudo privileges
user --name={{ rfe_user | default('core') }} --groups=wheel --password={{ rfe_password | default('edge') }}

# set up the OSTree-based install with disabled GPG key verification, the base
# URL to pull the installation content, 'rhel' as the management root in the
# repo, and 'rhel/8/x86_64/edge' as the branch for the installation
ostreesetup --nogpg --url={{ rfe_tarball_url }}/repo/ --osname=rhel --remote=edge --ref=rhel/8/x86_64/edge

%post

# Set the update policy to automatically download and stage updates to be
# applied at the next reboot
#stage updates as they become available. This is highly recommended
echo AutomaticUpdatePolicy=stage >> /etc/rpm-ostreed.conf

cat > /etc/systemd/system/ibm-weather-forecaster.service << 'EOF'
[Unit]
Description=Podman container-ibm-weather-forecaster.service
Requires=network.target
Requires=network-online.target
After=network-online.target
After=nss-lookup.target

[Service]
Environment=PODMAN_SYSTEMD_UNIT=%n
Restart=on-failure
ExecStartPre=/bin/rm -f %t/container-ibm-weather-forecaster.pid %t/container-ibm-weather-forecaster.ctr-id
ExecStart=/usr/bin/podman run --conmon-pidfile %t/container-ibm-weather-forecaster.pid --cidfile %t/container-ibm-weather-forecaster.ctr-id --cgroups=no-conmon --replace -d --label io.containers.autoupdate=image --name ibm-weather-forecaster -p 5000:5000 quay.io/codait/max-weather-forecaster:latest
ExecStop=/usr/bin/podman stop --ignore --cidfile %t/container-ibm-weather-forecaster.ctr-id -t 10
ExecStopPost=/usr/bin/podman rm --ignore -f --cidfile %t/container-ibm-weather-forecaster.ctr-id
PIDFile=%t/container-ibm-weather-forecaster.pid
KillMode=none
Type=forking

[Install]
WantedBy=multi-user.target default.target
EOF

systemctl enable ibm-weather-forecaster.service

%end