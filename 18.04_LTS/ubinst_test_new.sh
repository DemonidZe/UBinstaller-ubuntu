#!/bin/bash

DIALOG="whiptail"
#${DIALOG=dialog}
#"whiptail"

$DIALOG --title "Ubilling installation" --msgbox "This wizard helps you to install Stargazer and Ubilling of the latest stable versions to CLEAN (!) Ubuntu 16.04 or 18.04 distribution" 10 40
clear
$DIALOG --menu "Choose version" 16 50 8 \
           1804 "Ubuntu 18.04 amd64"\
           1604 "Ubuntu 16.04 amd64"\
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
#clear
echo $NAS_KERNEL > /tmp/nas
#if setup NAS kernel with preconfigured firewall
#configuring WAN interface
ALL_IFACES1=`ls /sys/class/net | grep -v lo`

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
EXT_IF=`cat /tmp/ubextif`
;;
1)
EXT_IF="none"
echo $NAS_KERNEL > /tmp/nas
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
EXT_IF=`cat /tmp/ubextif`
#EXT_IP=`cat /tmp/ubextip`

# cleaning temp files
#rm -fr /tmp/ubiface
#rm -fr /tmp/ubmypas
#rm -fr /tmp/ubnetw
#rm -fr /tmp/ubcidr
#rm -fr /tmp/ubstgpass
#rm -fr /tmp/ubrsd
#rm -fr /tmp/ubextif
#rm -fr /tmp/ubarch
#rm -fr /tmp/ubimode
#rm -fr /tmp/stgver

#last chance to exit
$DIALOG --title "Check settings"   --yesno "Are all of these settings correct? \n \n LAN interface: ${LAN_IFACE} \n LAN network: ${LAN_NETW}/${LAN_CIDR} \n WAN interface: ${EXT_IF} \n MySQL password: ${MYSQL_PASSWD} \n Stargazer password: ${STG_PASS} \n Rscripd password: ${RSD_PASS} \n System: ${ARCH} \n Mode: ${UBI_MODE}" 18 60
AGREE=$?
clear

#wget https://raw.github.com/nightflyza/ubuntustaller/master/batchsetup.sh
# params:
# batchsetup.sh MYSQL_PASSWD STG_PASS RSD_PASS LAN_IFACE LAN_NET LAN_MASK WAN_IFACE WAN_IP
#bash ./all_in_one.sh ${MYSQL_PASSWD} ${STG_PASS} ${RSD_PASS}  ${LAN_IF} ${LAN_NETW} ${LAN_CIDR} ${EXT_IF} ${EXT_IP} &>> /var/log/ubuntustaller.log &
#echo "all in one"

$DIALOG --title "Installation complete" --msgbox "Now you can access your web-interface by address http://${SERVER_IP}/ with login and password: admin/demo. Please reboot your server to check correct startup of all services" 15 50
echo "Ubilling"
exit
