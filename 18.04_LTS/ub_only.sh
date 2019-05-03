#!/bin/sh

EXPECTED_ARGS=7
E_BADARGS=65

if [ $# -ne $EXPECTED_ARGS ]
then
  echo "Usage: ubsetup.sh MYSQL_PASSWD STG_PASS RSD_PASS LAN_IFACE LAN_NET LAN_MASK SERVER_IP"
  exit $E_BADARGS
fi


#config section
#===============================================
MYSQL_PASSWD=$1
STG_PASS=$2
RSD_PASS=$3
LAN_IFACE=$4
LAN_NET=$5
LAN_MASK=$6
SERVER_IP=$7
UBILLING_RELEASE_URL="http://ubilling.net.ua/"
UBILLING_RELEASE_NAME="ub.tgz"

#===============================================


#setting mysql passwords
echo mysql-server-5.7 mysql-server/root_password password ${MYSQL_PASSWD} | debconf-set-selections
echo mysql-server-5.7 mysql-server/root_password_again password ${MYSQL_PASSWD} | debconf-set-selections

#deps install
apt -y install mysql-server-5.7 mysql-client-core-5.7 libmysqlclient20 libmysqlclient-dev apache2 expat libexpat1-dev php7.2 php7.2-cli php7.2-mysql php7.2-snmp libapache2-mod-php7.2 isc-dhcp-server build-essential bind9 softflowd arping snmp snmp-mibs-downloader nmap ipset automake libtool graphviz memcached freeradius-mysql elinks php7.2-curl dialog php7.2-gd php7.2-xmlrpc php7.2-imap php7.2-json
#apache php enabling 
a2enmod php7.2
apachectl restart

#add apache childs to sudoers
echo "User_Alias BILLING = www-data" >> /etc/sudoers
echo "BILLING          ALL = NOPASSWD: ALL" >> /etc/sudoers

#installing ipset
modprobe ip_set

# preparing for installation
mkdir /tmp/ubinstaller/
cp -R ./* /tmp/ubinstaller/
cd /tmp/ubinstaller/

#stargazer setup
#mkdir stargazer
#cd /root/stargazer
wget http://ubilling.net.ua/stg/stg-2.409-rc5.tar.gz
tar zxvf stg-2.409-rc5.tar.gz
cd stg-2.409-rc5/projects/stargazer/
./build
make install
cd ../sgconf && ./build && make && make install
cd ../sgconf_xml/ && ./build && make && make install

#updating stargazer config
cp -R /tmp/ubinstaller/config/stargazer.conf /etc/stargazer/
perl -e "s/newpassword/${MYSQL_PASSWD}/g" -pi /etc/stargazer/stargazer.conf
perl -e "s/secretpassword/${RSD_PASS}/g" -pi /etc/stargazer/stargazer.conf
#updating rules file
echo "ALL     0.0.0.0/0       DIR0" > /etc/stargazer/rules

#starting stargazer first time
stargazer
mysql -u root -p${MYSQL_PASSWD} stg -e "SHOW TABLES"
#updating admin password
/usr/sbin/sgconf_xml -s localhost -p 5555 -a admin -w 123456 -r " <ChgAdmin Login=\"admin\" password=\"${STG_PASS}\" /> "
killall stargazer

#downloading and installing Ubilling
cd /var/www/
mkdir billing
cd billing
wget ${UBILLING_RELEASE_URL}${UBILLING_RELEASE_NAME}
tar zxvf ${UBILLING_RELEASE_NAME}
chmod -R 777 content/ config/ multinet/ exports/ remote_nas.conf
#apply dump
cat /var/www/billing/docs/test_dump.sql | mysql -u root -p${MYSQL_PASSWD} stg
mysql -u root -p${MYSQL_PASSWD} stg -e "SHOW TABLES"
#updating passwords
perl -e "s/mylogin/root/g" -pi ./config/mysql.ini
perl -e "s/newpassword/${MYSQL_PASSWD}/g" -pi ./config/mysql.ini
perl -e "s/mylogin/root/g" -pi ./userstats/config/mysql.ini
perl -e "s/newpassword/${MYSQL_PASSWD}/g" -pi ./userstats/config/mysql.ini

#hotfix 2.408 admin permissions trouble
#wget https://raw.github.com/nightflyza/ubuntustaller/master/admin_rights_hotfix.sql
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
ln -fs /var/www/billing/multinet/ /etc/dhcp/multinet
sed -i '1 ilocal7.* /var/log/dhcpd.log' /etc/rsyslog.d/50-default.conf
sed -i '2 i&~' /etc/rsyslog.d/50-default.conf
sed -i '1 i/var/log/dhcpd.log' /etc/logrotate.d/rsyslog
service rsyslog restart
echo "INTERFACES=\"${LAN_IFACE}"\" > /etc/default/isc-dhcp-server
sed -i "s/\/etc\/dhcp\/dhcpd.conf/\/var\/www\/billing\/multinet\/dhcpd.conf/g" /etc/init/isc-dhcp-server.conf
sed -i "s/\/usr\/local\/etc/\/var\/www\/billing/g"  /var/www/billing/config/dhcp/subnets.template
cp -f /tmp/ubinstaller/config/usr.sbin.dhcpd /etc/apparmor.d/
apparmor_parser -r /etc/apparmor.d/usr.sbin.dhcpd
service isc-dhcp-server restart

#extractiong presets
cp -fr /tmp/ubinstaller/config/stargazer/* /etc/stargazer/
chmod a+x /etc/stargazer/*
ln -fs /var/www/billing/remote_nas.conf /etc/stargazer/remote_nas.conf

#ugly hack for starting stargazer without NAS-es
echo "127.0.0.1/32 127.0.0.1" > /etc/stargazer/remote_nas.conf

#updating init.d
cp -f /tmp/ubinstaller/config/ubilling /etc/init.d/ubilling
chmod a+x /etc/init.d/ubilling
cp -f /tmp/ubinstaller/config/firewall_ub.sh /etc/firewall.sh
chmod a+x /etc/firewall.sh
########
sed -i 's/$SHAPER/#$SHAPER/g;s/$BAND/#$BAND/g' /etc/init.d/ubilling
sed -i "s/newpassword/${MYSQL_PASSWD}/g" /etc/stargazer/config.ini
sed -i "s/EXTERNAL_IFACE/${LAN_IFACE}/g" /etc/stargazer/config.ini
sed -i "s/INTERNAL_IFACE/${LAN_IFACE}/g" /etc/stargazer/config.ini
########
sed -i "s/newpassword/${MYSQL_PASSWD}/g" /etc/stargazer/dnswitch.php

update-rc.d ubilling defaults

#
#post install ugly hacks
#
mkdir /etc/stargazer/dn
chmod 777 /etc/stargazer/dn
ln -fs  /usr/bin/php /usr/local/bin/php 
echo "INTERFACE=\"${LAN_IFACE}\"" >  /etc/default/softflowd
echo "OPTIONS=\"-n ${SERVER_IP}:42111\"" >> /etc/default/softflowd
#make bandwithd works - deb packages has broken post install scripts
#make htaccess works
cp -f /tmp/ubinstaller/config/php.ini /etc/php5/cli/
cp -f /tmp/ubinstaller/config/php.ini /etc/php5/apache2/
cp -f /tmp/ubinstaller/config/000-default.conf  /etc/apache2/sites-enabled/
sed -i "s/AllowOverride\ None/AllowOverride\ All/g"   /etc/apache2/sites-enabled/000-default.conf
apachectl restart

#installing auto update script
cp -f /tmp/ubinstaller/config/autoubupdate.sh /var/www/

#clean stargazer sample data before start
echo "TRUNCATE TABLE users" | mysql -u root  -p stg --password=${MYSQL_PASSWD}
echo "TRUNCATE TABLE tariffs" | mysql -u root  -p stg --password=${MYSQL_PASSWD}

echo "All installed"
