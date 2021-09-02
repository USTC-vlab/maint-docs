# SSH 证书认证

所有 Proxmox VE 主机及几个特殊容器（[CT100 gateway](servers/ct100.md)，[CT101 web](servers/ct101.md) 和其他 ID 为 1xx 的容器/虚拟机）的 SSH 登录均使用证书。

关于 OpenSSH 的证书认证方式，可以参考 [iBug 的博客](https://ibug.io/p/30)（英文）以及校 Linux 用户协会的[服务器维护文档](https://docs.ustclug.org/infrastructure/sshca/)。

CA 公钥：

```text
--8<-- "vlab_ca.pub"
```

可以在服务器上直接使用 Wget 或 cURL 获取：

```shell
wget -O /etc/ssh/ssh_user_ca https://vlab.ibugone.com/assets/vlab_ca.pub
```

然后准备 `/etc/ssh/sshd_config.d/vlab.conf`：

```conf
HostKey /etc/ssh/ssh_host_rsa_key
HostCertificate /etc/ssh/ssh_host_rsa_key-cert.pub
TrustedUserCAKeys /etc/ssh/ssh_user_ca

AuthorizedKeysFile /dev/null  # 屏蔽不带证书的公钥认证
PermitRootLogin prohibit-password
PasswordAuthentication no
```

## 用户 CA

由于 Proxmox VE 没有提供直接在容器内执行命令的 API，因此我们通过内嵌 SSH CA 的方式自己造个轮子。

出于管理的考虑，用户 CA 和主机 CA 独立。公钥：

```text
--8<-- "vlab_user_ca.pub"
```

可以在虚拟机中直接使用 Wget 或 cURL 获取：

```shell
wget -O /etc/ssh/ssh_user_ca https://vlab.ibugone.com/assets/vlab_user_ca.pub
```

将 CA 添加至容器或虚拟机的操作与上面类似，但是不需要对主机公钥进行签名，因此只需要

- 将以上公钥保存至某个文件，如 `/etc/ssh/ssh_user_ca`
- 在 `sshd_config` 中追加，或者创建 `/etc/ssh/sshd_config.d/vlab.conf` 并写入

    ```
    TrustedUserCAKeys /etc/ssh/ssh_user_ca
    ```

    注意使用 `sshd_config.d` 前要确认软件包提供的 `sshd_config` 包含了 Include 语句，否则请直接修改 `sshd_config`。
