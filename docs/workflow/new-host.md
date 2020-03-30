# 配置新主机并加入集群

使用 U 盘安装好 Proxmox VE，主机名为 `pv#.vlab.ustc.edu.cn`（Proxmox 安装程序要求，装好后可以改），其中 `#` 为数字，手动递增。

## 远程访问

先配好 SSH 访问，对 SSH Host Key 签名，并加入 TrustedUserCAKeys。见 [SSH 证书认证](../ssh-ca.md) 一页。

**在加入现有的 Proxmox VE 集群后**删除 root 密码（`passwd -d root`）。

## 软件源

修改 `/etc/apt/sources.list`，将软件源替换为 TUNA：

```
deb https://mirrors6.tuna.tsinghua.edu.cn/debian buster main contrib
deb https://mirrors6.tuna.tsinghua.edu.cn/debian buster-updates main contrib
deb https://mirrors6.tuna.tsinghua.edu.cn/debian-security buster/updates main contrib
```

删除 `/etc/apt/sources.list.d/pve-enterprise.list`，新建 `/etc/apt/sources.list.d/pve.list`，写入以下内容：

```
deb https://mirrors6.tuna.tsinghua.edu.cn/proxmox/debian buster pve-no-subscription
```

刷新软件源并安装更新。

## 安装软件（可选）

从 APT 安装一些软件以便管理和调试。请尽可能保持主机系统简洁。

- Vim 宇宙第一文本编辑器
- Htop 任务管理器
- iptables-persistent 用于保存 iptables 配置
- ipmitool 用于维护 IPMI，**使用最简安装（即 `--no-install-recommendeds`）**

## 配置防火墙

需要安装 `iptables-persistent` 软件包。将以下内容保存为 `iptables.sh` 并运行：

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
iptables -A VLAB -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
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
iptables -A FORWARD -i vmbr0 -j DROP
iptables -A FORWARD -i vmbr1 -j DROP

iptables -t nat -F
iptables -t nat -X
iptables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 8006
iptables -t nat -Z
iptables-save > /etc/iptables/rules.v4

##### IPv6 #####
#ip6tables -F
#ip6tables -X
ip6tables -P INPUT ACCEPT
ip6tables -P FORWARD ACCEPT
ip6tables -P OUTPUT ACCEPT
ip6tables -N VLAB >/dev/null 2>&1 || ip6tables -F VLAB

##### Rules #####
ip6tables -A VLAB -i lo -j ACCEPT
ip6tables -A VLAB -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
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
