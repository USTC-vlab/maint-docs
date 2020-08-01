# 主机网卡

Proxmox VE 不支持 ifupdown 以外的网络管理系统（可以使用 ifupdown2，不过我们不需要），如 NetworkManager 和 systemd-networkd 等，因此网络配置只能使用 `/etc/network/interfaces` 文件。

参考 pv2 上配置，复制时注意替换 IP 地址。

```
auto lo
iface lo inet loopback

auto eno1
iface eno1 inet manual
    bond-master bond0

auto eno2
iface eno2 inet manual
    bond-master bond0

auto eno3
iface eno3 inet manual
    bond-master bond0

auto eno4
iface eno4 inet manual
    bond-master bond0

auto ens1f0
iface ens1f0 inet static
    address 10.0.0.12
    netmask 255.255.255.0
auto ens1f1
iface ens1f1 inet static
    address 10.0.0.22
    netmask 255.255.255.0
    mtu 1550

auto bond0
iface bond0 inet manual
    bond-mode balance-alb
    bond-miimon 100
    bond-downdelay 200
    bond-updelay 200

auto vmbr0
iface vmbr0 inet static
    address 202.38.75.97/24
    gateway 202.38.75.254
    dns-nameservers 202.38.64.1
    bridge_ports bond0
    bridge_stp off
    bridge_fd 0
iface vmbr0 inet6 static
    address 2001:da8:d800:75::a2
    netmask 64
    gateway 2001:da8:d800:75::1
    dns-nameservers 2001:da8:d800::1

# Overlay network for VMs
auto vxlan0
iface vxlan0 inet manual
    pre-up ip link add vxlan0 type vxlan id 10 group 239.1.1.1 dstport 0 dev ens1f1 || true
    up ip link set vxlan0 up
    down ip link set vxlan0 down
    post-down ip link delete vxlan0 || true
    mtu 1500
auto vmbr1
iface vmbr1 inet static
    address 172.31.0.102/16
    bridge_ports vxlan0
    bridge_stp off
    bridge_fd 0
```

其中 ens1f1 的 `mtu 1550` 和 vxlan0 的 `mtu 1500` 设置见[踩坑记录](../traps.md#vxlan-mtu)中的解释。
