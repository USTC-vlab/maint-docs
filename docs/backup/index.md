# 备份

我们在 pv1 上同时安装了 Proxmox Backup Server 相关软件以提供虚拟机的备份服务。

```text title="/etc/apt/sources.list.d/pve.list"
deb https://mirrors.ustc.edu.cn/proxmox/debian/pve bookworm pve-no-subscription
deb https://mirrors.ustc.edu.cn/proxmox/debian/pbs bookworm pbs-no-subscription
```

由于 PBS 不能加入 PVE 集群，只能添加为一个 Storage location，自然也无法使用 PVE 的账号系统。我们目前的做法是每次需要登录 web 界面时先 SSH 上去将 root 密码改掉，然后使用 root 登录，在操作完成后再 `passwd -d root`。如果你需要经常登录 PBS 的话，可以给自己建一个账号，注意它与 PVE 账号是独立的。
