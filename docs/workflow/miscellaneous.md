# 杂项

## 列出集群中所有容器 {#list-all-vms}

首先 `apt install jq`（这个工具很小，不用担心弄乱系统环境），然后

```shell
jq -r '.ids | to_entries[] | select(.value.type == "lxc") | .key' /etc/pve/.vmlist
```

如果要列出虚拟机的话，将 select type 换成 qemu 即可；如果两者都要列出的话，直接去掉 select 这个 filter。

参考资料：

- [List all VMID's from command line? | Proxmox Support Forum](https://forum.proxmox.com/threads/list-all-vmids-from-command-line.10964/)

## 从主机上寻找 PID 所属的容器

!!! success "使用 Vlab Container Tool 工具"

    我们已将方法 1 整合进 [Vlab Container Tool 工具](https://github.com/USTC-vlab/vct)，可以使用 `vct findpid <pid>...` 来查找 PID 所属的容器。

### 方法 1

进程的 cgroup 结构里包含了容器 ID，例如：

```console
# cat /proc/114514/cgroup
0::/lxc/6666/ns/system.slice/lightdm.service
```

所以只需要对着这个 cgroup 文件 grep 出来即可：

```shell
grep -Po '/lxc/\K\d+' /proc/$PID/cgroup
```

### 方法 2

思路：从 `/proc` 里不断读取其父 PID 直到找到容器里的 PID 1，这个 "PID 1" 的父进程 `lxc-start` 的命令行里可以看到容器 ID。

参考代码：

```shell
#!/bin/sh

PID="$1"

while :; do
  procfile="/proc/$PID/status"
  name=$(awk '$1=="Name:"{print $2}' "$procfile")
  ppid=$(awk '$1=="PPid:"{print $2}' "$procfile")
  if [ "$name" = "lxc-start" ]; then
    tr '\0' ' ' < "/proc/$PID/cmdline" | cut -d' ' -f4
    break
  elif [ "$ppid" -eq 1 ]; then
    echo Failed
    exit 1
  else
    PID="$ppid"
  fi
done
```

## 调试容器启动失败的原因

PVE 的容器采用 systemd 管理，所以首先可以 `systemctl status pve-container@114514` 查看情况。如果这里没有足够的日志，可以把 ExecStart 命令拷下来手动运行，例如：

```shell
/usr/bin/lxc-start -F -n 114514
```

然后按提示加上 `--logfile /dev/stdout --logpriority INFO`（或者 DEBUG），应该就有足够详细的日志来判断问题了。

## 为容器添加 rootless container 支持

### 添加 `lxc.idmap` 配置

由于 PVE 默认会强塞一条 lxc.idmap 配置，而且无法通过全局设置移除，且 API 不支持设置 lxc 底层配置，因此需要在对应 node 上手动编辑 `/etc/pve/lxc/<vmid>.conf`，添加如下配置：

```
lxc.idmap: u 0 100000 165536
lxc.idmap: g 0 100000 165536
```

配完对容器关机再开机即可。

### 安装 lightdm hooks（无桌面环境可跳过）

修复 lightdm 对 seat0 处理不正确，导致 systemd user session 不正确的问题：

```shell
sudo apt install lightdm-hooks
```

### 配置 TUN 设备

```shell
sudo /opt/vlab/.dev/enable-dev.sh
```

### 测试

```shell
podman ps
podman run -it --rm ghcr.io/ustclug/debian:13
```
