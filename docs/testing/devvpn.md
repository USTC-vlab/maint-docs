# VPN for Vlab devs

为了方便参与开发的同学连接校园网，我们开设了一个 OpenVPN Server 运行在 [gateway（CT 100）](../servers/ct100.md)上。

## 使用方式

登录进 gateway，切换目录至 `/etc/openvpn/ca`，运行 `./genconf.sh '<Common Name>'`，其中 `<Common Name>` 为标识客户端的名称（X.509 证书的 Common Name 字段，建议使用姓名或昵称等能够辨认的名称）。如果一切正常，就能在 `clients` 目录中生成一个 `<Common Name>.ovpn` 文件，将该文件分发给用户，使用 OpenVPN 客户端导入并连接即可。

## 配置 OpenVPN Server {#configure}

!!! info "服务端只需配置一次，以下记录作为参考"

安装软件包：

```sh
apt install --no-install-recommends openvpn easy-rsa
```

### 证书系统 {#openvpn-pki}

```sh
cd /etc/openvpn
make-cadir ca
cd ca
./easyrsa init-pki
./easyrsa build-ca nopass
```

至此在 `/etc/openvpn/ca/pki` 目录下就有一堆准备好的文件，可以开始签证书了。

首先给服务端签一个证书：

```sh
./easyrsa build-server-full 'Vlab VPN Server' nopass
```

然后把 `pki/issued/Vlab VPN Server.crt` 和 `pki/issued/Vlab VPN Server.key` 复制到 `/etc/openvpn/server` 下，分别命名为 `server.crt` 和 `server.key`。

接下来每个客户端都用这样的命令签一个证书，注意 Common Name 不要重复。

```sh
./easyrsa build-client-full '<Client Name>' nopass
```

现在 `pki/issued` 下和 `pki/private` 下就有了一套证书和密钥，可以用它们来制作客户端配置文件了（见下）。

### OpenVPN Server

复制一份样例 `server.conf`：

```sh
cp /usr/share/doc/openvpn/examples/sample-config-files/server.conf.gz /etc/openvpn/server/
gunzip /etc/openvpn/server/server.conf.gz
```

编辑 `server.conf`:

```diff
 ;dev tap
-dev tun
+dev ovpn
+dev-type tun
```

```diff
-;topology subnet
+topology subnet
```

```diff
-server 10.8.0.0 255.255.255.0
+server 192.168.254.0 255.255.255.0
```

```diff
-tls-auth ta.key 0 # This file is secret
+;tls-auth ta.key 0 # This file is secret
```

```diff
-;push "route 192.168.10.0 255.255.255.0"
-;push "route 192.168.20.0 255.255.255.0"
+push "route 172.31.0.0 255.255.0.0"
+push "route 202.38.75.85 255.255.255.255"
+push "route 202.38.75.4 255.255.255.255"
+push "route 202.38.75.24 255.255.255.255"
```

```diff
-cipher AES-256-CBC
+cipher AES-256-GCM
```

```diff
-;user nobody
-;group nogroup
+user nobody
+group nogroup
```

生成 DH 参数文件：

```sh
openssl dhparam -out /etc/openvpn/server/dh2048.pem 2048
```

### 编写客户端配置文件 {#openvpn-client-conf}
