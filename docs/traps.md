# 踩坑记录

## Proxmox VE

### 在向集群添加节点时，需要保证集群中已有的节点全部开启并正常连接

否则，未开启的节点由于没有收到更新通知，可能在加入集群时出现错误。

在出现错误的节点上的症状：

- `pvesr.service` 无法运行，错误信息包含 "error with cfs lock 'file-replication\_cfg': no quorum!"
- `pvecm status` 显示 "Cannot initialize CMAP service"
- `corosync.service` 未在运行

解决方法：

1. 关闭 `pve-cluster.service`
2. 执行 `pmxcfs -l`，将集群文件系统以 local mode 启动
3. 从正常运行的节点上复制 `/etc/pve/corosync.conf`，覆盖错误节点的相应文件
4. `killall pmxcfs`
5. 重启 `pve-cluster.service` 和 `corosync.service`

## LVM

### 开机显示 Cannot process volume group pve 等错误信息

这一步比较麻烦，主要是因为 IPMI 提供的那个远程终端经常卡。

原因是系统中有 `/dev/sda` 和 `/dev/sdb` 两个设备，其中一个是 SSD，另一个不知道是哪来的（可能是 IPMI 的虚拟设备），为了不让 LVM 每次运行时都吐槽一遍 `open /dev/sdX failed: no medium found`，将报错的那个设备屏蔽，方法是在 `/etc/lvm/lvm.conf` 中的 `global_filters` 中加入一个 `"r|/dev/sdX|"`，使 LVM 扫描 PV 时忽略这个设备。

!!! bug "坑点"

    在不明情况下这两个设备会互换，导致原先的过滤规则把真正的系统盘给过滤掉了，留下一个空设备，无法开机启动（rootfs 在 LV 卷 pve/root 上）

    好在目前没有发现空设备从 sdb 变成 sda 的情况，因此每个主机最多只需要处理一次就行（其实到现在一共就发生过一次）。

!!! bug "坑点 2"

    LVM 是开机启动必须的功能，因此 LVM 相关的工具（`lvm` 命令）和配置文件（即 `/etc/lvm/lvm.conf`）会打包进 initramfs 里，这时候这个配置文件在系统里和 initramfs 里就有独立的两份了，要修改得把两份都修改掉。

#### 解决步骤

1. 开机失败，进入 initramfs，这里有个 busybox 和 `lvm` 工具
2. 编辑 `/etc/lvm/lvm.conf`，找到 `global_filters`，把其中的 `r|/dev/sda|` 换成 `r|/dev/sdb|`（或者反过来改，取决于原先内容是什么以及前面报 no medium found 的是哪个设备）
3. `lvm vgscan`，这时候再 `lvm vgs` 应该就能看到 pve 这个 VG 了
4. `lvm lvchange -ay pve/root` 激活 rootfs 卷，找个地方挂载起来
5. chroot 进去，把 `/etc/lvm/lvm.conf` **再改一遍**（和第 2 步相同）
6. `update-initramfs -u -k all` 更新 initramfs，重启

    <small>\* 其实第 5 步不一定需要 chroot，但是这一步是需要的</small>

### CT 100 和 CT 101 无法启动

LVM 卷不能多个主机同时使用（active 状态），如果出现这种情况会导致 LVM 拒绝使用受影响的卷。

目前我们的 VG `user-data` 是共享的，而 VG `pve` 是每个主机自己的 SSD（即与本问题无关）。

!!! note "Proxmox VE 使用 LVM"

    Proxmox VE 在启动容器或虚拟机时会尝试占用相关的卷（设为 active），并在关闭容器或虚拟机时取消 active 状态，因此正常情况下不会出现跨主机占用的情况。

!!! bug "坑点"

    出于不明原因，手动挂载 iSCSI 设备会导致上面所有的 LV 都变成 active。

解决步骤：

- 如果受影响的卷不多，可以手动 SSH 进入所有主机，全部来一遍 `lvchange -an <vg/lv>`，这样就在全部主机上把这个卷取消了 active 状态，然后其中一个主机就可以开始使用它（启动容器）了。
- 如果受影响的卷很多（常见情况），较为简单的方法是把所有虚拟机容器都关掉，然后 `vgchange -an <vg>`，一次性把整个 VG 里的全部 LV 取消 active 状态（当然每个主机都要重复一遍），然后一切恢复正常。

## 网络 {#networking}

### VXLAN MTU

VXLAN 是一种 overlay 网络实现，将帧包装在 UDP 包中传输。由于一个 UDP 包对应一个帧，因此 VXLAN 网络的 MTU 为下层承载网的 MTU 减掉 50 字节（各种头之类的），所以在下层网络使用默认配置（MTU 1500）的情况下 VXLAN 网络的 MTU 为 1450，**这是一个非标准的值**，而从该 VXLAN 网络中桥接出来的界面并不知道其网络的真实 MTU 小于 1500，结果就是传输的内容稍微多一点（单个帧超过 1450 字节）的时候就会被整个丢掉，造成无法联网的情况。

解决方法倒也不难，在系统里设置网络的 MTU 为 1450 就行。Proxmox VE 创建容器的时候可以直接在网络参数中指定 `mtu=1450`，但 KVM 虚拟机就必须每个虚拟机设置了，这在 Windows 下[尤其麻烦][windows-mtu]。

所以我们计划在 2020 年暑假把这个问题彻底解决，办法是把下层承载网的 MTU 调大 50 字节（变成 1550 字节，修改 pv1 到 pv8 的 ens1f1 界面），这样 VXLAN 就能拥有“正常”的 1500 字节的 MTU 了，能为以后减少不少麻烦。

  [windows-mtu]: http://networking.nitecruzr.net/2007/11/setting-mtu-in-windows-vista.html
