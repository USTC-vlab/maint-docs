# 备份

我们配置了一个虚拟机（pbs，ID 为 104）安装 Proxmox Backup Server 提供虚拟机的备份服务。

目前该虚拟机运行在 pv8 上，从 user-data 分配了 16 GB 的 rootfs（PBS 与 PVE 同样默认使用 LVM）和 128 GB 的数据盘，挂在 `/mnt/data` 下，对应的 Datastore 名称就叫 `data`。

由于 PBS 不能加入 PVE 集群，只能添加为一个 Storage location，自然也无法使用 PVE 的账号系统。我们目前的做法是每次需要登录 web 界面时先 SSH 上去将 root 密码改掉，然后使用 root 登录，在操作完成后再 `passwd -d root`。
