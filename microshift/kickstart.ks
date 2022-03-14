lang en_US.UTF-8
keyboard us
timezone UTC
zerombr
clearpart --all --initlabel
autopart --type=plain --fstype=xfs --nohome
reboot
text
network --bootproto=dhcp --device=link --activate --onboot=on
user --name=redhat --groups=wheel --iscrypted --password=$6$pa0G277C72qjSVm5$CbFgJ.9vgYW3/cSzqfUYw/T1DlHIxj9HEMF0txTEum5kSwqEJZtvXLF3XbQ8VrqTuURWs/awByAZtrXHC1jkL/

ostreesetup --nogpg --osname=rhel --remote=edge --url={{ ostree_repo_url }} --ref=rhel/8/x86_64/edge

%post --log=/var/log/anaconda/post-install.log --erroronfail
echo -e 'redhat\tALL=(ALL)\tNOPASSWD: ALL' >> /etc/sudoers
%end
