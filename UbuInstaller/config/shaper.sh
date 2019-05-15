#!/bin/bash

IFUP=EXTERNAL_IFACE
IFDOWN=INTERNAL_IFACE
IPT="/sbin/iptables"
tc="/sbin/tc"
SPEEDUP=1024mbit
SPEEDDOWN=1024mbit
case $1 in
start)
$IPT -t mangle --flush

$tc qdisc add dev $IFDOWN root handle 1: htb
$tc class add dev $IFDOWN parent 1: classid 1:1 htb rate $SPEEDDOWN ceil $SPEEDDOWN

$tc qdisc add dev $IFUP root handle 1: htb
$tc class add dev $IFUP parent 1: classid 1:1 htb rate $SPEEDUP ceil $SPEEDUP
;;
stop)

$IPT -t mangle --flush

$tc qdisc del dev $IFUP root handle 1: htb
$tc qdisc del dev $IFDOWN root handle 1: htb
;;
*)
echo "use start or stop"
esac
