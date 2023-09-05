# 打包虚拟机镜像

!!! success

    我们已将此任务部分自动化，脚本和相关资源在 [labstrap](https://github.com/USTC-vlab/labstrap) 仓库中。相关文件为 `kvmstrap`（shell 脚本）和其引用的 rootfs 相关内容，特别是 `/etc/cloud/cloud.cfg` 文件。

由于 Proxmox VE 上的虚拟机使用 cloud-init 进行定制，我们推荐以发行版官方的 cloud image 为基础进行额外配置。

## 使用 kvmstrap 构建镜像

首先从 ubuntu-cloud-images 获取一个 cloud image 镜像，以 Ubuntu 22.04 LTS 为例，从科大镜像站下载文件：

- <https://mirrors.ustc.edu.cn/ubuntu-cloud-images/jammy/current/jammy-server-cloudimg-amd64.img>

虽然该文件以 .img 结尾，但实际上是一个 qcow2 格式的镜像。在当前系统中准备好 `qemu-img`（软件包 qemu-utils）和 `guestmount`（软件包 libguestfs-tools）之后即可使用 kvmstrap 脚本修改镜像：

```shell
./kvmstrap jammy-server-cloudimg-amd64.img
```

修改好的镜像可以直接上传到 Proxmox VE 服务器上，然后在 web 界面创建一个虚拟机，并用上传上去的镜像替换虚拟机的磁盘即可。

!!! tip

    以下内容是我们在自动化之前的手动打包流程，留作参考。

## 一、从 Ubuntu cloud images 开始准备虚拟机

以 Ubuntu 20.04 LTS 为例，首先下载 <https://mirrors.ustc.edu.cn/ubuntu-cloud-images/focal/current/focal-server-cloudimg-amd64.img> 到本地。

首先创建一个临时虚拟机（注意将 ID 910 换成一个合适的空闲 [ID](../references/pve-ids.md)）

```shell
qm create 910 --memory 2048 --net0 virtio,bridge=vmbr1
```

将刚下载的镜像导入新虚拟机（这个 img 镜像实际上是 qcow2 格式）并挂载为 SCSI 硬盘，将新硬盘设为启动盘

```shell
qm importdisk 910 focal-server-cloudimg-amd64.img local-lvm
qm set 910 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-910-disk-1
qm set 910 --boot c --bootdisk scsi0
```

## 二、配置 Cloud-init

这一步可以完全在 Proxmox VE web 界面上操作，下面还是给出命令行指导。

添加 Cloud-init 配置盘（官方文档里是添加为 IDE 盘，实际加成 SCSI 的也没问题，这里跟随官方）

```shell
qm set 910 --ide2 local-lvm:cloudinit
```

为虚拟机提供网络信息（注意把 IP 地址改掉）：

```shell
qm set 910 --ipconfig0 ip=172.31.0.256/16,gw=172.31.0.1,ip6=auto
```

??? note "可选项目：将 console 设为串口"

    Proxmox VE 官方文档里的说明：

    > Many Cloud-Init images rely on this, as it is an requirement for OpenStack images.

    ```shell
    qm set 910 --serial0 socket --vga serial0
    ```

!!! note "可选项目：开机"

    现在我们可以通过 `qm start 910` 启动虚拟机进行高级配置了。

    看完第三章和第四章之后你就知道为什么将虚拟机开机是可选的了。

## 三、镜像的处理

我们认为 KVM 虚拟机的受众是不需要桌面环境和 Vlab Software 进行较为“通用”的实验和计算的用户，因此我们在 KVM 镜像中不提供桌面环境和 [`/opt/vlab`](../vlab-software/index.md)（其实要弄还有点麻烦），所以对于下载下来的官方镜像，我们只需要进行[最基本的修改](pack-ct-image.md#base-works)即可。

## 四、打包前的工作 {#pre-packaging}

与[打包容器镜像前的清理工作](pack-ct-image.md#pre-packaging)一样。

### 挂载虚拟机磁盘

注意 KVM 的“卷”是一个完整的磁盘，而容器的“卷”只包含 rootfs 所在的文件系统，因此要挂载 KVM 的 rootfs 需要先处理磁盘分区的问题。我们推荐使用 kpartx 工具。

```shell
kpartx -av /dev/pve/vm-910-disk-0
```

你会看到类似这样的输出：

```text
add map pve-vm--910--disk--0p1 (253:19): 0 4384735 linear 253:14 227328
add map pve-vm--910--disk--0p14 (253:23): 0 8192 linear 253:14 2048
add map pve-vm--910--disk--0p15 (253:24): 0 217088 linear 253:14 10240
```

根据容量判断，p1 就是虚拟机的 rootfs，此时就可以挂载 `/dev/mapper/pve-vm--910--disk--0p1` 进行清理工作了。

清理完成并 umount 后，可以使用 `kpartx -d /dev/pve/vm-910-disk-0` 删除分区映射。

同样的，取决于虚拟磁盘的位置，PVE 有可能会在关机后将虚拟磁盘的 LVM 卷设置为 inactive，需要使用 `lvchange` 先激活，参见打包容器镜像的[章节](pack-ct-image.md#packaging)。

## 五、打包 {#packaging}

如果打包好的镜像要作为 VM 模板使用，需要迁移至各 pve 主机间的共享存储上，如 user-data。

## 参考资料 {#references}

- Proxmox VE 关于 Cloud-init 的文档：<https://pve.proxmox.com/wiki/Cloud-Init_Support>
