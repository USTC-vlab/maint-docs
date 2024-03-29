# 主机网卡

Proxmox VE 不支持 ifupdown 以外的网络管理系统（PVE 7 开始默认使用 ifupdown2），如 NetworkManager 和 systemd-networkd 等，因此网络配置只能使用 `/etc/network/interfaces` 文件。

以下是 pv2 的配置供参考，批量修改请见[这个 Gist](https://gist.github.com/iBug/988806dea74b79408062db2325b972be)。关于 ifupdown 和 ifupdown2 的区别见[这个页面](https://support.cumulusnetworks.com/hc/en-us/articles/202933638-Comparing-ifupdown2-Commands-with-ifupdown-Commands)，以及 ifupdown2 的文档[在这](https://cumulusnetworks.github.io/ifupdown2/ifupdown2/index.html)。

=== "ifupdown2"

    ```
    auto lo
    iface lo inet loopback

    auto eno1
    iface eno1
    auto eno2
    iface eno2
    auto eno3
    iface eno3
    auto eno4
    iface eno4

    auto ens1f0
    iface ens1f0
        mtu 1550
    auto ens1f1
    iface ens1f1
        mtu 1550

    auto bond0
    iface bond0
        bond-slaves eno1 eno2 eno3 eno4
        bond-mode balance-alb
        bond-miimon 100
        bond-downdelay 200
        bond-updelay 200

    auto bond1
    iface bond1
        address 10.0.0.12/24
        bond-slaves ens1f0 ens1f1
        bond-mode 802.3ad
        bond-miimon 100
        bond-downdelay 200
        bond-updelay 200

    auto vmbr0
    iface vmbr0
        address 202.38.75.97/24
        gateway 202.38.75.254
        dns-nameservers 202.38.64.1
        bridge-ports bond0
        bridge-stp off
        bridge-fd 0
    iface vmbr0 inet6 static
        address 2001:da8:d800:75::a2/64
        gateway 2001:da8:d800:75::1

    # Overlay network for VMs
    auto vxlan1
    iface vxlan1
        pre-up ip link add $IFACE type vxlan id 1 group 239.1.1.1 dev bond1 || true
        post-down ip link delete $IFACE || true
        mtu 1500
    auto vmbr1
    iface vmbr1
        bridge-ports vxlan1
        bridge-stp off
        bridge-fd 0

    # Overlay network for management
    auto vxlan2
    iface vxlan2
        pre-up ip link add $IFACE type vxlan id 2 group 239.1.1.1 dev bond1 || true
        post-down ip link delete $IFACE || true
        mtu 1500
    auto vmbr2
    iface vmbr2
        address 172.30.0.102/24
        bridge-ports vxlan1
        bridge-stp off
        bridge-fd 0
    ```

=== "ifupdown"

    :fontawesome-solid-exclamation-triangle:{: .orangered } 以下配置文件为迁移至 ifupdown2 前的最后配置，实际情况已发生变化，内容仅供参考

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
    iface ens1f0 inet manual
        bond-master bond1
        mtu 1550
    auto ens1f1
    iface ens1f1 inet manual
        bond-master bond1
        mtu 1550

    auto bond0
    iface bond0 inet manual
        bond-mode balance-alb
        bond-miimon 100
        bond-downdelay 200
        bond-updelay 200

    auto bond1
    iface bond1 inet static
        address 10.0.0.12/24
        bond-mode 802.3ad
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
        address 2001:da8:d800:75::a2/64
        gateway 2001:da8:d800:75::1

    # Overlay network for VMs
    auto vxlan0
    iface vxlan0 inet manual
        pre-up ip link add vxlan0 type vxlan id 10 group 239.1.1.1 dev bond1 || true
        up ip link set vxlan0 up
        down ip link set vxlan0 down
        post-down ip link delete vxlan0 || true
        mtu 1500
    auto vmbr1
    iface vmbr1 inet static
        address 172.30.0.102/24
        bridge_ports vxlan0
        bridge_stp off
        bridge_fd 0
    ```

其中 ens1f1 的 `mtu 1550` 和 vxlan0 的 `mtu 1500` 设置见[踩坑记录](../traps.md#vxlan-mtu)中的解释。
