# 网络配置

与本代 Vlab 集群相关的网络有三个，下面分别介绍。

## 校园网 {#ustcnet}

所有机器都在电三楼 524 机房，通过铜线直接接入电三楼的 VLAN，该 VLAN 有三个公网 IP 地址段 202.38.75.254/24, 202.38.79.254/24, 202.38.86.254/24，另有一个仅校园网的地址段 10.38.79.254/24，目前部署了所有主机的 IPMI 界面。

除 pv8 外所有机器的四个网口做一个 bond，然后将这个 bond 桥接，系统中显示的界面名称为 `vmbr0`。方便起见所有主机的校园网 IP 都从 202.38.75.0/24 网段中取，记录在域名 `pv#.vlab.ibugone.net` 中。

pv8 的 eno4 接在光交换机的管理端口上，因此 pv8 只有三个网口做 bond。

## 光纤内网 {#fibre-intranet}

光纤界面为 `ens1f0` 和 `ens1f1`（两台 GPU 服务器为 `ens4f0` 和 `ens4f1`），通过一个华为光交换机互联，因此只有服务器集群内部连通，由于每台计算服务器各自接入校园网，所以光纤内网只用于互联（包括连接 iSCSI），不用于转发。

IP 分配情况见 [IP 地址列表](ips.md)。

运行在这个网络上的设施有 iSCSI 和 NFS（用于共享容器镜像，LVM 带锁不能直接多机同时挂载）。

## 容器内网 {#overlay-intranet}

容器之间的连接基于运行在光纤之上的 overlay 网络，overlay 实现采用 VXLAN，更多信息参见 [容器内网](intranet.md) 一页。

### 学生机网络 {#vm-network}

CT100 为网关，将所有学生机的上行流量 NAT 后连接到校园网，详见 [CT100 容器的文档](../servers/ct100.md)。

CT101 为 web 服务器，提供 web 界面（Nginx, Django）和 VNC 统一接入（程序在 [pdlan](https://github.com/pdlan) 的一个私有仓库中，由于潜在的版权问题不能公开）。具体内容详见 [CT101 容器的文档](../servers/ct101.md)。

## 网络架构 {#structure}

![External network structure](https://image.ibugone.com/vlab/network-external-1.png){: .img-border }

![Internal network structure](https://image.ibugone.com/vlab/network-internal.png){: .img-border }
