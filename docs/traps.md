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

!!! question "该坑点可能已修复，尚未测试"

    出于不明原因，手动挂载 iSCSI 设备会导致上面所有的 LV 都变成 active。

    **解决方法**：根据 Server Fault 上的[这个回答](https://serverfault.com/a/678654/450575)，在 `/etc/lvm/lvm.conf` 中写入以下内容：

    ```toml
    auto_activation_volume_list = [ "pve", "data" ]
    ```

    保存后 LVM 就不会在检测到新 VG 时自动启用全部卷了。可能需要更新 initramfs 和/或重启。

解决步骤：

- 如果受影响的卷不多，可以手动 SSH 进入所有主机，全部来一遍 `lvchange -an <vg/lv>`，这样就在全部主机上把这个卷取消了 active 状态，然后其中一个主机就可以开始使用它（启动容器）了。
- 如果受影响的卷很多（常见情况），较为简单的方法是把所有虚拟机容器都关掉，然后 `vgchange -an <vg>`，一次性把整个 VG 里的全部 LV 取消 active 状态（当然每个主机都要重复一遍），然后一切恢复正常。

    - 另一种高级办法是使用文字处理技巧，解析 `lvs` 的输出并关闭全部 active 但不是 open 的卷（即 flags 为 `-wi-a-----` 的卷）。参考命令如下：

        ```shell
        lvs | awk '$2 == "user-data" && substr($3, 5, 1) == "a" { print $2 "/" $1 }' | xargs lvchange -an
        ```

### 容器仍在（部分）运行，但是 rootfs 未在 `lvs` 中显示

症状：

- 容器的 rootfs 神秘消失。
- `journalctl` 的错误日志提示 ext4（或者其他文件系统）读写容器 rootfs 时出现错误。
- 容器无法正常操作。

这个问题当时在 CT100 上出现，原因为在同学操作测试节点时，使用了和正式环境相同的 LVM 存储，但是未加入集群，导致锁失效。**这种情况是极其危险的，最坏的情况下，可能会破坏 LVM 的分区表。**

目前，测试节点已加入集群，并且对重要容器的备份正在操作中。

## 网络 {#networking}

### ARP 问题 {#linux-arp}

!!! success "该问题已于 2020 年 7 月 31 日解决，见下"

默认情况下 Linux 会对本机的所有 IP 地址在所有界面上响应 ARP 请求（当然 127.0.0.0/8 和 loopback 是除外的），例如一个主机拥有两个界面 ifA 和 ifB，它们分别具有 IP 地址 ipA 和 ipB，那么 Linux 会在 ifA 上响应 who-has ipB 的请求，反之亦然。

这在 2020 年上半年研究 pv8 为什么连不上 VXLAN 的时候造成了很大的困惑，因为实际上 pv8 的 ens1f1 界面是坏的（可能是光纤没插好之类的），然后系统在 ens1f0 界面上响应了实际属于 ens1f1 的 IP 地址，在其他机器上看起来就像是 ens1f1 能连通但 vxlan0 连不通，而实际上是 10.0.0.28 被解析到了 pv8 的 ens1f0 上，没故障当然就能连通了。

!!! note "iBug 备注"

    这个地方我也没想到，其实只要在其他机器上看看 ARP 缓存表（`arp -a`）就能发现两个 IP 解析出来的 MAC 一样了

解决办法就是设置 Linux 参数让其只在“正确的”界面上响应，详细解释参见 Server Fault 上的[这个回答](https://serverfault.com/a/834519/450575)。我们的做法是向 `/etc/sysctl.d/arp.conf` 里写入了如下内容：

```ini
net.ipv4.conf.all.arp_ignore=1
net.ipv4.conf.all.arp_announce=2
```

### VXLAN MTU

!!! success "该坑点已于 2020 年 8 月 1 日修复"

    在[此次维护工作](records/2020-08-01.md)中，下层承载网卡 ens1f1 的 MTU 已被调整为 1550 字节，从而此后的 VXLAN 网络都具有“正常”的 1500 字节的设置。

    注意以后若有新增的机器还是需要额外设置一遍的。

VXLAN 是一种 overlay 网络实现，将帧包装在 UDP 包中传输。由于一个 UDP 包对应一个帧，因此 VXLAN 网络的 MTU 为下层承载网的 MTU 减掉 50 字节（各种头之类的），所以在下层网络使用默认配置（MTU 1500）的情况下 VXLAN 网络的 MTU 为 1450，**这是一个非标准的值**，而从该 VXLAN 网络中桥接出来的界面并不知道其网络的真实 MTU 小于 1500，结果就是传输的内容稍微多一点（单个帧超过 1450 字节）的时候就会被整个丢掉，造成无法联网的情况。

解决方法倒也不难，在系统里设置网络的 MTU 为 1450 就行。Proxmox VE 创建容器的时候可以直接在网络参数中指定 `mtu=1450`，但 KVM 虚拟机就必须每个虚拟机设置了，这在 Windows 下[尤其麻烦][windows-mtu]。

所以我们计划在 2020 年暑假把这个问题彻底解决，办法是把下层承载网的 MTU 调大 50 字节（变成 1550 字节，修改 pv1 到 pv8 的 ens1f1 界面），这样 VXLAN 就能拥有“正常”的 1500 字节的 MTU 了，能为以后减少不少麻烦。

  [windows-mtu]: http://networking.nitecruzr.net/2007/11/setting-mtu-in-windows-vista.html

## 虚拟机 {#vm}

### user@1000.service 启动失败

检查环境变量 `XDG_RUNTIME_DIR` 是否设置正确，应为 `/run/user/<uid>`。

另外在未知情况下该目录有可能不存在，需要先创建一个（保险起见，同时 chown 一下）：

```shell
UID="$(id -u)"
mkdir -p "/run/user/$UID"
chown "$UID.$UID" "/run/user/$UID"
```

Ref: <https://github.com/systemd/systemd/issues/9461#issuecomment-409929860>

### Docker in LXC 启动失败

症状：

运行 Docker 容器出现类似于 `docker: Error response from daemon: OCI runtime create failed: container_linux.go:349: starting container process caused "process_linux.go:449: container init caused \"join session keyring: create session key: disk quota exceeded\"": unknown.` 的错误。

解决方法：

参考 <https://github.com/docker/compose/issues/7295#issuecomment-657475590>。

Docker 需要获取到 kernel session key 才能正常运行。首先查看 `/proc/key-users` 文件，分析限额卡在了哪里。文件内容类似于：

```
    0:   336 335/335 238/1000000 4597/25000000
  100:     1 1/1 1/50000 9/20000
  998:     1 1/1 1/50000 9/20000
100000:  1198 1198/1198 1198/50000 19871/20000
100101:     2 2/2 2/50000 18/20000
```

其中：

- 第一列：UID。
- 第二列：目前对应 UID 的 key 数量。
- 第三列：实例化的 key 数量和总 key 数量。（应该可以忽略）
- 第四列：key 数量与总 key 数量限额。（关注）
- 第五列：key 大小与总 key 大小限额。（关注）

注意最后两列。如果出现很贴近限额的情况，需要调整 `/proc/sys/kernel/keys/maxbytes` 和 `/proc/sys/kernel/keys/maxkeys` 的值。root 下 echo 一个更大的数进去即可。

`root_maxbytes` 和 `root_maxkeys` 一般都非常大（见 `key-users` 的第一行），可以不用管。

如果需要持久化配置，需要编辑 `/etc/sysctl.conf`，添加：

```
kernel.keys.maxbytes=500000
kernel.keys.maxkeys=5000
```

然后 `sysctl --system`。