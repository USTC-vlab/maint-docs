# 虚拟机 VirtIO FS 文件系统配置

[virtiofsd](https://virtio-fs.gitlab.io/) 是一种将主机上的文件系统共享进虚拟机的机制，类似 NFS，但不经过网络，而是使用本地的 Unix socket 和 FUSE 语义，可以提供比 NFS 更好的性能。

## 主机配置

为 virtiofsd 创建一个模板化的 systemd 服务，以便在主机上启动 virtiofsd 服务（[文件下载](../assets/virtiofsd@.service)）：

```ini title="/etc/systemd/system/virtiofsd@.service"
--8<-- "virtiofsd@.service"
```

然后编写一个 hook script 脚本（[文件下载](../assets/virtiofsd.sh)）：

```shell title="/mnt/vz/snippets/virtiofsd.sh"
--8<-- "virtiofsd.sh"
```

## 虚拟机配置

每个想要使用 `/opt/vlab` 的虚拟机都需要配置以下两点：

```yaml
args: -chardev socket,id=virtfs0,path=/run/virtiofsd/9612.sock -device vhost-user-fs-pci,queue-size=1024,chardev=virtfs0,tag=vlab-software -object memory-backend-file,id=mem,size=6144M,mem-path=/dev/shm,share=on -numa node,memdev=mem
hookscript: nfs-template:snippets/virtiofsd.sh
```

其中 `args` 里有两点需要注意：

- `socket,[...],path=` 后面的路径需要和前面的 systemd service 中为 `virtiofsd` 指定的 socket 路径一致；
- `memory-backend-file` 的 `size` 需要和虚拟机和内存大小一致。

除此之外，`vhost-user-fs-pci` 后面的 `tag` 参数就是在虚拟机内挂载的 source。以此处的 `tag=vlab-software` 为例，虚拟机内的挂载命令为：

```shell
mount -t virtiofs vlab-software /opt/vlab
```

对应的 fstab 写法为：

```shell
vlab-software /opt/vlab virtiofs nofail 0 0
```

## 参考资料

- [\[TUTORIAL\] virtiofsd in PVE 8.0.x](https://forum.proxmox.com/threads/virtiofsd-in-pve-8-0-x.130531/)
