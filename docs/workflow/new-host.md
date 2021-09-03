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

## 挂载存储服务器

使用 iSCSI 命令行管理工具

```shell
iscsiadm -m discovery -t sendtargets -p 10.0.0.200
iscsiadm -m node -T iqn.2015-11.com.hpe:storage.msa1050.1840436ed4 -p 10.0.0.200 --login
```

存储服务器的使用地址为 10.0.0.200 与 10.0.0.201，分别归属两个控制器，建议各台计算服务器交替连接这两个地址以「负载均衡」。

第一步（`-t sendtargets`）操作完成后需要进入 `/etc/iscsi/nodes/iqn.2015-11.com.hpe:storage.msa1050.1840436ed4` 删掉多余的资料，只保留第二步选定的那个 IP 对应的目录。

挂载看到 iSCSI 的卷之后，进入存储服务器的管理页面，选 Hosts，为刚才新增的那个主机补上名称。IQN 可以看主机里的 `/etc/iscsi/initiatorname.iscsi` 文件来确认。

### 更新 open-iscsi.service

open-iscsi 软件包通过 systemd 服务提供了开机自动挂载 iSCSI 的功能，但是由于我们的存储设施在一个链路上暴露了两个端口（IP 地址），直接使用该服务会导致存储被挂载两遍，后面 LVM 会产生更多的警告或错误信息。

我们没有找到一个“原生”的解决办法，所以我们直接修改服务（使用 `systemctl edit` 或手动添加 override.conf 文件）：

```dosini
[Service]
ExecStart=
ExecStart=/sbin/iscsiadm -d8 -m node -T iqn.2015-11.com.hpe:storage.msa1050.1840436ed4 -p 10.0.0.200 --login 
ExecStart=/lib/open-iscsi/activate-storage.sh
```

注意把中间那行后面的 IP 地址换掉（如果需要）。

这是一个 oneshot 类型的服务，所以修改之后就放着不用动了，下次开机时会自动应用。

## 挂载 NFS 镜像共享

挂载 NFS 共享所用的 `/etc/fstab` 条目：

```
10.0.0.1:/var/lib/vz /mnt/vz nfs rw,async,hard,intr,noexec 0 0
```

注意先在 pv1 上编辑 `/etc/exports` 并运行 `exportfs -a` 刷新挂载权限。
