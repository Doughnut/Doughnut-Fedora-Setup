#!/bin/sh

if [ "$EUID" -ne 0 ]
  then echo ""
  echo "Please Run As Root"
  echo ""
fi

# This script is used to do a basic setup of Fedora 21 (Workstation) for quick rollouts.

# First off, disable firewalld and change it to iptables for ease

systemctl disable firewalld
systemctl stop firewalld
yum install iptables-services -y
touch /etc/sysconfig/iptables
touch /etc/sysconfig/ip6tables
systemctl start iptables
systemctl start ip6tables
systemctl enable iptables
systemctl enable ip6tables

# Setup iptables to only allow SSH and do some other things

IPT="/sbin/iptables"
$IPT --flush
$IPT --delete-chain
$IPT -P INPUT DROP
$IPT -P FORWARD DROP
$IPT -P OUTPUT ACCEPT
$IPT -A INPUT -i lo -j ACCEPT
$IPT -A OUTPUT -o lo -j ACCEPT
$IPT -A INPUT -p tcp ! --syn -m state --state NEW -s 0.0.0.0/0 -j DROP
$IPT -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
$IPT -A INPUT -p tcp --dport 22 -m state --state NEW -s 0.0.0.0/0 -j ACCEPT
unset $IPT

# Still needs: sublime text 3 installation, secure secure shell (https://stribika.github.io/2015/01/04/secure-secure-shell.html), install chrome, thunderbird, pidgin /w plugins (and more!)
