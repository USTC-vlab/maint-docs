# 服务器防火墙配置

我们采用比手搓 iptables 更加靠谱合理的方案：使用 PVE Firewall。

!!! abstract "关于全面切换到 PVE Firewall 的调研"

    优点：

    - PVE 帮忙维护，省心
        - 尤其是在多个 PVE host 之间同步防火墙规则变得更简单了。只需要建一个 Security Group，然后把它绑定到多个 host 上就行了
    - 跑在 PVE host 上，对虚拟机/容器完全透明（类似云服务器的安全组）
    - 自带 MAC filter 和 IP filter，我们就再也不用担心 spoofing 的问题了（虽然 IP filter 需要手动开一下，或者 PUT 一个 API）
    - 四层开关：
        - Datacenter 级别的总开关，只要这个开关不开，就不会有任何规则生效，正式启用之前可以随意改规则
        - Host 级别的开关，针对该主机上的规则（不包括其上的虚拟机）
        - VM 级别的开关，针对该虚拟机的规则
            - 每个虚拟网卡都可以单独开关。注意 VM 级别的开关需要先开启

    缺点：

    - 和 UFW / Firewalld 类似，PVE 也会弄出一堆 iptables 规则（性能未知，不过根据 UFW / Firewalld 的经验，瓶颈应该还在我们的千兆网口上）
    - 作为又一个 iptables 前端，PVE firewall 也要独占 ip(6)tables，需要把我们自己的 filter 规则完全迁移过去
        - 好在初步观察发现它没有动 filter 以外的表（比如 nat），也就是我们自己的 443 → 8006 转发规则还可以留着不冲突，并且还可以继续使用 `iptables-persistent`
            - 但是这个规则还是需要我们手动同步
    - 虚拟机层面的开关和一些其他选项（如 IP filter）默认关闭，需要在虚拟机创建好之后再 PUT 一个 API（考虑交给 vlab-pve-agent）

## 配置文件 {#config}

Datacenter 级别的配置文件在 `/etc/pve/firewall/cluster.fw`，Host 级别的配置文件在 `/etc/pve/nodes/{hostname}/host.fw`，VM 级别的配置文件在 `/etc/pve/firewall/<id>.fw`。如果这些文件在磁盘上被修改了，PVE 会自动将修改同步到 iptables 规则里，测试表明 PVE 的扫描间隔大约为 10s。

### 主机设置 {#config-host}

PVE 会自动放通集群通信所需的端口，所以我们只需要创建一个名为 `management` 的 IPset，将我们自己登录 PVE 的 IP 加入就行了，PVE 会帮我们自动放通这个 IPset 里的 IP。目前添加了几个常用的 IP 地址，包括 iBug 的工作站和 LUG VPN 的出口 IP。

另有一个特殊 IPset 叫做 `blacklist`，不过我们暂时用不上。

其他需要的规则用 Security Group（安全组）实现。我们在集群层面建好了 `vlab-host` 和 `pbs` 等 SG，然后给每个主机都按需配上这些 SG 就行了。

参见：[Firewall - Proxmox VE](https://pve.proxmox.com/wiki/Firewall)

### 虚拟机设置 {#config-vm}

我们在 datacenter 上建一个 Security Group 叫 `vlab-vm` 用来配置需要对所有虚拟机的生效的规则，比如针对 code-server 和 VNC 的防火墙可以通过这种方式部署在虚拟机外面。

如果设置里开启了 IP Filter，对于 LXC 容器，PVE 会自动把已配置好的 IP 地址加入这个白名单，但是我们仍然需要手动处理另外两个问题：

- KVM 虚拟机的 IP 地址（通过 cloud-init 提供的）
- 我们自己配置的 IPv6 SLAAC 地址

目前做法是交给 vlab-pve-agent 来读取 VM 配置文件并生成防火墙配置。对于 IPv6 SLAAC 地址，我们选择偷个懒，直接把整段 /64 加入白名单。

```ini
--8<-- "vm.fw"
```

初始化配置过程见 [2023 年 10 月 1 日工作记录](../records/2023-10-01.md)


## 旧的手工配置 {#previous}

!!! warning

    以下内容已经过时，仅供参考。

防火墙使用 Linux 自带的 iptables 管理，默认策略为 `INPUT DROP`, `FORWARD ACCEPT`, `OUTPUT ACCEPT`。方便起见使用 `iptables-persistent` 让防火墙规则开机自动加载。

以下为 pv1 上的防火墙配置（`/etc/iptables/rules.v4` 和 `rules.v6` 文件内容一样）：

!!! todo "pv1 的额外配置"

    pv1 需要修改以下配置，额外放行 8090 端口，以用于虚拟机创建时的额外初始化（post-creation-agent）。

    另外，由于 pv1 不运行用户容器，故屏蔽了 iptables-legacy 的相关模块，以<s>减少潜在的故障可能</s>展示闲着没事干的精神。

    ```shell title="/etc/modprobe.d/iptables-legacy.conf"
    install iptable_filter    /bin/true
    install iptable_nat       /bin/true
    install iptable_mangle    /bin/true
    install iptable_raw       /bin/true
    install iptable_security  /bin/true
    install ip6table_filter   /bin/true
    install ip6table_nat      /bin/true
    install ip6table_mangle   /bin/true
    install ip6table_raw      /bin/true
    install ip6table_security /bin/true
    ```

```shell
*filter
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
:VLAB - [0:0]
-A INPUT -i lo -j ACCEPT
-A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
-A INPUT -p icmp -j ACCEPT
-A INPUT -i vmbr2 -j ACCEPT
-A INPUT -i vmbr+ -j VLAB
-A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -i vmbr+ -j DROP
-A VLAB -p tcp -m state --state NEW -m tcp --sport 1024:65535 -m multiport --dports 22,80,443,8006 -j ACCEPT
-A VLAB -j DROP
COMMIT


*nat
:PREROUTING ACCEPT [0:0]
:INPUT ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
:POSTROUTING ACCEPT [0:0]
-A PREROUTING -m addrtype --dst-type LOCAL -p tcp --dport 443 -j REDIRECT --to-ports 8006
COMMIT
```

## 以太网桥防火墙 {#ebtables}

我们使用了 ebtables 来防止用户虚拟机通过 ARP 欺骗伪装成 CT 100/101，因为这两个虚拟机对维持正常服务至关重要，但为每个用户虚拟机配置 MAC 地址过滤又过于繁琐、不现实。

我们的 ebtables 规则简单过滤了从用户虚拟机发出的，受保护的源 MAC 地址的以太网帧和响应受保护的源 IP 地址的 ARP 包：

```shell
ebtables -N VLAB_SECURE
ebtables -A VLAB_SECURE -i vxlan1 -j ACCEPT
ebtables -A VLAB_SECURE -i veth100i+ -j ACCEPT
ebtables -A VLAB_SECURE -i veth101i+ -j ACCEPT
ebtables -A VLAB_SECURE -j DROP
ebtables -A FORWARD -p arp --arp-ip-src 172.31.0.0/30 -j VLAB_SECURE
ebtables -A FORWARD -s 00:00:ac:1f:00:00/ff:ff:ff:ff:ff:fc -j VLAB_SECURE
```

由于 ebtables 不自带 persistent 的服务，我们手写了一个 systemd 服务用于持久化 ebtables 规则。

```ini
--8<-- "ebtables.service"
```
