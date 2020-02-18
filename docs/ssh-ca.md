# SSH 证书认证

所有 8 台 Proxmox VE 主机及两个特殊容器（CT100 gateway 和 CT101 web）的 SSH 登录均使用证书。

关于 OpenSSH 的证书认证方式，可以参考 [iBug 的博客](https://ibugone.com/p/30)（英文）以及校 Linux 用户协会的[服务器维护文档](https://docs.ustclug.org/infrastructure/sshca/sshca/)。

CA 公钥：

```text
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQD6KdAJzKLswXyjf4SipNL1dlK1Vq0KNOit/MTDLiamkqvHJDiKceLYmN97y3Chdx8ofXwW6sRUBJRrjmYq6M0JZSGc8roUtUnSai1P5q1kZQ59x1IhsduTg4WENSteSB6vIvpyoSmcIhi3v9UHgUsl4MsnHxffxx5BiyW7UHPY3MzzkRZL96A4QXUOFd9P+NED3zHmEZ9B2Q66+s2ep2FmNralK4XwRaVxBO2r9san8vYU5pH2TzYZLYxNZ/AFX3bLV5M+AmZytaSNLcuIzZHyqbYawvD+Lee00VB9A3JcaqsjDUCtHZ5gQsZMmqw2r7gj9lDqM6Fw6A8y5rWNJP3Q+FOEEYvzGnQ/SnzU0MpMvGpYWrm/uCJ8pFdbYTYkxAJ+VO0lJ5mAIN664cX0DQ3OyGH/xmCNWGGCfGfmvWqwMwD6Kzo06xcqzsoqaMxwgBuVyICE+VvVCf3pcX4HERDrZY0TMjZxaTc8Ws2xQHJbqekv6nIjQWUgH7LIjkYvycQkxXE2dWfDy/c2SRiKWuxW9n8Hymmfp3lbBHzlCa/LtHeuPIzmBUHUoGya0feWFjrbGnKcPs3etNqpvyIGngMaecTAsbrf5v+J1M0VLCfwzwLt13/G1BCb+BK22vYzMTusrR+6A68Fm6OWSFlBYp31uVLxPg0nqtiW8bi1FbD0hQ==
```

`sshd_config` 相关配置：

```conf
HostKey /etc/ssh/ssh_host_rsa_key
HostCertificate /etc/ssh/ssh_host_rsa_key-cert.pub

AuthorizedKeysFile /dev/null  # 屏蔽公钥认证

PermitRootLogin prohibit-password

PasswordAuthentication no
```
