# Proxmox VE 主机

我们尽量保证 PVE 主机干净整洁，只安装配置必须运行在主机上的服务，减轻维护压力。

## pv1

### 更新 SSL 证书 {#ssl}

由于 Proxmox VE 主机没有出校权限，因此主机使用的 SSL 证书（`*.ibuglab.com`）需要通过 web 容器（CT 101）更新，再从 web 容器中取回。我们配置了如下脚本，使用 cron 每天从 web 容器中同步证书：

```sh title="/etc/cron.daily/sync-cert"
--8<-- "sync-cert"
```

### PVE Agent

由于 LXC 容器的一些设置（如 bind mount）必须通过 root@pam 用户登录时才能修改，而我们并不想在 django 中存储主机的 root 用户密码，因此写了这个 agent 放在主机上，通过 HTTP API 提供这些功能，后端直接调用主机上的 `pvesh` 命令。pvesh 命令在主机上执行时会自动以执行该命令的 Linux 用户认证，因此只要该 agent 以 root 运行，就能通过 `pvesh` 调用这些需要 root@pam 用户的 PVE API。

代码在 [vlab-pve-agent](https://github.com/USTC-vlab/vlab-pve-agent) 仓库中，配置文件为 `/etc/vlab-pve-agent.json`，对应的 systemd service 为 `vlab-pve-agent.service`。

### Recovery SSHd

PVE 主机上可以使用 `pct enter` 和 `pct console` 命令获取 LXC 容器中的一个 shell 或者接入 /dev/tty0，但该“接口”不在 PVE API 中提供。考虑到这两个接口的主要连接方式是 SSH，因此我们写了这个 recovery SSHd 放在 pv1 上运行，供 sshpiper 调用。

代码在 [recovery-sshd](https://github.com/USTC-vlab/recovery-sshd) 仓库中，配置文件为 `/etc/recovery-sshd.json`，对应的 systemd service 为 `recovery-sshd.service`。
