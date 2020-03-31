# 远程桌面配置与管理

vnc-multiplexer (以下简称 vncmux) 用于实现 VNC 统一登录。vncmux 用户在登录中输入的用户名、密码，将被程序通过 API 发送给 Django 后端，并得到内网客户机的 VNC 服务器连接信息，以此实现转发。除了简单的转发数据，vncmux 还会对 VNC 协议的消息进行解析、修改，以此实现通知功能。以下简介 vncmux 的配置和管理方法。

## 配置文件

vncmux 的配置文件存储在 `/etc/vnc_multiplexer/config.json`，目前如下：

```json
{
    "port": 5900,
    "api": "http://127.0.0.1:8000/vm/vnc/",
    "cert_chain_file": "/etc/letsencrypt/live/vlab.ustc.edu.cn/fullchain.pem",
    "private_key_file": "/etc/letsencrypt/live/vlab.ustc.edu.cn/privkey.pem",
    "dhparam_file": "/etc/vnc_multiplexer/dhparam.pem",
    "ra2_private_key_file": "/etc/vnc_multiplexer/ra2.pem",
    "enabled_protocol": ["RA2r_256", "RA2r", "RA2_256", "RA2", "VeNCrypt"],
    "enable_log": true,
    "logger_ip": "127.0.0.1",
    "logger_port": 5555,
    "enable_notification": true,
    "notification_file": "/etc/vnc_multiplexer/notification0327.png",
    "enable_admin": true,
    "admin_port": 5557,
    "enable_websocket": true,
    "websocket_port": 5801,
    "enable_tight_translation": true,
    "tight_jpeg_level": 7,
    "threads": 8
}
```

其中各项意义如下：

* `api`： Django 后端 API 的 URL ，请注意不得使用 HTTPS。

* `cert_chain_file`： TLS 证书文件，不用更改。

* `private_key_file`： TLS 私钥文件，不用更改。

* `dhparam_file`： DH 对文件，不用更改。

* `ra2_private_key_file`： RealVNC 协议私钥文件，用于证明服务器的身份。必须为 PKCS#8 RSA 2048 私钥文件。

* `enabled_protocol`： 允许的协议。`VeNCrypt` 为 TigerVNC 使用的协议。 `RA2`, `RA2r`, `RA2_256`, `RA2_256` 均为 RealVNC 的加密协议, `RA2ne`, `RA2ne_256` 为 RealVNC 使用的非加密协议，建议关闭。

* `enable_log`： 是否开启日志。日志将在每个连接关闭后通过 UDP 报文发送给日志服务器。

* `logger_ip`： 日志服务器 IP

* `logger_port`： 日志服务器端口

* `enable_notification`： 是否开启通知功能。若开启，每个用户连接后 vncmux 都将在画面上注入一个可关闭的对话框用以显示通知。

* `notification_file`： 通知图片文件。必须为 PNG 格式。由于调色板原因，建议使用黑白图片。

* `enable_admin`： 是否开启管理端口。若开启， vncmux 将在一个 TCP 端口上接收管理命令，以此与 vncmux-cli 工具连接。

* `admin_port`： 管理端口号

* `enable_websocket`： 是否开启 WebSocket 功能。noVNC 必须使用此功能，因此总是应该开启。这里的 WebSocket 连接是未加密的，需要使用 Nginx 反代。

* `websocket_port`： WebSocket 服务端口

* `enable_tight_translation`： 是否给 RealVNC 开启有损压缩。默认情况下 RealVNC 连接 TigerVNC 服务端只支持无损压缩。此功能将 TigerVNC 发出的 Tight 编码数据转换成 RealVNC 可读的格式，以此实现使用 JPEG 压缩。开启后可以让 RealVNC 流畅很多，但是可能降低画质。

* `tight_jpeg_level`： RealVNC 有损压缩的质量等级。取值范围是 0 到 9。如果为 8 接近无损。

* `threads`： 工作线程数

## vncmux-cli 工具

vncmux-cli 工具用于管理运行中的 vncmux 服务器。连接到 vncmux 服务器的方法如下：

```shell
vncmux-cli 127.0.0.1 5557
```

连接后输入 `exit` 可以退出，输入 `help` 可以显示帮助，还可以进行以下操作：

### 列出在线用户

输入 `list` 即可列出在线用户的信息，包括连接 ID 、连接时间、用户名、主机 IP 、用户 IP 、客户端类型。

### 更换通知图片

输入 `load-notification <image file>` 可以更换通知文件，通知文件最好是绝对路径。当前已在线的用户将不会看到新的通知。

### 发送图片

可以发送 PNG 格式的图片给一个或多个用户。命令格式为 `send-image <image file> <id> [id] ...` ，其中 id 可以从 `list` 的输出得知。

### 打开和关闭通知

命令分别为 `enable-notification` 和 `disable-notification`

### 打开和关闭 RealVNC 有损压缩

命令分别为 `enable-realvnc-lossy` 和 `disable-realvnc-lossy`

### 设定 RealVNC 有损压缩质量等级

命令为 `set-realvnc-jpeg-level <0-9>`