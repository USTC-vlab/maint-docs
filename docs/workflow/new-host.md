# 配置新主机并加入集群

使用 U 盘安装好 Proxmox VE，主机名为 `pv#.ibuglab.com`（Proxmox 安装程序要求，装好后可以改），其中 `#` 为数字或其他标记，手动递增。

## 远程访问

先配好 SSH 访问，对 SSH Host Key 签名，并加入 TrustedUserCAKeys。见 [SSH 证书认证](../ssh-ca.md) 一页。

**在加入现有的 Proxmox VE 集群后**删除 root 密码（`passwd -d root`），方便以后维护。

## 软件源

修改 `/etc/apt/sources.list`，将软件源替换为 TUNA：

```
deb https://mirrors.ustc.edu.cn/debian bullseye main contrib
deb https://mirrors.ustc.edu.cn/debian bullseye-updates main contrib
deb https://mirrors.ustc.edu.cn/debian-security bullseye-security main contrib
```

删除 `/etc/apt/sources.list.d/pve-enterprise.list`，新建 `/etc/apt/sources.list.d/pve.list`，写入以下内容：

```
deb https://mirrors.ustc.edu.cn/proxmox/debian bullseye pve-no-subscription
```

刷新软件源并安装更新。

## 安装软件（可选）

从 APT 安装一些软件以便管理和调试。请尽可能保持主机系统简洁。

- Vim 宇宙第一文本编辑器
- Htop 任务管理器
- iptables-persistent 和 ipset-persistent 用于保存 iptables 配置
- ipmitool 用于维护 IPMI，**使用最简安装（即 `--no-install-recommends`）**

## 配置网卡

参见[主机网卡](../networking/host.md)一页。

## 配置防火墙

需要安装 `iptables-persistent` 和 `ipset-persistent` 软件包，从另一台主机上复制 `/etc/iptables` 目录，修改相关文件中的网卡名称（如有需要）并重启 `netfilter-persistent.service`。

## 配置 LVM

在 `/etc/lvm/lvm.conf` 末尾追加以下内容，替换掉 pve-manager 生成的 devices section：

```conf
devices {
    # added by pve-manager to avoid scanning ZFS zvols
    global_filter = ["r|/dev/disk/by-id/usb.*|", "r|/dev/zd.*|", "r|/dev/mapper/pve-.*|" "r|/dev/mapper/.*-(vm|base)--[0-9]+--disk--[0-9]+|"]
}
activation {
    auto_activation_volume_list = ["pve", "data"]
}
```

## 挂载存储服务器

使用 iSCSI 命令行管理工具

```shell
iscsiadm -m discovery -t sendtargets -p 10.0.0.200
iscsiadm -m node -T iqn.2015-11.com.hpe:storage.msa1050.1840436ed4 -p 10.0.0.200 --login
```

存储服务器的使用地址为 10.0.0.200 与 10.0.0.201，分别归属两个控制器，建议各台计算服务器交替连接这两个地址以「负载均衡」。

挂载看到 iSCSI 的卷之后，进入存储服务器的管理页面，选 Hosts，为刚才新增的那个主机补上名称。IQN 可以看主机里的 `/etc/iscsi/initiatorname.iscsi` 文件来确认。

open-iscsi 软件包通过 systemd 服务提供了开机自动挂载 iSCSI 的功能，但是默认通过 sendtargets 方式发现的 target 不会自动登录，我们可以根据需要自己设置每台机器通过指定的地址和端口登录指定的 target。

参考[这篇文章](https://library.netapp.com/ecmdocs/ECMP1654943/html/GUID-8EC685B4-8CB6-40D8-A8D5-031A3899BCDC.html)，针对想要登录的 target 和地址，修改设置：

```shell
iscsiadm -m node -T iqn.2015-11.com.hpe:storage.msa1050.1840436ed4 -p 10.0.0.200 -o update -n node.startup -v automatic
iscsiadm -m node -T iqn.2015-11.com.hpe:storage.msa1050.1840436ed4 -p 10.0.0.200 -o update -n node.conn[0].startup -v automatic
```

注意正确填写选项 `-T` 和 `-p` 的参数。

!!! tip "也可以直接编辑配置文件"

    或者，一个等价的做法是编辑 `/etc/iscsi/nodes/iqn.2015-11.com.hpe:storage.msa1050.1840436ed4/10.0.0.200,3260,1/default` 文件，找到如下两行并修改为 `automatic`：

    ```ini
    node.startup = automatic
    node.conn[0].startup = automatic
    ```

    注意路径中的 `10.0.0.200,3260,1` 目录名就是 IP 地址 + 端口号 + 控制器序号。存储服务器的另一个控制器位于 `10.0.0.201,3260,2`。

## 挂载 NFS 镜像共享

挂载 NFS 共享所用的 `/etc/fstab` 条目：

```
10.0.0.1:/var/lib/vz /mnt/vz nfs rw,async,hard,intr,noexec 0 0
```

注意先在 pv1 上编辑 `/etc/exports` 并运行 `exportfs -a` 刷新挂载权限。

## 额外的系统设置

参见 [PVE 服务器的额外设置](../servers/pve.md#extra-settings)。
