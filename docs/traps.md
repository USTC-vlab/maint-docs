---
icon: material/bug
---

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

### HA 提示 `service 'ct:100' in error state, must be disabled and fixed first`

需要先 disable：`ha-manager set ct:100 --state disabled`（`ct:100` 替换为报错提示中对应的名字）

### Migrate 提示 `ERROR: migration aborted (duration 00:00:00): CT is locked (migrate)`

容器：`pct unlock <ID>`

虚拟机：`qm unlock <ID>`

!!! warning "HA 注意事项"

    请勿 bind mount 或挂载 ISO，否则节点下线时无法进行自动 migrate。

### 手动迁移启用了 HA 的虚拟机或容器又被自动迁移回来了

PVE 的 HA 太敬业了，运行虚拟机时会严格按照 HA 配置好的节点优先级来运行虚拟机。

??? note "旧解决方法"

    要想 HA “听话”，办法就是直接改各节点的优先级，让听话的 HA 帮你迁移。

    维护节点前请将其优先级调低或删掉（默认为零，数值越高越优先），以免重启过程中 HA 将虚拟机频繁迁移。

HA group 有一个选项是 nofailback，即禁用“有更高优先级节点在线时优先迁移到更高节点”这个默认行为。启用 nofailback 后 HA 会尽量避免迁移虚拟机而不是尽量往高优先级节点上迁移。

### Proxmox Backup Server 无法连接，提示 Error fetching datastores - fingerprint XX:XX:XX:…

PVE 会验证 PBS 的证书，如果证书与配置的 fingerprint 不匹配（或者在没有 fingerprint 的时候不信任证书），则会提示错误。

由于我们的证书使用 acme.sh 自动更新，每次更新后证书的 fingerprint 就会变化，而我们使用内网地址连接 PBS 也不可能获得公网可信任的证书，因此解决方法是每次更新证书时同步更新 fingerprint。

在 pv1 的更新证书的 cron 脚本最后加入以下内容，使用 OpenSSL 获取证书 fingerprint 并用 pvesm 命令登记修改：

```shell
FP="$(openssl x509 -noout -fingerprint -sha256 -inform pem -in "$SRC/pveproxy-ssl.pem")"
FP="${FP##*=}"
pvesm set pbs --fingerprint "$FP"
```

## LVM

### 开机显示 Cannot process volume group pve 等错误信息

这一步比较麻烦，主要是因为 IPMI 提供的那个远程终端经常卡。

原因是系统中有 `/dev/sda` 和 `/dev/sdb` 两个设备，其中一个是 SSD，另一个不知道是哪来的（可能是 IPMI 的虚拟设备，通过 USB 总线接入），为了不让 LVM 每次运行时都吐槽一遍 `open /dev/sdX failed: no medium found`，将报错的那个设备屏蔽，方法是在 `/etc/lvm/lvm.conf` 中的 `global_filters` 中加入 `"r|/dev/disk/by-id/usb.*|"`，使 LVM 扫描 PV 时忽略这个设备及其他经过 USB 总线连接的设备。

!!! bug "坑点 1（已解决）"

    曾经的过滤规则是 `r|/dev/sdb|`，这样就把任何映射到 sdb 的设备都忽略了，但是在不明情况下这两个设备会互换，导致原先的过滤规则把真正的系统盘给过滤掉了，留下一个空设备，无法开机启动（rootfs 在 LV 卷 pve/root 上）

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

    !!! note ""

        其实第 5 步不一定需要 chroot，但是这一步是需要的

### CT 100 和 CT 101 无法启动

LVM 卷不能多个主机同时使用（active 状态），如果出现这种情况会导致 LVM 拒绝使用受影响的卷。

目前我们的 VG `user-data` 是共享的，而 VG `pve` 是每个主机自己的 SSD（即与本问题无关）。

!!! note "Proxmox VE 使用 LVM"

    Proxmox VE 在启动容器或虚拟机时会尝试占用相关的卷（设为 active），并在关闭容器或虚拟机时取消 active 状态，因此正常情况下不会出现跨主机占用的情况。

!!! question "该坑点可能已修复，尚未测试"

    开机启动或者手动连接 iSCSI 设备会导致上面所有的 LV 都变成 active，[这是 PVE 的默认行为](https://forum.proxmox.com/threads/vm-lvm-volumes-active-on-all-nodes.47531/)。

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

### 将 pve/root 改为 LVM mirror 卷后开机卡在 Loading initial ramdisk

重启进 Live CD，挂载一堆东西，然后 chroot 进原系统的 rootfs。

```shell
vgscan
vgchange -ay pve/root
mount /dev/pve/root /mnt
mount -o rbind /run /mnt/run  # For systemd-udevd
chroot /mnt
mount -t devtmpfs devtmpfs dev
mount -t proc proc proc
mount -t sysfs sysfs sys
mount /dev/sda1 /boot/efi
```

然后在以下方法中二选一（两个都做也没问题）：

1. 编辑 `/etc/initramfs-tools/modules`，添加两行 `dm_raid` 和 `raid1`，运行 `update-initramfs -u -k all`
2. 直接安装 `mdadm` 软件包

以上操作完成后重启即可。

参考：<https://askubuntu.com/q/292092/612877>

### 容器仍在（部分）运行，但是 rootfs 未在 `lvs` 中显示

症状：

- 容器的 rootfs 神秘消失
- `journalctl` 的错误日志提示 ext4（或者其他文件系统）读写容器 rootfs 时出现错误
- 容器无法正常操作

这个问题当时在 CT 100 上出现，原因为在同学操作测试节点时，使用了和正式环境相同的 LVM 存储，但是未加入集群，导致锁失效。**这种情况是极其危险的，最坏的情况下，可能会破坏 LVM 的分区表。**

目前，测试节点已加入集群，并且对重要容器的备份正在操作中。

### LVM metadata 已满，无法新建 LV

参见 [2022 年 6 月 16 日工作总结](records/2022-06-16.md)。

## 网络 {#networking}

### Proxmox VE 7 网络配置 {#pve-7-ifupdown2}

PVE 7 默认使用 ifupdown2，是 ifupdown 的一个 Python 替代品，配置文件 `/etc/network/interfaces` **几乎**兼容。

ifupdown2 的 bond 语法有一点不一样（并且会炸），就是 bond 的 slave 是写在 bond 设备下的，而不是像 ifupdown 一样在 slave 设备下写 `bond-master`，所以从 ifupdown 换到 ifupdown2 后**重启前务必修改配置**。建议不要着急删掉 `bond-master`，因为尽管两种写法互不兼容，但是它们也互不冲突（ifupdown / ifupdown2 会互相无视另一种写法）。

!!! warning "升级 PVE 7 不一定会自动替换软件"

    如果更新到 PVE 7 的时候没有自动将 ifupdown 替换为 ifupdown2，请手动替换并更新配置文件。

语法比较：

=== "ifupdown"

    ```
    auto eno1
    iface eno1 inet manual
        bond-master bond0

    auto eno2
    iface eno2 inet manual
        bond-master bond0

    auto bond0
    iface bond0 inet manual
        bond-mode balance-alb
        bond-miimon 100
        bond-downdelay 200
        bond-updelay 200
    ```

=== "ifupdown2"

    ```
    auto eno1
    iface eno1

    auto eno2
    iface eno2

    auto bond0
    iface bond0
        bond-slaves eno1 eno2
        bond-mode balance-alb
        bond-miimon 100
        bond-downdelay 200
        bond-updelay 200
    ```

更多信息请见[主机网卡](networking/host.md)。

!!! bug "注意下划线"

    ifupdown2 里不再使用下划线作为 key，所有 ifupdown 里使用下划线的 key 都被换成了减号，例如 `bridge_ports` 已经换成了 `bridge-ports`。   

### ARP 问题 {#linux-arp}

!!! success "该问题已于 2020 年 7 月 31 日解决，见下"

默认情况下 Linux 会对本机的所有 IP 地址在所有界面上响应 ARP 请求（当然 127.0.0.0/8 是除外的），例如一个主机拥有两个界面 ifA 和 ifB，它们分别具有 IP 地址 ipA 和 ipB，那么 Linux 会在 ifA 上响应 who-has ipB 的请求，反之亦然。

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

### PVE 防火墙与 ebtables {#pve-fwbr}

PVE 会将开启了 firewall 的虚拟机网卡额外桥接一次，如图所示：

未开启 firewall 时

:   <!-- -->

    ```mermaid
    flowchart LR
    vmbr{{vmbr0}} ---|"veth100i0 / eth0@vm"| vm([VM])
    ```

开启 firewall 时

:   <!-- -->

    ```mermaid
    flowchart LR
    vmbr{{vmbr0}} ---|"fwpr100i0 / fwln100i0"| fwbr{{fwbr100i0}} ---|"veth100i0 / eth0@vm"| vm([VM])
    ```

为了全面迁移到 PVE 防火墙，我们提前修改了 Django 为新建的虚拟机的网卡启用防火墙，但是意外的是，PVE Datacenter 层面的防火墙总开关只控制是否应用 iptables 规则，总开关关闭的情况下 PVE 仍然进行上述桥接操作。该桥接与我们[手搓的 ebtables 规则](./networking/firewall.md#ebtables)有冲突，使所有帧都无法经过 fwbr100i0，导致虚拟机整个断网。

虽然 `ebtables -I VLAB_SECURE 4 -i fwln+ -j ACCEPT` 可以解决问题，但是既然要迁移了，我们还是选择直接删除手搓的 ebtables 配置，避免以后起更多冲突。

### iptables-legacy 与 iptables-nft {#iptables-legacy-nft}

PVE Firewall 会在启动时自动将 iptables 命令的 alternatives [切换至 iptables-legacy][pve-iptables-legacy]，但是并不会帮忙清掉 iptables-nft 里已有的规则，所以刚开启全局防火墙开关的时候，尽管 `iptables -S` 和 `iptables-save` 命令的输出看起来没啥问题，但是虚拟机还是断网了，仔细思考了 20 分钟才想起来这个问题。

  [pve-iptables-legacy]: https://forum.proxmox.com/threads/v6-0-move-from-iptables-to-nftables.55924/#post-257794

解决方法是手动清掉 iptables-nft 里的规则，在每个主机上运行：

```shell
iptables-nft -F
iptables-nft -X
iptables-nft -Z
```

此时还没有注意到 IPv6 也坏了，又花了 10 分钟想起来还需要执行下面的命令：

```shell
ip6tables-nft -F
ip6tables-nft -X
ip6tables-nft -Z
```

考虑到我们先前对 INPUT, OUTPUT, FORWARD 链设置的 policy 都是 ACCEPT，就不需要重置了。


## 虚拟机 {#vm}

### systemd-logind 启动失败

尤其是在容器从 Debian buster 升级到 bullseye 后容易出现。

**症状：**

SSH 登录已连接，但长时间不弹出 shell，`/var/log/auth.log` 显示 `pam_systemd(sshd:session): Failed to create session: Failed to activate service 'org.freedesktop.login1': timed out`，`systemctl status systemd-logind` 显示 `failed` / `code=226/NAMESPACE`。

**原因：**

Systemd 从版本 242 开始采用更多技术来限制运行服务的权限，而默认没开 nesting 的容器缺少必要权限，导致 systemd-logind 无法启动。

**解决方法：**

为容器开启 nesting（和 keyctl，如果你想的话）。我们已经默认为用户容器开启了这两项权限，所以为我们自己的服务容器开启它们不会有额外的问题。

```shell
pvesh set /nodes/<node_name>/lxc/<vmid>/config -features keyctl=1,nesting=1
```

参考资料：<https://discuss.linuxcontainers.org/t/apparmor-blocks-systemd-services-in-container/9812>

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

**症状：**

尝试运行 Docker 容器时出现如下错误：

> docker: Error response from daemon: OCI runtime create failed: container\_linux.go:349: starting container process caused "process\_linux.go:449: container init caused \\"join session keyring: create session key: disk quota exceeded\\"": unknown.

**解决方法：**

参考 <https://github.com/docker/compose/issues/7295#issuecomment-657475590>。

Docker 需要获取到 kernel session key 才能正常运行。首先查看 `/proc/key-users` 文件，分析限额卡在了哪里。文件内容类似于：

```text
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

如果需要持久化配置，请添加 `/etc/sysctl.d/20-keys.conf`，写入下面的内容：

```ini
kernel.keys.maxbytes = 500000
kernel.keys.maxkeys = 5000
```

然后执行 `sysctl --system`。

### Docker in LXC 启动失败 (Proxmox VE 7)

从 Proxmox VE 6 升级到 Proxmox VE 7 后配置了 `keyctl=1,nesting=1` 的容器无法启动 `docker.service`，journalctl 输出有 `Devices cgroup isn't mounted`。

**原因：**Proxmox VE 7 默认开启了 unified cgroup hierarchy（即 cgroup v2），而旧版本的 Docker 需要原来的 cgroup v1 结构。

**解决方法：**在内核参数中加上 `systemd.unified_cgroup_hierarchy=0`，然后重启主机。具体操作是在 `/etc/default/grub` 的 `GRUB_CMDLINE_LINUX_DEFAULT` 后面补上 `systemd.unified_cgroup_hierarchy=0`，然后执行 `update-grub` 并重启。

!!! note

    Docker Engine 20.10 开始支持 cgroup v2，但是到全面应用还有点早，所以这个兼容设置先开着。

### Systemd 服务因「空间不足」启动失败。

症状：重要服务无法启动，提示 `Failed to add /run/systemd/ask-password to directory watch: No space left on device`，但是 `df` 显示剩余空间还有很多。

可能的解决方法：设置 sysctl:

```ini
fs.inotify.max_user_watches = 1048576
```

因为出问题的容器被同学删掉了，所以未验证是否能够解决问题。

### 图形界面中运行的进程数最多只能跑 4915 个

所有图形界面进程 cgroup 都挂在 lightdm.service 的限制下面，而 systemd 默认配置限额为 4915。

简单快速的修改命令：`systemctl set-property lightdm.service TasksMax=18000`

更详细的指导参见 <https://www.suse.com/support/kb/doc/?id=000015901>

### 使用 Ubuntu cloud-image 镜像 import 的虚拟机启动卡死

解决方法：手动挂载（`lvchange -ay 磁盘名`），使用 `fdisk -l` 检查分区表是否有问题。如果有（提示 The primary GPT table is corrupt, but the backup appears OK, so that will be used），使用 `fdisk` 打开，再执行 `w` 利用备份分区表写入修复。

### `tcpdump` 运行无输出

2021/12/19 凌晨有同学反馈该问题，经检查问题为容器中的 apparmor 规则阻止了 `tcpdump` 向 `stdout`/`stderr` 导致的。简单的解决方法如下：

```shell
cd /etc/apparmor.d
sudo mv usr.sbin.tcpdump disable/
sudo apparmor_parser -R /etc/apparmor.d/disable/
```

之后需要修改镜像，移除 `usr.sbin.tcpdump` 规则。

### 处理 fork bomb

1. 找到问题主机，从 `/proc/<很大的 PID>/mounts` 获得 VMID
2. `echo 1 > /sys/fs/cgroup/lxc/<VMID>/cgroup.kill`
3. 等一段时间，让 kernel 慢慢杀（`cgroup.kill` 会阻止 cgroup 内部进程创建新进程，并且发送 SIGKILL）。如果有需要，单独添加更严格的限额（在文件 `/etc/pve/lxc/<VMID>.conf` 添加 `lxc.cgroup2.pids.max: 2000`）

### 调试 "Failed to run lxc.hook.pre-start for container"

1. 在对应的节点上执行 `lvchange -ay` 激活用户盘
2. 执行 `lxc-start -n <vmid> -F -I DEBUG -o debug.log`
3. 启动失败后查看 debug.log 内容

2023/04/07 遇到一个盘写满，结果写不了需要给 systemd-network 的临时文件，然后启动失败的，之后给 postcreation 的 tune2fs 设置了保留 1% 的预留空间（而不是不保留）。

### 定时任务调整

如果发现凌晨 0 点或者凌晨 6 至 7 点 iowait% 以及 IO time 过高，对所有正在运行的容器执行以下操作：

See [2023 年 1 月 28 日工作记录](./records/2023-01-28.md).

```console
# pct list | awk '$2=="running"{print $1}' | xargs -I xxx pct exec xxx -- systemctl disable man-db.timer
# pct list | awk '$2=="running"{print $1}' | xargs -I xxx pct exec xxx -- systemctl disable apt-daily-upgrade.timer
# pct list | awk '$2=="running"{print $1}' | xargs -I xxx pct exec xxx -- bash -c 'echo xxx && [ ! -f "/etc/systemd/system/logrotate.timer.d/vlab.conf" ] && mkdir -p /etc/systemd/system/logrotate.timer.d && echo -e "[Timer]\nRandomizedDelaySec=3h" > /etc/systemd/system/logrotate.timer.d/vlab.conf && systemctl daemon-reload'
```

### 新建的虚拟机随机出现 GPT 分区表损坏

这个问题困扰了我们很久，根本原因是 HPE 的 SAN 汇报其会对通过 SCSI UNMAP 命令释放的块进行清零处理，但实际上并不会，导致 `qemu-img convert` 往新建的 LVM 写入镜像时跳过了清零操作，而未清零的残余数据导致了 GPT 分区表损坏。

排查过程和解决方法详见 [2024 年 10 月 2 日的工作记录](records/2024-10-02.md)。

### 解决 FUSE 死锁

FUSE 死锁时（有应用在容器中访问 FUSE，但是 FUSE 的应用因为某种原因工作不正确）需要使用内核的 fuse 管理接口手工结束连接，方法如下：

1. 在 `/sys/fs/fuse/connections` 下运行 `for i in */waiting; do echo $i; cat $i; done`，保险起见可以多跑几遍，收集所有一直在 waiting 的连接。
2. 对每个连接 `echo 1 > xxxx/abort` 杀掉连接。

## Web 及用户界面

### 创建虚拟机出现 Connection aborted, RemoteDisconnected('Remote end closed connection without response')

查看 pv1 上的 `systemctl status pveproxy` 可见如下内容：

```
Oct 27 17:13:56 pv1 pveproxy[34382]: problem with client ::ffff:172.30.0.2; rsa_padding_check_pkcs1_type_1: invalid padding
```

**解决方法**：直接 reload django 应用即可，原因及复现方法未知。

## HPE 服务器 IPMI（HPE iLO）

HPE iLO 固件下载（官方链接，免登录）：<https://pingtool.org/latest-hp-ilo-firmwares/>

P.S. 如果链接挂了，请善用各种 Internet Archive 以及 Google Web Cache。

### 更新 iLO 固件报错 The file signature is invalid.

更新 iLO 固件时报错 *The file signature is invalid. Make sure you are using a valid, signed flash file and try again.*

原因：跨版本的 iLO 固件有时候需要先更新到某个“中间版本”，例如 iLO 5 1.40 以前的版本不能直接更新到 2.10 以后，需要先更新到 1.40 才能再更新到 2.10。

参考资料：<https://community.hpe.com/t5/ProLiant-Servers-ML-DL-SL/ILO5-firware-update-fails-quot-the-file-siganture-is-invalid/td-p/7085862>
