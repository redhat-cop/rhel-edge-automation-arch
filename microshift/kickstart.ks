lang en_US.UTF-8
keyboard us
timezone UTC
zerombr
clearpart --all --initlabel
autopart --type=plain --fstype=xfs --nohome
reboot
text
network --bootproto=dhcp --device=link --activate --onboot=on
user --name=redhat --groups=wheel --iscrypted --password=$6$CSSKOjfLnT9NGS6F$6h9cY9OW/ZW6j4u8sNHCEr2bEgm2OOQFcMo1eRT4.TEzLACrjsM8PSFRldfFs8UwemI1URLB98fzWHnSyXMNT/

ostreesetup --nogpg --osname=rhel --remote=edge --url={{ ostree_repo_url }} --ref=rhel/8/x86_64/edge

%post --log=/var/log/anaconda/post-install.log --erroronfail
echo -e 'redhat\tALL=(ALL)\tNOPASSWD: ALL' >> /etc/sudoers
%end
