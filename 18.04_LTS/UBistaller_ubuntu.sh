#!/bin/bash

DIALOG="whiptail"
DIALOG2="dialog"
UBILLING_RELEASE_URL="http://ubilling.net.ua/"
UBILLING_RELEASE_NAME="ub.tgz"
DL_STG_URL="http://ubilling.net.ua/stg/"
DL_STG_NAME="stg-2.409-rc2.tar.gz"
DL_STG_RELEASE="stg-2.409-rc2"
$DIALOG --title "Ubilling installation" --msgbox "This wizard helps you to install Stargazer and Ubilling of the latest stable versions to CLEAN (!) Ubuntu 16.04 or 18.04 distribution" 10 40
clear
$DIALOG --menu "Choose version" 16 50 8 \
           1804 "Ubuntu 18.04 amd64"\
           1604 "Ubuntu 16.04 amd64 now not work!!"\
        2> /tmp/ubarch
clear
#configuring stargazer release
clear
$DIALOG --menu "Choose Stargazer release" 16 50 8 \
                   409RC2 "Stargazer 2.409-rc2 (stable)"\
                   409RC5 "Stargazer 2.409-rc5 (testing)"\
            2> /tmp/stgver
clear
#configuring LAN interface
ALL_IFACES=`ls /sys/class/net | grep -v lo`

INTIF_DIALOG_START="$DIALOG --menu \"Select LAN interface that interracts with your INTERNAL network\" 15 65 6 \\"
INTIF_DIALOG="${INTIF_DIALOG_START}"

for EACH_IFACE in $ALL_IFACES
do
   LIIFACE_MAC=`ip addr show ${EACH_IFACE} | grep ether | awk {'print $2'}`
   LIIFACE_IP=`ip addr show ${EACH_IFACE} | grep inet' '| awk {'print $2'}`
   INTIF_DIALOG="${INTIF_DIALOG}${EACH_IFACE} \\ \"${LIIFACE_IP} - ${LIIFACE_MAC}\" "
done
INTIF_DIALOG="${INTIF_DIALOG} 2> /tmp/ubiface"

sh -c "${INTIF_DIALOG}"
clear 
#configuring internal network
TMP_LAN_IFACE=`cat /tmp/ubiface`
TMP_LAN_NETW=`ip route show | grep ${TMP_LAN_IFACE} | grep -v dhcp | grep -v via | grep src | awk {'print $1'} | cut -f 1 -d "/"`
TMP_LAN_CIDR=`ip route show | grep ${TMP_LAN_IFACE} | grep -v dhcp | grep -v via | grep src | awk {'print $1'} | cut -f 2 -d "/"`
TMP_LAN_IP=`ip addr show ${TMP_LAN_IFACE} | grep inet' '| awk {'print $2'} | cut -f 1 -d "/"`
echo ${TMP_LAN_NETW} > /tmp/ubnetw
echo ${TMP_LAN_CIDR} > /tmp/ubcidr
echo ${TMP_LAN_IP} > /tmp/ubip

#generating mysql password
GEN_MYS_PASS=`dd if=/dev/urandom count=128 bs=1 2>&1 | md5sum | cut -b-8`
echo "mys"${GEN_MYS_PASS} > /tmp/ubmypas

#getting stargazer admin password
GEN_STG_PASS=`dd if=/dev/urandom count=128 bs=1 2>&1 | md5sum | cut -b-8`
echo "stg"${GEN_STG_PASS} > /tmp/ubstgpass


#getting rscriptd encryption password
GEN_RSD_PASS=`dd if=/dev/urandom count=128 bs=1 2>&1 | md5sum | cut -b-8`
echo "rsd"${GEN_RSD_PASS} > /tmp/ubrsd

$DIALOG --title "Setup NAS"   --yesno "Do you want to install firewall/nat/shaper presets for setup all-in-one Billing+NAS server" 10 40
NAS_KERNEL=$?
clear
case $NAS_KERNEL in
0)
#if setup NAS kernel with preconfigured firewall
#configuring WAN interface
ALL_IFACES=`ls /sys/class/net | grep -v lo`

EXTIF_DIALOG_START="$DIALOG --menu \"Select WAN interface for NAT that interracts with Internet\" 15 65 6 \\"
EXTIF_DIALOG="${EXTIF_DIALOG_START}"

for EACH_IFACE in $ALL_IFACES
do
   LIIFACE_MAC=`ip addr show ${EACH_IFACE} | grep ether | awk {'print $2'}`
   LIIFACE_IP=`ip addr show ${EACH_IFACE} | grep inet' '| awk {'print $2'}`
   EXTIF_DIALOG="${EXTIF_DIALOG}${EACH_IFACE} \\ \"${LIIFACE_IP} - ${LIIFACE_MAC}\" "
done

EXTIF_DIALOG="${EXTIF_DIALOG} 2> /tmp/ubextif"

sh -c "${EXTIF_DIALOG}"
clear 
WAN_IFACE=`cat /tmp/ubextif`
;;
1)
WAN_IFACE="none"
;;
esac

LAN_IFACE=`cat /tmp/ubiface`
MYSQL_PASSWD=`cat /tmp/ubmypas`
SERVER_IP=`cat /tmp/ubip`
LAN_NETW=`cat /tmp/ubnetw`
LAN_CIDR=`cat /tmp/ubcidr`
STG_PASS=`cat /tmp/ubstgpass`
RSD_PASS=`cat /tmp/ubrsd`
ARCH=`cat /tmp/ubarch`
STG_VER=`cat /tmp/stgver`
WAN_IP=`cat /tmp/ubextip`

# cleaning temp files
rm -fr /tmp/ubiface
rm -fr /tmp/ubmypas
rm -fr /tmp/ubnetw
rm -fr /tmp/ubcidr
rm -fr /tmp/ubstgpass
rm -fr /tmp/ubrsd
rm -fr /tmp/ubextif
rm -fr /tmp/ubarch
rm -fr /tmp/ubimode
rm -fr /tmp/stgver

#last chance to exit
$DIALOG --title "Check settings"   --yesno "Are all of these settings correct? \n \n LAN interface: ${LAN_IFACE} \n LAN network: ${LAN_NETW}/${LAN_CIDR} \n WAN interface: ${EXT_IF} \n MySQL password: ${MYSQL_PASSWD} \n Stargazer password: ${STG_PASS} \n Rscripd password: ${RSD_PASS} \n System: ${ARCH}" 18 60
AGREE=$?
clear

case $AGREE in
0)
echo "Everything is okay! Installation is starting."
# preparing for installation
mkdir /tmp/ubinstaller/
cp -R ./* /tmp/ubinstaller/
cd /tmp/ubinstaller/
#case $ARCH in
#1804)
#ubuntu 18.04  x64 Release
#;;
#1604)
#ubuntu 16.04  x64 Release
#;;
#esac

#Selecting stargazer release to install
case $STG_VER in
409RC5)
DL_STG_NAME="stg-2.409-rc5.tar.gz"
DL_STG_RELEASE="stg-2.409-rc5"
;;
esac
$DIALOG2 --infobox "package installation in progress." 4 60
#setting mysql passwords
echo mysql-server-5.7 mysql-server/root_password password ${MYSQL_PASSWD} | debconf-set-selections
echo mysql-server-5.7 mysql-server/root_password_again password ${MYSQL_PASSWD} | debconf-set-selections
#deps install
apt -y install dialog mysql-server-5.7 mysql-client-core-5.7 libmysqlclient20 libmysqlclient-dev apache2 expat libexpat1-dev php7.2-mbstring php7.2 php7.2-cli php7.2-mysql php7.2-snmp libapache2-mod-php7.2 isc-dhcp-server build-essential bind9 softflowd arping snmp snmp-mibs-downloader nmap ipset automake libtool graphviz elinks php7.2-curl ipcalc php7.2-gd php7.2-xmlrpc php7.2-imap php7.2-json
a2enmod php7.2
apachectl restart

#add apache childs to sudoers
echo "User_Alias BILLING = www-data" >> /etc/sudoers
echo "BILLING          ALL = NOPASSWD: ALL" >> /etc/sudoers

#installing ipset
modprobe ip_set
echo "Patching mysql conf"
#patch conf mysql
sed -i "/system resource/r /tmp/ubinstaller/config/mysql_apparm" /etc/apparmor.d/usr.sbin.mysqld
apparmor_parser -r /etc/apparmor.d/usr.sbin.mysqld
cp -R /tmp/ubinstaller/config/disable_mysql_strict_mode.cnf /etc/mysql/conf.d/
service mysql restart
echo "stargazer setup"
#stargazer setup
wget http://ubilling.net.ua/stg/${DL_STG_NAME}
#check is stargazer sources download complete
if [ -f ${DL_STG_NAME} ];
then
echo "Stargazer distro download has been completed."
else
echo "=== Error: stargazer sources are not available. Installation is aborted. ==="
exit
fi
$DIALOG2 --infobox "Compiling Stargazer.." 4 60
tar zxvf ${DL_STG_NAME} >> /tmp/ubstg.log
cd ${DL_STG_RELEASE}/projects/stargazer/
./build >> /tmp/ubstg.log 2>> /tmp/ubstg.log
$DIALOG2 --infobox "Compiling Stargazer..." 4 60
make install >> /tmp/ubstg.log 2>> /tmp/ubstg.log
$DIALOG2 --infobox "Compiling Stargazer....." 4 60
cd ../sgconf && ./build && make && make install >> /tmp/ubstg.log 2>> /tmp/ubstg.log
$DIALOG2 --infobox "Compiling Stargazer......." 4 60
cd ../sgconf_xml && ./build && make && make install >> /tmp/ubstg.log 2>> /tmp/ubstg.log
$DIALOG2 --infobox "Stargazer installed." 4 60

#updating stargazer config
cp -f /tmp/ubinstaller/config/stargazer.conf /etc/stargazer/
perl -e "s/newpassword/${MYSQL_PASSWD}/g" -pi /etc/stargazer/stargazer.conf
perl -e "s/secretpassword/${RSD_PASS}/g" -pi /etc/stargazer/stargazer.conf
#updating rules file
echo "ALL     0.0.0.0/0       DIR0" > /etc/stargazer/rules

#starting stargazer first time
stargazer
sleep 2
#mysql -u root -p${MYSQL_PASSWD} stg -e "SHOW TABLES"
#updating admin password
/usr/sbin/sgconf_xml -s localhost -p 5555 -a admin -w 123456 -r " <ChgAdmin Login=\"admin\" password=\"${STG_PASS}\" /> "
killall stargazer
$DIALOG2 --infobox "Ubilling download, unpacking and installation is in progress." 4 60

#downloading and installing Ubilling
cd /var/www/
mkdir billing
cd billing
wget ${UBILLING_RELEASE_URL}${UBILLING_RELEASE_NAME}
if [ -f ${UBILLING_RELEASE_NAME} ];
then
echo "Ubilling download has been completed."
else
echo "=== Error: Ubilling release is not available. Installation is aborted. ==="
exit
fi
tar zxvf ${UBILLING_RELEASE_NAME} >> /tmp/ubweb.log
chmod -R 777 content/ config/ multinet/ exports/ remote_nas.conf
#apply dump
cat /var/www/billing/docs/test_dump.sql | mysql -u root -p${MYSQL_PASSWD} stg
#mysql -u root -p${MYSQL_PASSWD} stg -e "SHOW TABLES"
#updating passwords
perl -e "s/mylogin/root/g" -pi ./config/mysql.ini
perl -e "s/newpassword/${MYSQL_PASSWD}/g" -pi ./config/mysql.ini
perl -e "s/mylogin/root/g" -pi ./userstats/config/mysql.ini
perl -e "s/newpassword/${MYSQL_PASSWD}/g" -pi ./userstats/config/mysql.ini

#hotfix 2.408 admin permissions trouble
cat /tmp/ubinstaller/config/admin_rights_hotfix.sql | mysql -u root  -p stg --password=${MYSQL_PASSWD}
perl -e "s/123456/${STG_PASS}/g" -pi ./config/billing.ini
perl -e "s/123456/${STG_PASS}/g" -pi ./userstats/config/userstats.ini
#updating linux specific things
sed -i "s/\/usr\/local\/bin\/sudo/\/usr\/bin\/sudo/g" ./config/billing.ini
sed -i "s/\/usr\/bin\/top -b/\/usr\/bin\/top -b -n 1/g" ./config/billing.ini
sed -i "s/\/usr\/bin\/grep/\/bin\/grep/g" ./config/billing.ini
sed -i "s/\/usr\/local\/etc\/rc.d\/isc-dhcpd/\/etc\/init.d\/isc-dhcp-server/g" ./config/billing.ini
sed -i "s/\/sbin\/ping/\/bin\/ping/g" ./config/billing.ini
sed -i "s/\/var\/log\/messages/\/var\/log\/dhcpd.log/g" ./config/alter.ini
sed -i "s/\/usr\/local\/sbin\/arping/\/usr\/sbin\/arping/g" ./config/alter.ini
sed -i "s/rl0/${LAN_IFACE}/g" ./config/alter.ini
sed -i "s/\/usr\/local\/bin\/snmpwalk/\/usr\/bin\/snmpwalk/g" ./config/alter.ini
sed -i "s/\/usr\/local\/bin\/snmpset/\/usr\/bin\/snmpset/g" ./config/alter.ini
sed -i "s/\/usr\/local\/bin\/mysqldump/\/usr\/bin\/mysqldump/g" ./config/alter.ini
sed -i "s/\/usr\/local\/bin\/mysql/\/usr\/bin\/mysql/g" ./config/alter.ini
sed -i "s/\/usr\/local\/bin\/nmap/\/usr\/bin\/nmap/g" ./config/alter.ini
#setting up dhcpd
MASK=`ipcalc $LAN_NETW $LAN_CIDR | grep Netmask | awk {'print $2'}`
ln -fs /var/www/billing/multinet/ /etc/dhcp/multinet
sed -i '1 ilocal7.* /var/log/dhcpd.log' /etc/rsyslog.d/50-default.conf
sed -i '2 i&~' /etc/rsyslog.d/50-default.conf
sed -i '1 i/var/log/dhcpd.log' /etc/logrotate.d/rsyslog
service rsyslog restart
echo "INTERFACES=\"${LAN_IFACE}"\" > /etc/default/isc-dhcp-server
sed -i "s/\/etc\/dhcp\/dhcpd.conf/\/var\/www\/billing\/multinet\/dhcpd.conf/g" /etc/init.d/isc-dhcp-server
sed -i "s/\/etc\/dhcp\/dhcpd.conf/\/var\/www\/billing\/multinet\/dhcpd.conf/g" /lib/systemd/system/isc-dhcp-server.service
sed -i "s/\/usr\/local\/etc/\/var\/www\/billing/g"  /var/www/billing/config/dhcp/subnets.template
sed -i "/shared-network/a subnet ${LAN_NETW} netmask ${MASK} {}"  /var/www/billing/config/dhcp/global.template
sed -i "/\/usr\/sbin\/dhcpd mr/r /tmp/ubinstaller/config/dhcpd_apparm" /etc/apparmor.d/usr.sbin.dhcpd
apparmor_parser -r /etc/apparmor.d/usr.sbin.dhcpd
#extractiong presets
cp -fr /var/www/billing/docs/presets/MikroTik/* /etc/stargazer/
cp -fr /tmp/ubinstaller/config/stargazer/* /etc/stargazer/
cat /tmp/ubinstaller/config/config_ini.preconf >> /etc/stargazer/config.ini
chmod a+x /etc/stargazer/*
ln -fs /var/www/billing/remote_nas.conf /etc/stargazer/remote_nas.conf

#ugly hack for starting stargazer without NAS-es
echo "127.0.0.1/32 127.0.0.1" > /etc/stargazer/remote_nas.conf

cp -f /tmp/ubinstaller/config/billing.service /lib/systemd/system
cp -f /tmp/ubinstaller/config/firewall.service /lib/systemd/system
########
sed -i "s/newpassword/${MYSQL_PASSWD}/g" /etc/stargazer/config.ini
sed -i "s/newpassword/${MYSQL_PASSWD}/g" /etc/stargazer/dnswitch.php


#
#post install ugly hacks
#
mkdir /etc/stargazer/dn
chmod 777 /etc/stargazer/dn
ln -fs  /usr/bin/php /usr/local/bin/php 
echo "INTERFACE=\"${LAN_IFACE}\"" >  /etc/default/softflowd
echo "OPTIONS=\"-n ${SERVER_IP}:42111\"" >> /etc/default/softflowd
#make htaccess works
cp -f /tmp/ubinstaller/config/php.ini /etc/php/7.2/cli/
cp -f /tmp/ubinstaller/config/php.ini /etc/php/7.2/apache2/
cp -f /tmp/ubinstaller/config/000-default.conf  /etc/apache2/sites-enabled/
apachectl restart

#installing auto update script
cp -f /tmp/ubinstaller/config/autoubupdate.sh /var/www/
cp -f /tmp/ubinstaller/config/ubapi /etc/ubapi.sh
chmod a+x /etc/ubapi.sh
#updating systemctl
systemctl daemon-reload
systemctl enable softflowd
systemctl enable mysql
systemctl enable isc-dhcp-server
systemctl enable billing
systemctl enable firewall
#clean stargazer sample data before start
echo "TRUNCATE TABLE users" | mysql -u root  -p stg --password=${MYSQL_PASSWD}
echo "TRUNCATE TABLE tariffs" | mysql -u root  -p stg --password=${MYSQL_PASSWD}
echo "All installed"
################
case $NAS_KERNEL in
0)
cp -f /tmp/ubinstaller/config/firewall /etc/firewall.sh
chmod a+x /etc/firewall.sh
cp -f /tmp/ubinstaller/config/shaper.sh /etc/shaper.sh
chmod a+x /etc/shaper.sh
sed -i "s/INTERNAL_IFACE/${LAN_IFACE}/g" /etc/stargazer/config.ini
sed -i "s/EXTERNAL_IFACE/${WAN_IFACE}/g" /etc/stargazer/config.ini
#update settings in firewall sample
sed -i "s/EXTERNAL_IP/${WAN_IP}/g" /etc/firewall.sh
sed -i "s/EXTERNAL_IFACE/${WAN_IFACE}/g" /etc/firewall.sh
sed -i "s/INTERNAL_NETWORK/${LAN_NETW}/g" /etc/firewall.sh
sed -i "s/INTERNAL_MASK/${LAN_CIDR}/g" /etc/firewall.sh
########
sed -i "s/EXTERNAL_IFACE/${WAN_IFACE}/g" /etc/shaper.sh
sed -i "s/INTERNAL_IFACE/${LAN_IFACE}/g" /etc/shaper.sh
;;
1)
cp -f /tmp/ubinstaller/config/firewall_ub /etc/firewall.sh
chmod a+x /etc/firewall.sh
echo "no NAS setup required"
;;
esac

$DIALOG2 --title "Installation complete" --msgbox "Now you can access your web-interface by address http://${SERVER_IP}/ with login and password: admin/demo. Please reboot your server to check correct startup of all services" 15 50
;;
1)
echo "Installation has been aborted"
exit
;;
esac
