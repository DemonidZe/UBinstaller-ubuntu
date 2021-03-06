#!/bin/sh

# Обьявляем где у нас лежит IPTABLES
IPT="/sbin/iptables"
IPS="/sbin/ipset"
case $1 in
start)
# удаляем все имеющиеся правила
$IPT -F
$IPT -X
$IPT -F -t nat
$IPT -F -t mangle
$IPT -F -t filter
# Стандартные действия
$IPT -P INPUT ACCEPT
$IPT -P OUTPUT ACCEPT
$IPT -P FORWARD DROP


#При применении этих правил будет следующий эффект: нельзя в течении одной минуты подключиться на порт SSH более 4х раз. Защита очень простая и эффективная,
$IPT -t filter -A INPUT -p tcp --destination-port 22 -m state --state NEW -m recent --set --name SSH -j ACCEPT
$IPT -t filter -A INPUT -p tcp --destination-port 22 -m recent --update --seconds 60 --hitcount 4 --rttl --name SSH -j LOG --log-prefix "SSH_BRUTFORCE: "
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
;;
stop)
# удаляем все имеющиеся правила
$IPT -F
$IPT -X
$IPT -F -t nat
$IPT -F -t mangle
$IPT -F -t filter
# Стандартные действия
$IPT -P INPUT ACCEPT
$IPT -P OUTPUT ACCEPT
$IPT -P FORWARD DROP
;;
*)
echo "use start or stop"
esac
