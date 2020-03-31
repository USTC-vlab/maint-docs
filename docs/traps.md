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
