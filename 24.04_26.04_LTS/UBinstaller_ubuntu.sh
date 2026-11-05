#!/usr/bin/bash

export LC_ALL=C
export CFLAGS="-std=gnu17"

DIALOG="dialog"
FETCH="/usr/bin/wget"

TARGET_SYSTEM="Ubuntu 24.04 / 26.04 LTS"

APACHE_VERSION="apache24"
APACHE_DATA_PATH="/var/www/html/"
APACHE_CONFIG_DIR="/etc/apache2/"
APACHE_INIT_SCRIPT="/usr/sbin/service apache2"
APACHE_CONFIG_PRESET_NAME="apache2.conf"
APACHE_CONFIG_NAME="apache2.conf"
PHP_CONFIG_PRESET="php8.ini"

DL_PACKAGES_URL="http://ubilling.net.ua/packages/"
DL_PACKAGES_EXT=".tar.gz"
DL_UB_URL="http://ubilling.net.ua/"
DL_UB_NAME="ub.tgz"
DL_STG_URL="http://ubilling.net.ua/stg/"
DL_STG_NAME="stg-2.409.tar.gz"
DL_STG_RELEASE="stg-2.409"

LOG_FILE="/var/log/ubinstaller.log"
STG_PID_FILE="/var/run/stargazer.pid"
STG_WAIT_TIMEOUT=120

wait_stargazer_start() {
    echo -n "Waiting for Stargazer to start" | tee -a ${LOG_FILE}
    WAIT_COUNT=0
    while [ ! -f "${STG_PID_FILE}" ]; do
        echo -n "." | tee -a ${LOG_FILE}
        sleep 1
        WAIT_COUNT=$((WAIT_COUNT + 1))
        if [ $WAIT_COUNT -ge ${STG_WAIT_TIMEOUT} ]; then
            echo " timeout!" | tee -a ${LOG_FILE}
            return 1
        fi
    done
    echo " ok" | tee -a ${LOG_FILE}
    sleep 3
    return 0
}

wait_stargazer_stop() {
    echo -n "Waiting for Stargazer to stop" | tee -a ${LOG_FILE}
    WAIT_COUNT=0
    while [ -f "${STG_PID_FILE}" ]; do
        echo -n "." | tee -a ${LOG_FILE}
        sleep 1
        WAIT_COUNT=$((WAIT_COUNT + 1))
        if [ $WAIT_COUNT -ge ${STG_WAIT_TIMEOUT} ]; then
            echo " timeout!" | tee -a ${LOG_FILE}
            return 1
        fi
    done
    echo " ok" | tee -a ${LOG_FILE}
    sleep 1
    return 0
}

echo "Preparing to installation.."
apt update >> ${LOG_FILE}  2>&1
DEBIAN_FRONTEND=noninteractive apt -y upgrade >> ${LOG_FILE}  2>&1

echo "Installing basic software required for UbuInstaller.."
apt install -y dialog >> ${LOG_FILE}  2>&1
apt install -y net-tools >> ${LOG_FILE}  2>&1
apt install -y gnupg2 >> ${LOG_FILE}  2>&1

clear
$DIALOG --title "Ubilling installation" --msgbox "This wizard helps you to install Stargazer and Ubilling to your server with ${TARGET_SYSTEM}." 10 50
clear

$DIALOG --menu "Choose Ubuntu version" 12 50 4 \
                   2404 "Ubuntu 24.04 LTS amd64"\
                   2604 "Ubuntu 26.04 LTS amd64"\
            2> /tmp/ubver
clear

$DIALOG --menu "Type of Ubilling installation" 10 75 8 \
                   NEW "This is new Ubilling installation"\
                   MIG "Migrating existing Ubilling setup from another server"\
            2> /tmp/insttype
clear

$DIALOG --menu "Choose Ubilling installation channel" 11 54 4 \
                   STABLE "Latest stable release (recommended)"\
                   CURRENT "Nightly build (current development)"\
            2> /tmp/ubchannel
clear

ALL_IFACES=`ls -l /sys/class/net/ | grep ^l | awk '{print $9}' | grep -v lo | tr "\n" " "`

INTIF_DIALOG_START="$DIALOG --menu \"Select LAN interface that interracts with your INTERNAL network\" 15 85 6 \\"
INTIF_DIALOG="${INTIF_DIALOG_START}"

for EACH_IFACE in $ALL_IFACES
do
    LIIFACE_IP=`ifconfig ${EACH_IFACE} | grep "inet " | xargs`
    INTIF_DIALOG="${INTIF_DIALOG}${EACH_IFACE} \\ \"${LIIFACE_IP}\" "
done

INTIF_DIALOG="${INTIF_DIALOG} 2> /tmp/ubiface"

sh -c "${INTIF_DIALOG}"
clear 

TMP_LAN_IFACE=`cat /tmp/ubiface`
TMP_NET_DATA=`netstat -rn -f inet | grep -v UG | grep ${TMP_LAN_IFACE}`
TMP_LAN_NETW=`echo ${TMP_NET_DATA} | cut -f 1 -d " "`
TMP_LAN_CIDR=`ip address show dev ${TMP_LAN_IFACE} | grep "inet " | cut -f 2 -d "/" | cut -f 1 -d " " | xargs`
echo ${TMP_LAN_NETW} > /tmp/ubnetw
echo ${TMP_LAN_CIDR} > /tmp/ubcidr

clear
$DIALOG --title "Setup NAS"   --yesno "Do you want to install firewall/nat/shaper presets for setup all-in-one Billing+NAS server" 10 40
NAS_KERNEL=$?
clear

case $NAS_KERNEL in
0)
ALL_IFACES=`ls -l /sys/class/net/ | grep ^l | awk '{print $9}' | grep -v lo | tr "\n" " "`

EXTIF_DIALOG_START="$DIALOG --menu \"Select WAN interface for NAT that interracts with Internet\" 15 85 6 \\"
EXTIF_DIALOG="${EXTIF_DIALOG_START}"

for EACH_IFACE in $ALL_IFACES
do
   LIIFACE_IP=`ifconfig ${EACH_IFACE} | grep "inet " | xargs`
   EXTIF_DIALOG="${EXTIF_DIALOG}${EACH_IFACE} \\ \"${LIIFACE_IP}\" "
done

EXTIF_DIALOG="${EXTIF_DIALOG} 2> /tmp/ubextif"

sh -c "${EXTIF_DIALOG}"
clear 
EXT_IF=`cat /tmp/ubextif`
;;

1)
EXT_IF="none"
;;
esac

PASSW_MODE=`cat /tmp/insttype`

case $PASSW_MODE in
NEW)
GEN_MYS_PASS=`dd if=/dev/urandom count=128 bs=1 2>&1 | md5sum | cut -b-8`
echo "mys"${GEN_MYS_PASS} > /tmp/ubmypass

GEN_STG_PASS=`dd if=/dev/urandom count=128 bs=1 2>&1 | md5sum | cut -b-8`
echo "stg"${GEN_STG_PASS} > /tmp/ubstgpass

GEN_RSD_PASS=`dd if=/dev/urandom count=128 bs=1 2>&1 | md5sum | cut -b-8`
echo "rsd"${GEN_RSD_PASS} > /tmp/ubrsd

;;
MIG)
clear
$DIALOG --title "MySQL root password"  --inputbox "Enter your previous installation MySQL root password" 8 60 2> /tmp/ubmypass
clear
$DIALOG --title "Stargazer password"  --inputbox "Enter your previous installation Stargazer password" 8 60 2> /tmp/ubstgpass
clear
$DIALOG --title "rscriptd password"  --inputbox "Enter your previous installation rscriptd password" 8 60 2> /tmp/ubrsd
clear
$DIALOG --title "Ubilling serial"  --inputbox "Enter your previous installation Ubilling serial number" 8 60 2> /tmp/ubsrl
;;
esac

LAN_IFACE=`cat /tmp/ubiface`
MYSQL_PASSWD=`cat /tmp/ubmypass`
LAN_NETW=`cat /tmp/ubnetw`
LAN_CIDR=`cat /tmp/ubcidr`
STG_PASS=`cat /tmp/ubstgpass`
RSD_PASS=`cat /tmp/ubrsd`
UB_VER=`cat /tmp/ubver`
ARCH=`hostnamectl | grep System | xargs`
UB_CHANNEL=`cat /tmp/ubchannel`

case $PASSW_MODE in
NEW)
UBSERIAL="auto"
;;
MIG)
UBSERIAL=`cat /tmp/ubsrl`
;;
esac

rm -fr /tmp/ubiface
rm -fr /tmp/ubmypass
rm -fr /tmp/ubnetw
rm -fr /tmp/ubcidr
rm -fr /tmp/ubstgpass
rm -fr /tmp/ubrsd
rm -fr /tmp/ubextif
rm -fr /tmp/ubchannel
rm -fr /tmp/insttype
rm -fr /tmp/ubsrl
rm -fr /tmp/ubver

$DIALOG --title "Check settings"   --yesno "Are all of these settings correct? \n \n LAN interface: ${LAN_IFACE} \n LAN network: ${LAN_NETW}/${LAN_CIDR} \n WAN interface: ${EXT_IF} \n MySQL password: ${MYSQL_PASSWD} \n Stargazer password: ${STG_PASS} \n Rscripd password: ${RSD_PASS} \n System: ${ARCH} (${UB_VER}) \n Ubilling channel: ${UB_CHANNEL}\n Stargazer: ${DL_STG_RELEASE}\n Ubilling serial: ${UBSERIAL}\n" 18 70
AGREE=$?
clear

case $AGREE in
0)
$DIALOG --infobox "Everything is okay! Installation is starting..." 4 60
mkdir -p /usr/local/ubinstaller/
cp -R ./* /usr/local/ubinstaller/
cd /usr/local/ubinstaller/

case $UB_CHANNEL in
STABLE)
;;
CURRENT)
DL_UB_URL="http://snaps.ubilling.net.ua/"
DL_UB_NAME="ub_current.tgz"
;;
esac

$DIALOG --infobox "Software installation is in progress. This takes a while." 4 70

apt install -y software-properties-common dirmngr >> ${LOG_FILE}  2>&1
add-apt-repository -y universe >> ${LOG_FILE}  2>&1
add-apt-repository -y multiverse >> ${LOG_FILE}  2>&1
apt update >> ${LOG_FILE}  2>&1

$DIALOG --infobox "Installing MariaDB" 4 60
$DIALOG --infobox "Installing MariaDB..." 4 60
apt install -y mariadb-server >> ${LOG_FILE}  2>&1
$DIALOG --infobox "Installing MariaDB...." 4 60
apt install -y mariadb-client >> ${LOG_FILE}  2>&1
$DIALOG --infobox "Installing MariaDB....." 4 60
apt install -y libmariadb-dev >> ${LOG_FILE}  2>&1
$DIALOG --infobox "Installing MariaDB......" 4 60
apt install -y libmariadb-dev-compat >> ${LOG_FILE}  2>&1

$DIALOG --infobox "MariaDB installed" 4 60
mariadb --version >> ${LOG_FILE}  2>&1

systemctl start mariadb  >> ${LOG_FILE}  2>&1
systemctl enable mariadb  >> ${LOG_FILE}  2>&1

$DIALOG --infobox "MariaDB startup enabled" 4 60

$DIALOG --infobox "Installing some required software" 4 60
apt install -y expat >> ${LOG_FILE}  2>&1
apt install -y libexpat1-dev >> ${LOG_FILE}  2>&1
apt install -y sudo >> ${LOG_FILE}  2>&1
apt install -y cron >> ${LOG_FILE}  2>&1
systemctl enable cron >> ${LOG_FILE}  2>&1
apt install -y curl >> ${LOG_FILE}  2>&1
$DIALOG --infobox "Installing Apache server" 4 60
apt install -y apache2 >> ${LOG_FILE}  2>&1
apt install -y libapache2-mod-php >> ${LOG_FILE}  2>&1
$DIALOG --infobox "Installing DHCP server" 4 60
apt install -y isc-dhcp-server >> ${LOG_FILE}  2>&1
$DIALOG --infobox "Installing misc software" 4 60
apt install -y build-essential >> ${LOG_FILE}  2>&1
apt install -y bind9 >> ${LOG_FILE}  2>&1
DEBIAN_FRONTEND=noninteractive apt install -y softflowd >> ${LOG_FILE}  2>&1
apt install -y libxmlrpc-c++8-dev >> ${LOG_FILE}  2>&1 || apt install -y libxmlrpc-c++9-dev >> ${LOG_FILE}  2>&1
apt install -y ipset >> ${LOG_FILE}  2>&1
$DIALOG --infobox "Installing memory caching servers" 4 60
apt install -y memcached >> ${LOG_FILE}  2>&1
apt install -y redis >> ${LOG_FILE}  2>&1
systemctl enable redis-server >> ${LOG_FILE}  2>&1
$DIALOG --infobox "Installing PHP and required extensions" 4 60
apt install -y php-cli >> ${LOG_FILE}  2>&1
apt install -y php-mysql >> ${LOG_FILE}  2>&1
apt install -y php-mysqli >> ${LOG_FILE}  2>&1
apt install -y php-mbstring >> ${LOG_FILE}  2>&1
apt install -y php-bcmath >> ${LOG_FILE}  2>&1
apt install -y php-curl >> ${LOG_FILE}  2>&1
apt install -y php-gd >> ${LOG_FILE}  2>&1
apt install -y php-snmp >> ${LOG_FILE}  2>&1
apt install -y php-soap >> ${LOG_FILE}  2>&1
apt install -y php-zip >> ${LOG_FILE}  2>&1
apt install -y php-imap >> ${LOG_FILE}  2>&1
apt install -y php-tokenizer >> ${LOG_FILE}  2>&1
apt install -y php-xml >> ${LOG_FILE}  2>&1
apt install -y php-xmlreader >> ${LOG_FILE}  2>&1
apt install -y php-xmlwriter >> ${LOG_FILE}  2>&1
apt install -y php-simplexml >> ${LOG_FILE}  2>&1
apt install -y php-sqlite3 >> ${LOG_FILE}  2>&1
apt install -y php-sockets >> ${LOG_FILE}  2>&1
apt install -y php-opcache >> ${LOG_FILE}  2>&1
apt install -y php-json >> ${LOG_FILE}  2>&1
apt install -y php-pdo >> ${LOG_FILE}  2>&1
apt install -y php-pdo-sqlite >> ${LOG_FILE}  2>&1
apt install -y php-phar >> ${LOG_FILE}  2>&1
apt install -y php-posix >> ${LOG_FILE}  2>&1
apt install -y php-memcached >> ${LOG_FILE}  2>&1
apt install -y php-redis >> ${LOG_FILE}  2>&1

PHP_VER=`php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;'`
PHP_CONFIG_DIR="/etc/php/${PHP_VER}/apache2/"
PHP_CLI_CONFIG_DIR="/etc/php/${PHP_VER}/cli/"
a2enmod php${PHP_VER} >> ${LOG_FILE}  2>&1

$DIALOG --infobox "Installing some optional software" 4 60
apt install -y graphviz >> ${LOG_FILE}  2>&1
apt install -y vim-tiny >> ${LOG_FILE}  2>&1
apt install -y arping >> ${LOG_FILE}  2>&1
apt install -y elinks >> ${LOG_FILE}  2>&1
apt install -y mc >> ${LOG_FILE}  2>&1
apt install -y nano >> ${LOG_FILE}  2>&1
apt install -y nmap >> ${LOG_FILE}  2>&1
apt install -y mtr >> ${LOG_FILE}  2>&1
apt install -y expect >> ${LOG_FILE}  2>&1
apt install -y bwm-ng >> ${LOG_FILE}  2>&1
apt install -y ifstat >> ${LOG_FILE}  2>&1
apt install -y arpwatch >> ${LOG_FILE}  2>&1
apt install -y git >> ${LOG_FILE}  2>&1
apt install -y ffmpeg >> ${LOG_FILE}  2>&1
apt install -y bmon >> ${LOG_FILE}  2>&1
apt install -y iftop >> ${LOG_FILE}  2>&1
apt install -y netdiag >> ${LOG_FILE}  2>&1
apt install -y htop >> ${LOG_FILE}  2>&1
apt install -y rsyslog >> ${LOG_FILE}  2>&1
apt install -y snmp >> ${LOG_FILE}  2>&1
apt install -y snmp-mibs-downloader >> ${LOG_FILE}  2>&1
apt install -y ipcalc >> ${LOG_FILE}  2>&1

$DIALOG --infobox "Installing FreeRADIUS server" 4 60
apt install -y freeradius freeradius-mysql >> ${LOG_FILE}  2>&1

cd /usr/local/ubinstaller/

$DIALOG --infobox "Stargazer download is in progress." 4 60
$FETCH ${DL_STG_URL}${DL_STG_NAME} >> ${LOG_FILE}  2>&1
if [ -f ${DL_STG_NAME} ];
then
$DIALOG --infobox "Stargazer distro download has been completed." 4 60
else
echo "=== Error: stargazer sources are not available. Installation is aborted. ==="
exit
fi
$DIALOG --infobox "Compiling Stargazer." 4 60
tar zxvf ${DL_STG_NAME} >> ${LOG_FILE}  2>&1
cd ${DL_STG_RELEASE}/projects/stargazer/ 
./build >> ${LOG_FILE}  2>&1
/usr/bin/gmake install >> ${LOG_FILE}  2>&1
$DIALOG --infobox "Compiling Stargazer..." 4 60
cd ../sgconf 
./build >> ${LOG_FILE}  2>&1
/usr/bin/gmake >> ${LOG_FILE}  2>&1
/usr/bin/gmake install >> ${LOG_FILE}  2>&1
$DIALOG --infobox "Compiling Stargazer...." 4 60
cd ../sgconf_xml/ 
./build >> ${LOG_FILE}  2>&1
/usr/bin/gmake >> ${LOG_FILE}  2>&1
$DIALOG --infobox "Compiling Stargazer....." 4 60
/usr/bin/gmake install >> ${LOG_FILE}  2>&1
$DIALOG --infobox "Stargazer installed." 4 60

${APACHE_INIT_SCRIPT} stop

cd /usr/local/ubinstaller/configs/
cp -R ${APACHE_CONFIG_PRESET_NAME} ${APACHE_CONFIG_DIR}${APACHE_CONFIG_NAME}
mkdir -p /etc/systemd/system/apache2.service.d
cp -R apache2-systemd.conf /etc/systemd/system/apache2.service.d/ubilling.conf
systemctl daemon-reload
cp -R ${PHP_CONFIG_PRESET} ${PHP_CONFIG_DIR}php.ini
cp -R ${PHP_CONFIG_PRESET} ${PHP_CLI_CONFIG_DIR}php.ini
cp -R stargazer.conf /etc/stargazer/

cp -R sudoers_preset /etc/sudoers.d/ubilling
chmod 0440 /etc/sudoers.d/ubilling

cp -R inside.html ${APACHE_DATA_PATH}/index.html

service mariadb stop
cp -R 50-server.cnf /etc/mysql/mariadb.conf.d/50-server.cnf
if [ -d /var/lib/mariadb ] && [ ! -d /var/lib/mysql ]; then
    perl -e "s/\/var\/lib\/mysql/\/var\/lib\/mariadb/g" -pi /etc/mysql/mariadb.conf.d/50-server.cnf
fi
service mariadb start

${APACHE_INIT_SCRIPT} start

mysqladmin -u root password ${MYSQL_PASSWD}

$DIALOG --infobox "Ubilling download, unpacking and installation is in progress." 4 60
cd /usr/local/ubinstaller/
$FETCH ${DL_UB_URL}${DL_UB_NAME} >> ${LOG_FILE}  2>&1
if [ -f ${DL_UB_NAME} ];
then
$DIALOG --infobox "Ubilling download has been completed." 4 60
else
echo "=== Error: Ubilling release is not available. Installation is aborted. ==="
exit
fi

mkdir ${APACHE_DATA_PATH}billing/
cp ${DL_UB_NAME} ${APACHE_DATA_PATH}billing/
cd ${APACHE_DATA_PATH}billing/
tar zxvf ${DL_UB_NAME} >> ${LOG_FILE}  2>&1
chmod -R 777 content/ config/ multinet/ exports/ remote_nas.conf 
chmod -R 777 userstats/config/

perl -e "s/mylogin/root/g" -pi ./config/mysql.ini
perl -e "s/newpassword/${MYSQL_PASSWD}/g" -pi ./config/mysql.ini
perl -e "s/mylogin/root/g" -pi ./userstats/config/mysql.ini
perl -e "s/newpassword/${MYSQL_PASSWD}/g" -pi ./userstats/config/mysql.ini
perl -e "s/rl0/${LAN_IFACE}/g" -pi ./config/alter.ini

perl -e "s/newpassword/${MYSQL_PASSWD}/g" -pi /etc/stargazer/stargazer.conf
perl -e "s/secretpassword/${RSD_PASS}/g" -pi /etc/stargazer/stargazer.conf
perl -e "s/newpassword/${MYSQL_PASSWD}/g" -pi ./docs/presets/MikroTik/config.ini
perl -e "s/mylogin/root/g" -pi ./docs/openpayz/config/mysql.ini
perl -e "s/newpassword/${MYSQL_PASSWD}/g" -pi ./docs/openpayz/config/mysql.ini

perl -e "s/\/usr\/local\/bin\/sudo/\/usr\/bin\/sudo/g" -pi ./config/billing.ini
perl -e "s/\/usr\/bin\/top -b/\/usr\/bin\/top -b -n1/g" -pi ./config/billing.ini
perl -e "s/\/usr\/local\/etc\/rc.d\/isc-dhcpd/\/etc\/init.d\/isc-dhcp-server/g" -pi ./config/billing.ini
perl -e "s/\/sbin\/ping/\/usr\/bin\/ping/g" -pi ./config/billing.ini
perl -e "s/\/usr\/local\/bin\/wget/\/usr\/bin\/wget/g" -pi ./config/billing.ini
perl -e "s/\/usr\/local\/bin\/expect/\/usr\/bin\/expect/g" -pi ./config/billing.ini

perl -e "s/\/usr\/local\/bin\/mysqldump/\/usr\/bin\/mysqldump/g" -pi ./config/alter.ini
perl -e "s/\/usr\/local\/bin\/mysql/\/usr\/bin\/mysql/g" -pi ./config/alter.ini
perl -e "s/\/usr\/local\/bin\/snmpset/\/usr\/bin\/snmpset/g" -pi ./config/alter.ini
perl -e "s/\/usr\/local\/bin\/snmpwalk/\/usr\/bin\/snmpwalk/g" -pi ./config/alter.ini
perl -e "s/\/usr\/local\/bin\/nmap/\/usr\/bin\/nmap/g" -pi ./config/alter.ini
perl -e "s/\/usr\/local\/bin\/radclient/\/usr\/bin\/radclient/g" -pi ./config/alter.ini
perl -e "s/\/usr\/local\/sbin\/arping/\/usr\/sbin\/arping/g" -pi ./config/alter.ini
perl -e "s/-c 10 -w 20000/-c 10 -W 0.1/g" -pi ./config/alter.ini
perl -e "s/Debian GNU\/Linux 13 \(trixie\)/Ubuntu/g" -pi ./api/libs/api.crontabeditor.php

chmod -R 777 /var/log/apache2

$DIALOG --infobox "Creating initial Stargazer DB" 4 60
cat docs/dumps/stargazer.sql | /usr/bin/mysql -u root --password=${MYSQL_PASSWD} >> ${LOG_FILE}  2>&1

$DIALOG --infobox "Starting Stargazer" 4 60
/usr/sbin/stargazer
if ! wait_stargazer_start; then
    echo "=== Fatal error: Stargazer failed to start. Installation is aborted. ===" | tee -a ${LOG_FILE}
    $DIALOG --msgbox "Fatal error: Stargazer failed to start. Installation is aborted." 8 60
    exit 1
fi

/usr/sbin/sgconf_xml -s localhost -p 5555 -a admin -w 123456 -r " <ChgAdmin Login=\"admin\" password=\"${STG_PASS}\" /> " >> ${LOG_FILE}  2>&1
$DIALOG --infobox "Stargazer default password changed." 4 60
$DIALOG --infobox "Stopping Stargazer." 4 60
killall stargazer
wait_stargazer_stop

$DIALOG --infobox "Restoring Ubilling database" 4 60
cat docs/dumps/ubilling.sql | /usr/bin/mysql -u root  -p stg --password=${MYSQL_PASSWD} >> ${LOG_FILE}  2>&1

$DIALOG --infobox "Installing OpenPayz database preset" 4 60
cat docs/dumps/openpayz.sql | /usr/bin/mysql -u root  -p stg --password=${MYSQL_PASSWD} >> ${LOG_FILE}  2>&1

cat /usr/local/ubinstaller/configs/admin_rights_hotfix.sql | /usr/bin/mysql -u root  -p stg --password=${MYSQL_PASSWD}
perl -e "s/123456/${STG_PASS}/g" -pi ./config/billing.ini
perl -e "s/123456/${STG_PASS}/g" -pi ./docs/openpayz/config/openpayz.ini

cat /usr/local/ubinstaller/configs/rsyslog.preconf >> /etc/rsyslog.conf
touch /var/log/dhcpd.log
chown syslog:adm /var/log/dhcpd.log 2>/dev/null || true
chmod 666 /var/log/dhcpd.log
cp -R /usr/local/ubinstaller/configs/logrotate-dhcpd /etc/logrotate.d/ubilling-dhcpd
systemctl restart rsyslog >> ${LOG_FILE}  2>&1
perl -e "s/NMLEASES = \/var\/log\/messages/NMLEASES = \/var\/log\/dhcpd.log/g" -pi ./config/alter.ini
$DIALOG --infobox "dhcpd logging configured." 4 60

touch ./exports/FIRST_INSTALL
chmod 777 ./exports/FIRST_INSTALL

cp -R /usr/local/ubinstaller/configs/ubapi /bin/
chmod a+x /bin/ubapi
$DIALOG --infobox "remote API wrapper installed" 4 60

$DIALOG --infobox "Starting stargazer" 4 60
/usr/sbin/stargazer
if ! wait_stargazer_start; then
    echo "=== Fatal error: Stargazer failed to start. Installation is aborted. ===" | tee -a ${LOG_FILE}
    $DIALOG --msgbox "Fatal error: Stargazer failed to start. Installation is aborted." 8 60
    exit 1
fi

cd ${APACHE_DATA_PATH}billing
if [ -f ./docs/crontab/crontab.preconf ];
then

case $PASSW_MODE in
NEW)
/usr/bin/curl -o /dev/null "http://127.0.0.1/billing/?module=remoteapi&action=identify&param=save" >> ${LOG_FILE}  2>&1
sleep 3
if [ ! -s ./exports/ubserial ]; then
    echo "=== Fatal error: failed to generate new Ubilling serial number. Installation is aborted. ===" | tee -a ${LOG_FILE}
    $DIALOG --msgbox "Fatal error: failed to generate new Ubilling serial number. Installation is aborted." 8 60
    exit 1
fi
NEW_UBSERIAL=`cat ./exports/ubserial`
if [ -z "${NEW_UBSERIAL}" ]; then
    echo "=== Fatal error: generated Ubilling serial number is empty. Installation is aborted. ===" | tee -a ${LOG_FILE}
    $DIALOG --msgbox "Fatal error: generated Ubilling serial number is empty. Installation is aborted." 8 60
    exit 1
fi
$DIALOG --infobox "New Ubilling serial generated: ${NEW_UBSERIAL}" 4 60
;;
MIG)
NEW_UBSERIAL=${UBSERIAL}
if [ -z "${NEW_UBSERIAL}" ]; then
    echo "=== Fatal error: Ubilling serial number is empty. Installation is aborted. ===" | tee -a ${LOG_FILE}
    $DIALOG --msgbox "Fatal error: Ubilling serial number is empty. Installation is aborted." 8 60
    exit 1
fi
$DIALOG --infobox "Using Ubilling serial: ${NEW_UBSERIAL}" 4 60
;;
esac

echo "OK: new Ubilling serial ${NEW_UBSERIAL}" >> ${LOG_FILE}  2>&1

crontab ./docs/crontab/crontab.preconf
$DIALOG --infobox "Installing default crontab preset" 4 60
perl -e "s/UB000000000000000000000000000000000/${NEW_UBSERIAL}/g" -pi /bin/ubapi
$DIALOG --infobox "New serial installed into ubapi wrapper" 4 60
perl -e "s/UB000000000000000000000000000000000/${NEW_UBSERIAL}/g" -pi ./userstats/config/userstats.ini
$DIALOG --infobox "Serial installed into userstats config" 4 60
else
echo "Looks like this Ubilling release is not supporting automatic crontab configuration"
fi

cd ${APACHE_DATA_PATH}billing
if [ -f ./docs/webspeed/speed_hta ];
then
cp -R ./docs/webspeed/speed_hta ${APACHE_DATA_PATH}billing/.htaccess
else
echo "Looks like this Ubilling release does not containing default htaccess preset"
fi

cd ${APACHE_DATA_PATH}billing
cp -R ./docs/multigen/raddb3/* /etc/freeradius/3.0/
cp -R ./docs/multigen/debian/radiusd.conf /etc/freeradius/3.0/radiusd.conf
RADVER=`freeradius -v | grep "radiusd: FreeRADIUS Version" | awk '{print $4}' | tr -d ,`
$DIALOG --infobox "Configuring FreeRADIUS ${RADVER} and MultiGen" 4 70
perl -e "s/\/usr\/local\/share\/freeradius\/dictionary/\/usr\/share\/freeradius\/dictionary/g" -pi /etc/freeradius/3.0/dictionary
perl -e "s/\/usr\/local\/etc\/raddb\/dictionary_preset/\/etc\/freeradius\/3.0\/dictionary_preset/g" -pi /etc/freeradius/3.0/dictionary
cat ./docs/multigen/dump.sql | /usr/bin/mysql -u root  -p stg --password=${MYSQL_PASSWD}
cat ./docs/multigen/radius3_fix.sql | /usr/bin/mysql -u root  -p stg --password=${MYSQL_PASSWD}
perl -e "s/yourmysqlpassword/${MYSQL_PASSWD}/g" -pi /etc/freeradius/3.0/sql.conf

$DIALOG --infobox "Installing Sphinx search service" 4 60
cd /opt
wget -T 10 -t 2 http://sphinxsearch.com/files/sphinx-3.4.1-efbcc65-linux-amd64.tar.gz >> ${LOG_FILE}  2>&1 || wget -O sphinx-3.4.1-efbcc65-linux-amd64.tar.gz "https://web.archive.org/web/20241002215257id_/http://sphinxsearch.com/files/sphinx-3.4.1-efbcc65-linux-amd64.tar.gz" >> ${LOG_FILE}  2>&1
tar zxvf sphinx-3.4.1-efbcc65-linux-amd64.tar.gz >> ${LOG_FILE}  2>&1
mv sphinx-3.4.1 sphinx
cd sphinx
mkdir -p sphinxdata/logs
touch sphinxdata/logs/searchd.log
cp -R ${APACHE_DATA_PATH}billing/docs/sphinxsearch/sphinx3.conf /opt/sphinx/etc/sphinx.conf
perl -e "s/rootpassword/${MYSQL_PASSWD}/g" -pi /opt/sphinx/etc/sphinx.conf
/opt/sphinx/bin/indexer --config /opt/sphinx/etc/sphinx.conf --all >> ${LOG_FILE}  2>&1
/opt/sphinx/bin/searchd --config /opt/sphinx/etc/sphinx.conf >> ${LOG_FILE}  2>&1
cp -R /usr/local/ubinstaller/configs/searchd.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable searchd.service >> ${LOG_FILE}  2>&1

$DIALOG --infobox "Stopping stargazer" 4 60
killall stargazer
wait_stargazer_stop

cp -R /usr/local/ubinstaller/configs/stargazer.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable stargazer.service >> ${LOG_FILE}  2>&1

case $NAS_KERNEL in
0)
$DIALOG --infobox "Installing NAS presets" 4 60
cd /usr/local/ubinstaller/
cat configs/sysctl.preconf >> /etc/sysctl.conf
cp -R configs/furrywall /etc/
chmod a+x /etc/furrywall
perl -e "s/INTERNAL_INTERFACE/${LAN_IFACE}/g" -pi /etc/furrywall
perl -e "s/EXTERNAL_INTERFACE/${EXT_IF}/g" -pi /etc/furrywall
perl -e "s/INTERNAL_NETWORK/${LAN_NETW}/g" -pi /etc/furrywall
perl -e "s/INTERNAL_CIDR/${LAN_CIDR}/g" -pi /etc/furrywall
cp -R configs/furrywall.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable furrywall.service >> ${LOG_FILE}  2>&1
cp -R configs/softflowd.preconf /etc/softflowd/default.conf
perl -e "s/INTERNAL_INTERFACE/${LAN_IFACE}/g" -pi /etc/softflowd/default.conf
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
mkdir -p /etc/sysctl.d
cp -R configs/sysctl.preconf /etc/sysctl.d/99-ubilling.conf
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.d/99-ubilling.conf

cd ${APACHE_DATA_PATH}billing/
cp -f docs/presets/Debian/etc/stargazer/* /etc/stargazer/
chmod a+x /etc/stargazer/*
perl -e "s/mylogin/root/g" -pi /etc/stargazer/config
perl -e "s/newpassword/${MYSQL_PASSWD}/g" -pi /etc/stargazer/config
perl -e "s/INTERNAL_INTERFACE/${LAN_IFACE}/g" -pi /etc/stargazer/OnConnect
perl -e "s/EXTERNAL_INTERFACE/${EXT_IF}/g" -pi /etc/stargazer/OnConnect
perl -e "s/INTERNAL_INTERFACE/${LAN_IFACE}/g" -pi /etc/stargazer/OnDisconnect
perl -e "s/EXTERNAL_INTERFACE/${EXT_IF}/g" -pi /etc/stargazer/OnDisconnect

;;
1)
$DIALOG --infobox "No NAS presets required" 4 60
;;
esac

mkdir /etc/stargazer/dn
chmod -R 777 /etc/stargazer/dn
mkdir ${APACHE_DATA_PATH}billing/content/dn
chmod 777 ${APACHE_DATA_PATH}billing/content/dn
ln -fs /usr/bin/php /usr/local/bin/php
cp -R /usr/local/ubinstaller/configs/dhcp_preset /etc/default/isc-dhcp-server
perl -e "s/LAN_IFACE/${LAN_IFACE}/g" -pi /etc/default/isc-dhcp-server
if [ -f /etc/apparmor.d/usr.sbin.dhcpd ]; then
    if ! grep -q "/var/www/html/billing/multinet" /etc/apparmor.d/usr.sbin.dhcpd; then
        sed -i "/\/usr\/sbin\/dhcpd mr/r /usr/local/ubinstaller/configs/dhcpd_apparm" /etc/apparmor.d/usr.sbin.dhcpd
    fi
    apparmor_parser -r /etc/apparmor.d/usr.sbin.dhcpd >> ${LOG_FILE}  2>&1
fi
if [ -f /etc/apparmor.d/usr.sbin.mysqld ]; then
    if ! grep -q "sys_resource" /etc/apparmor.d/usr.sbin.mysqld; then
        sed -i "/system resource/r /usr/local/ubinstaller/configs/mysql_apparm" /etc/apparmor.d/usr.sbin.mysqld
    fi
    apparmor_parser -r /etc/apparmor.d/usr.sbin.mysqld >> ${LOG_FILE}  2>&1
fi
systemctl reload apparmor >> ${LOG_FILE}  2>&1
systemctl enable isc-dhcp-server >> ${LOG_FILE}  2>&1
ln -fs /var/www/html/billing/multinet /usr/local/etc/multinet
ln -fs ${APACHE_DATA_PATH}billing/remote_nas.conf /etc/stargazer/remote_nas.conf

$DIALOG --infobox "Configuring NTP sync" 4 60
if [ -f /etc/systemd/timesyncd.conf ]; then
    if ! grep -q "ntp.ubilling.net.ua" /etc/systemd/timesyncd.conf; then
        echo "NTP=ntp.ubilling.net.ua" >> /etc/systemd/timesyncd.conf
    fi
    systemctl enable systemd-timesyncd >> ${LOG_FILE}  2>&1
    systemctl restart systemd-timesyncd >> ${LOG_FILE}  2>&1
elif [ -d /etc/chrony/sources.d ]; then
    echo "pool ntp.ubilling.net.ua iburst" > /etc/chrony/sources.d/ubilling.sources
    systemctl enable chrony >> ${LOG_FILE}  2>&1
    systemctl restart chrony >> ${LOG_FILE}  2>&1
fi

cd ${APACHE_DATA_PATH}billing/
if [ -f ./docs/presets/Debian/ubautoupgrade.sh ];
then
cp -R ./docs/presets/Debian/ubautoupgrade.sh /bin/
chmod a+x /bin/ubautoupgrade.sh
else
echo "Looks like this Ubilling release does not containing automatic upgrade preset"
fi

$DIALOG --title "Ubilling installation has been completed" --msgbox "Now you can access your web-interface by address http://server_ip/billing/ with login and password: admin/demo. Please reboot your server to check correct startup of all services" 15 50

;;
1)
echo "Installation has been aborted"
exit
;;
esac
