# 服务器防火墙配置

防火墙使用 Linux 自带的 iptables 管理，默认策略为 `INPUT DROP`, `FORWARD ACCEPT`, `OUTPUT ACCEPT`。方便起见使用 `iptables-persistent` 让防火墙规则开机自动加载。

以下为 pv1 上的防火墙配置：

```shell
#!/bin/sh

set +ex

##### IPv4 #####
#iptables -F
#iptables -X
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
iptables -N VLAB >/dev/null 2>&1 || iptables -F VLAB

##### Rules #####
iptables -A VLAB -i lo -j ACCEPT
iptables -A VLAB -p tcp -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A VLAB -p udp -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A VLAB -p icmp -j ACCEPT
iptables -A VLAB -p tcp -m state --state NEW --sport 1024:65535 -m multiport --dports 22,80,443,8006 -j ACCEPT
iptables -A VLAB -j DROP
iptables -Z VLAB
iptables -D INPUT -i ens1f1 -j ACCEPT >/dev/null 2>&1
iptables -I INPUT -i ens1f1 -j ACCEPT
iptables -D INPUT -i ens1f0 -j ACCEPT >/dev/null 2>&1
iptables -I INPUT -i ens1f0 -j ACCEPT
iptables -D INPUT -i vmbr0 -j VLAB >/dev/null 2>&1
iptables -I INPUT -i vmbr0 -j VLAB
iptables -D INPUT -i vmbr1 -j VLAB >/dev/null 2>&1
iptables -I INPUT -i vmbr1 -j VLAB

iptables -F FORWARD
iptables -A FORWARD -p tcp -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -i vmbr0 -j DROP
iptables -A FORWARD -i vmbr1 -j DROP

iptables -t nat -F
iptables -t nat -X
iptables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 8006
# For storage facility email notification
iptables -t nat -A PREROUTING -i eno3 -p tcp --dport 465 -j DNAT --to-destination 202.38.64.8:465
iptables -t nat -A PREROUTING -i eno4 -p tcp --dport 465 -j DNAT --to-destination 202.38.64.8:465
iptables -t nat -A POSTROUTING -s 10.0.0.0/30 -o vmbr0 -j MASQUERADE
iptables -t nat -Z
iptables-save > /etc/iptables/rules.v4

##### IPv6 #####
#ip6tables -F
#ip6tables -X
ip6tables -P INPUT ACCEPT
ip6tables -P FORWARD ACCEPT
ip6tables -P OUTPUT ACCEPT
ip6tables -N VLAB >/dev/null 2>&1 || ip6tables -F VLAB
ip6tables -N VLAB_STUDENT >/dev/null 2>&1

##### Rules #####
ip6tables -A VLAB -i lo -j ACCEPT
ip6tables -A VLAB -p tcp -m state --state ESTABLISHED,RELATED -j ACCEPT
ip6tables -A VLAB -p udp -m state --state ESTABLISHED,RELATED -j ACCEPT
ip6tables -A VLAB -p ipv6-icmp -j ACCEPT
ip6tables -A VLAB -p tcp -m state --state NEW --sport 1024:65535 -m multiport --dports 22,80,443,8006 -j ACCEPT
ip6tables -A VLAB -j DROP
ip6tables -Z VLAB
ip6tables -D INPUT -i ens1f1 -j ACCEPT >/dev/null 2>&1
ip6tables -I INPUT -i ens1f1 -j ACCEPT
ip6tables -D INPUT -i ens1f0 -j ACCEPT >/dev/null 2>&1
ip6tables -I INPUT -i ens1f0 -j ACCEPT
ip6tables -D INPUT -i vmbr0 -j VLAB >/dev/null 2>&1
ip6tables -I INPUT -i vmbr0 -j VLAB
ip6tables -D INPUT -i vmbr1 -j VLAB >/dev/null 2>&1
ip6tables -I INPUT -i vmbr1 -j VLAB

ip6tables -F FORWARD
ip6tables -A FORWARD -i vmbr0 -j DROP
ip6tables -A FORWARD -i vmbr1 -j DROP

ip6tables -t nat -F
ip6tables -t nat -X
ip6tables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 8006
ip6tables -t nat -Z
ip6tables-save > /etc/iptables/rules.v6
```

几个小点解释：

```shell
iptables -A VLAB -i lo -j ACCEPT
iptables -A VLAB -p tcp -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A VLAB -p udp -m state --state ESTABLISHED,RELATED -j ACCEPT
```

这三个放最前面，让本机流量 `-i lo` 和已经建立起来的 TCP / UDP 连接经过最少的链项，提高性能降低 CPU 使用量，这是因为 iptables 规则是按顺序逐条匹配的。

```shell
iptables -I INPUT -i ens1f1 -j ACCEPT
iptables -I INPUT -i ens1f0 -j ACCEPT
```

光纤内网不设防。
