# VPN for Vlab devs

为了方便参与开发的同学连接校园网，我们开设了一个 OpenVPN Server 运行在 [gateway（CT 100）](../servers/ct100.md)上。

## 使用方式

登录进 gateway，切换目录至 `/etc/openvpn/ca`，运行 `./genconf.sh '<Common Name>'`，其中 `<Common Name>` 为标识客户端的名称（X.509 证书的 Common Name 字段，建议使用姓名或昵称等能够辨认的名称）。如果一切正常，就能在 `clients` 目录中生成一个 `<Common Name>.ovpn` 文件，将该文件分发给用户，使用 OpenVPN 客户端导入并连接即可。

## 配置 OpenVPN Server

!!! info "未完待续"
