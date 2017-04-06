#!/usr/bin/env bash
echoerror() {
    printf "\033[1;31m${RC} * ERROR${EC}: $@\033[0m\n" 1>&2;
}

#此cobbler 需要管理的网段
DHCP_RANGE=10.3.1.10,10.3.252.252

#cobbler 的 ip 一般为本机ip
SERVER=`LC_ALL=C /sbin/ifconfig  | grep 'inet'| grep -v '127.0.0.1' |head -n1 |tr -s ' '|cut -d ' ' -f3 | cut -d: -f2`
if [ "$SERVER" == '' ]; then
    echoerror "cobbler 的 ip 为空"
    exit 1
fi

if [ ! -f /root/.ssh/id_rsa.pub ]; then
	echoerror "root的为空 此key用来免登其它机器 下面自动生成"
	ssh-keygen -t rsa -f /root/.ssh/id_rsa -N ''
fi

yum -y install xinetd tftp-server cobbler cobbler-web dnsmasq ansible

chkconfig iptables off
service iptables stop
iptables -F

echo 1 > /proc/sys/net/ipv4/ip_forward
sed -i 's/net.ipv4.ip_forward = 0/net.ipv4.ip_forward = 1/' /etc/sysctl.conf

chkconfig httpd on
chkconfig cobblerd on
chkconfig dnsmasq on

sed -i '/disable/c\\tdisable\t\t\t= no' /etc/xinetd.d/tftp

service xinetd start
service cobblerd start
service httpd start

cobbler get-loaders


sed -i 's/authn_denyall/authn_configfile/g' /etc/cobbler/modules.conf

#修改cobbler web登录密码
#htdigest /etc/cobbler/users.digest "Cobbler" cobbler

#修改 dnsmasq.template
sed -i 's/dhcp-range=192.168.1.5,192.168.1.200/dhcp-range='$DHCP_RANGE'/g' /etc/cobbler/dnsmasq.template


#修改moddules.conf
sed -i 's/module = manage_bind/module = manage_dnsmasq/g' /etc/cobbler/modules.conf
sed -i 's/module = manage_isc/module = manage_dnsmasq/g' /etc/cobbler/modules.conf


sed -i 's/^[[:space:]]\+/ /' /etc/cobbler/settings
sed -i 's/allow_dynamic_settings: 0/allow_dynamic_settings: 1/g' /etc/cobbler/settings

service cobblerd restart
service  httpd restart

cobbler setting edit --name=server --value=$SERVER

cobbler setting edit --name=pxe_just_once --value=1

cobbler setting edit --name=next_server --value=$SERVER

cobbler setting edit --name=manage_rsync --value=1
cobbler setting edit --name=manage_dhcp --value=1
cobbler setting edit --name=manage_dns --value=1

cobbler setting edit --name=default_virt_bridge --value=br0
cobbler setting edit --name=default_virt_file_size --value=2048
cobbler setting edit --name=default_virt_disk_driver --value=raw
cobbler setting edit --name=default_virt_type --value=kvm
cobbler setting edit --name=default_virt_ram --value=4096

cobbler setting edit --name=default_name_servers --value=[114.114.114.114]
cobbler setting edit --name=scm_track_enabled --value=1

cobbler setting edit --name=default_kickstart --value=/var/lib/cobbler/kickstarts/base.ks

cobbler setting edit --name=webdir --value=/data/cobbler


sed -i 's|/var/www/html|/data/cobbler|g' /etc/httpd/conf/httpd.conf 
sed -i 's|/var/www/cobbler|/data/cobbler|g' /etc/httpd/conf.d/cobbler.conf

#移动目录
cp -r /var/www/cobbler /data/

service cobblerd restart

cobbler repo add --name=centos --breed=yum --mirror=http://mirrors.ustc.edu.cn/centos/7.2.1511/os/x86_64/
cobbler repo add --name=extras --breed=yum --mirror=http://mirrors.ustc.edu.cn/centos/7.2.1511/extras/x86_64/
cobbler repo add --name=kvm-common --breed=yum --mirror=http://mirrors.ustc.edu.cn/centos/7.2.1511/virt/x86_64/kvm-common/
cobbler repo add --name=ceph-hammer --breed=yum --mirror=http://mirrors.ustc.edu.cn/centos/7.2.1511/storage/x86_64/ceph-hammer/
cobbler repo add --name=updates --breed=yum --mirror=http://mirrors.ustc.edu.cn/centos/7.2.1511/updates/x86_64/
cobbler repo add --name=glusterfs --breed=yum --mirror=http://mirrors.ustc.edu.cn/centos/7.2.1511/storage/x86_64/gluster-3.7/
cobbler repo add --name=epel --mirror=http://mirrors.ustc.edu.cn/epel/7/x86_64/ --arch=x86_64 --breed=yum
cobbler repo add --name=cloudera --mirror=http://archive-primary.cloudera.com/cdh5/redhat/7/x86_64/cdh/5/ --arch=x86_64 --breed=yum
cobbler repo add --name=cloudera-kudu --mirror=http://archive.cloudera.com/beta/kudu/redhat/7/x86_64/kudu/1/ --arch=x86_64 --breed=yum
cobbler repo add --name=cloudera-impala-kudu --mirror=http://archive.cloudera.com/beta/impala-kudu/redhat/7/x86_64/impala-kudu/1/ --arch=x86_64 --breed=yum
cobbler repo add --name=cloudera-gplextras5 --mirror=https://archive.cloudera.com/gplextras5/redhat/7/x86_64/gplextras/5/ --arch=x86_64 --breed=yum
cobbler repo add --name=percona --mirror=http://repo.percona.com/release/centos/latest/RPMS/x86_64/ --arch=x86_64 --breed=yum
cobbler repo add --name=mesosphere --mirror=http://repos.mesosphere.io/el/7/x86_64 --arch=x86_64 --breed=yum

cobbler distro add --name=centos --kernel=http://mirrors.ustc.edu.cn/centos/7.2.1511/os/x86_64/images/pxeboot/vmlinuz --initrd=http://mirrors.ustc.edu.cn/centos/7.2.1511/os/x86_64/images/pxeboot/initrd.img --arch=x86_64 --kopts="selinux=disabled"

#添加系统ks类型
cobbler profile add --name=base --kickstart=/var/lib/cobbler/kickstarts/base.ks --distro=centos --repos="centos extras kvm-common ceph-hammer glusterfs updates cloudera cloudera-kudu cloudera-impala-kudu cloudera-gplextras5 epel  mesosphere percona" 
cobbler profile add --name=mysql --kickstart=/var/lib/cobbler/kickstarts/mysql.ks --distro=centos --repos="centos extras kvm-common ceph-hammer glusterfs updates cloudera cloudera-kudu cloudera-impala-kudu cloudera-gplextras5 epel  mesosphere percona" 
cobbler profile add --name=lvs --kickstart=/var/lib/cobbler/kickstarts/lvs.ks --distro=centos --repos="centos extras kvm-common ceph-hammer glusterfs updates cloudera cloudera-kudu cloudera-impala-kudu cloudera-gplextras5 epel  mesosphere percona" 
#docker
cobbler profile add --name=docker --ksmeta='host_type=docker' --kickstart=/var/lib/cobbler/kickstarts/base.ks --distro=centos --repos="centos extras kvm-common ceph-hammer glusterfs updates cloudera cloudera-kudu cloudera-impala-kudu cloudera-gplextras5  epel  mesosphere percona"  
#kvm
cobbler profile add --name=kvm --ksmeta='host_type=kvm' --kickstart=/var/lib/cobbler/kickstarts/base.ks --distro=centos --repos="centos extras kvm-common ceph-hammer glusterfs updates cloudera cloudera-kudu cloudera-impala-kudu cloudera-gplextras5 epel  mesosphere percona" 
#同步配置
cobbler sync

systemctl restart httpd 
systemctl restart cobblerd 
systemctl restart dnsmasq 

#同步仓库
cobbler reposync

#跨机房部署
#cobbler replicate –master=cobbler-ns.meizu.mz  –distros=* –profiles=* –systems=* –repos-* –images=* --prune

#自动配raid 原理是先装设置raid的系统 然后再装对应的业务系统
#wget https://downloads.dell.com/FOLDER04162229M/1/DTK_5.5.0_2372_Linux64_A00.iso -O /tmp/DTK_5.5.0_2372_Linux64_A00.iso
#mount -o loop /tmp/DTK_5.5.0_2372_Linux64_A00.iso /mnt
#cp /mnt/* /data/cobbler/ks_mirror/dtk
#mkdir /vat/lib/tftpboot/raidcfg
#cp raid.sh /vat/lib/tftpboot/raidcfg
#cobbler distro add --name=autoraid --kernel=/data/cobbler/ks_mirror/dtk/isolinux/SA.1 --initrd=/data/cobbler/ks_mirror/dtk/isolinux/SA.2 --kopts="share_type=tftp share_location=/raidcfg share_script=raid.sh tftp_ip=$SERVER"
#cobbler profile add --name=autoraid --distro=autoraid
#cobbler system add --name=00:24:E8:64:24:59 --profile=autoraid --mac=00:24:E8:64:24:59

#添加需要安装系统的节点 和 配置eth0 eth1 . cobbler会把 dns-name和ip写入DNS记录中，用于DNS解析
#bound
#cobbler system add --name=192.168.98.136 --profile=centos6.6 --hostname=GZNS-NGINX-161-32 --dns-name=GZNS-NGINX-161-32.meizu.mz --interface=bond0 --interface-type=bond --bonding-opts="mode=active-backup miimon=100" --ip-address=192.168.98.136 --subnet=255.255.255.0 --gateway=192.168.98.128 --static=1 --static-routes="192.168.1.0/16:192.168.1.1 172.16.0.0/16:172.16.0.1"
#cobbler system edit --name=192.168.98.136 --interface=eth0 --mac=00:50:56:33:77:19 --interface-type=bond_slave --interface-master=bond0
#cobbler system edit --name=192.168.98.136 --interface=eth1 --mac=00:50:56:33:FC:99 --interface-type=bond_slave --interface-master=bond0

#docker host
#cobbler system add --name=192.168.10.161 --hostname=GZNS-NGINX-161-32 --dns-name=GZNS-NGINX-161-32.meizu.mz  --mac=00:24:E8:64:24:59 --ip-address=192.168.10.161 --subnet=255.255.255.0 --gateway=192.168.10.5 --interface=eth0 --static=1 --profile=docker --ksmeta="host_type=docker" --hostname=test.meizu.com --name-servers=192.168.10.160

#kvm host
#cobbler system add --name=192.168.10.161 --hostname=GZNS-NGINX-161-32 --dns-name=GZNS-NGINX-161-32.meizu.mz --mac=00:24:E8:64:24:59 --ip-address=192.168.10.161 --subnet=255.255.255.0 --gateway=192.168.10.5 --interface=eth0 --static=1 --profile=kvm --ksmeta="host_type=kvm" --hostname=test.meizu.com --name-servers=192.168.10.160
