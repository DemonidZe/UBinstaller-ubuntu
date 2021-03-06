#!/bin/sh

#set -x
/sbin/modprobe ip_conntrack
/sbin/modprobe ip_conntrack_ftp
/sbin/modprobe ip_nat_ftp

# Обьявляем где у нас лежит IPTABLES
IPT="/sbin/iptables"
IPS="/sbin/ipset"
# Включаем пересылку пакетов нашим роутером
echo 1 > /proc/sys/net/ipv4/ip_forward
case $1 in
start)
# удаляем все имеющиеся правила
$IPT -F
$IPT -X
$IPT -F -t nat
$IPT -F -t mangle
$IPT -F -t filter
#$IPS -F blacklist
#$IPS -X blacklist
$IPS -F FORW 
$IPS -X FORW
$IPS -F DISCON
$IPS -X DISCON
#$IPS -N blacklist iphash
$IPS -N FORW iphash
$IPS -N DISCON iphash 
# Стандартные действия
$IPT -P INPUT ACCEPT
$IPT -P OUTPUT ACCEPT
$IPT -P FORWARD DROP


#При применении этих правил будет следующий эффект: нельзя в течении одной минуты подключиться на порт SSH более 4х раз. Защита очень простая и эффективная,
$IPT -t filter -A INPUT -p tcp --destination-port 22 -m state --state NEW -m recent --set --name SSH -j ACCEPT
$IPT -t filter -A INPUT -p tcp --destination-port 22 -m recent --update --seconds 60 --hitcount 4 --rttl --name SSH -j ULOG --ulog-prefix "SSH_BRUTFORCE: "
$IPT -t filter -A INPUT -p tcp --destination-port 22 -m recent --update --seconds 60 --hitcount 4 --rttl --name SSH -j DROP
#####
$IPT -t filter -A INPUT -m state --state INVALID -j DROP
$IPT -t filter -A INPUT -p tcp ! --syn -m state --state NEW -j DROP
# будет препятствовать спуфингу от нашего имени.
$IPT -I INPUT -m conntrack --ctstate NEW,INVALID -p tcp --tcp-flags SYN,ACK SYN,ACK -j REJECT --reject-with tcp-reset



###############################################################
######################## FORWARD ##############################
###############################################################
$IPT -t filter -A FORWARD -i lo -j ACCEPT
#$IPT -t filter -A FORWARD -m set --match-set blacklist dst -j DROP
$IPT -t filter -A FORWARD -m state --state INVALID -j DROP
$IPT -t filter -A FORWARD -m set --match-set FORW src,dst -j ACCEPT
$IPT -t filter -A FORWARD -m set --match-set FORW dst,src -j ACCEPT
$IPT -t filter -A FORWARD -m set --match-set DISCON src --dst EXTERNAL_IP -j ACCEPT
$IPT -t filter -A FORWARD -m set --match-set DISCON dst --src EXTERNAL_IP -j ACCEPT

###############################################################
######################## NAT ##################################
###############################################################

######### Все обращения на 80 порт перебрасываем на UHW
#$IPT -t nat -A PREROUTING --src 10.90.90.0/24 --dst 0.0.0.0/0 -p tcp --dport 80 -j DNAT --to-destination 10.90.90.1:80
######### отключенных абонов редиректим на личный кабинет
#$IPT -t nat -A PREROUTING -m set --match-set DISCON src  --dst 0.0.0.0/0 -p tcp --dport 80 -j DNAT --to-destination SERVER_IP:port
$IPT -t nat -A POSTROUTING -s INTERNAL_NETWORK/INTERNAL_MASK -o EXTERNAL_IFACE -j SNAT --to-source EXTERNAL_IP
#######нат в пул адрессов
#$IPT -t nat -A POSTROUTING -s INTERNAL_NETWORK/INTERNAL_MASK -o EXTERNAL_IFACE -j SNAT --to-source EXTERNAL_IP-EXTERNAL_IP --persisten

#$IPS -A FORW 192.168.64.0/24
;;
stop)
# удаляем все имеющиеся правила
$IPT -F
$IPT -X
$IPT -F -t nat
$IPT -F -t mangle
$IPT -F -t filter
#$IPS -F blacklist
#$IPS -X blacklist
$IPS -F FORW 
$IPS -X FORW
$IPS -F DISCON
$IPS -X DISCON
# Стандартные действия
$IPT -P INPUT ACCEPT
$IPT -P OUTPUT ACCEPT
$IPT -P FORWARD DROP
;;
*)
echo "use start or stop"
esac
