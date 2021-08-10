# 打包虚拟机镜像

## 从 Ubuntu cloud images 开始准备虚拟机

由于虚拟机使用 cloud-init 进行定制，我们推荐以发行版官方的 cloud image 为基础进行额外配置。

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

## 配置 Cloud-init

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

现在我们可以通过 `qm start 910` 启动虚拟机进行高级配置了。

## 后续工作

如果打包好的镜像要作为 VM 模板使用，需要迁移至各 pve 主机间的共享存储上，如 user-data。

## 参考资料

- Proxmox VE 关于 Cloud-init 的文档：<https://pve.proxmox.com/wiki/Cloud-Init_Support>
