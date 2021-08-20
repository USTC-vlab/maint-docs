# 杂项

## 列出集群中所有容器 {#list-all-vms}

首先 `apt install jq`（这个工具很小，不用担心弄乱系统环境），然后

```shell
jq -r '.ids | to_entries[] | select(.value.type == "lxc") | .key' /etc/pve/.vmlist
```

如果要列出虚拟机的话，将 select type 换成 qemu 即可；如果两者都要列出的话，直接去掉 select 这个 filter。

参考资料：

- [List all VMID's from command line? | Proxmox Support Forum](https://forum.proxmox.com/threads/list-all-vmids-from-command-line.10964/)
  