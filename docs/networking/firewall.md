# 服务器防火墙配置

防火墙使用 Linux 自带的 iptables 管理，默认策略为 `INPUT DROP`, `FORWARD ACCEPT`, `OUTPUT ACCEPT`。方便起见使用 `iptables-persistent` 让防火墙规则开机自动加载。

以下为 pv1 上的防火墙配置（`/etc/iptables/rules.v4` 和 `rules.v6` 文件内容一样）：

!!! todo "pv1 的额外配置"
    pv1 需要修改以下配置，额外放行 8090 端口，以用于虚拟机创建时初始化。

```shell
*filter
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
:VLAB - [0:0]
-A INPUT -i lo -j ACCEPT
-A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
-A INPUT -p icmp -j ACCEPT
-A INPUT -i vmbr+ -j VLAB
-A INPUT -i ens1f0 -j ACCEPT
-A INPUT -i ens1f1 -j ACCEPT
-A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -i vmbr+ -j DROP
-A VLAB -p tcp -m state --state NEW -m tcp --sport 1024:65535 -m multiport --dports 22,80,443,8006 -j ACCEPT
-A VLAB -j DROP
COMMIT


*nat
:PREROUTING ACCEPT [0:0]
:INPUT ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
:POSTROUTING ACCEPT [0:0]
-A PREROUTING -m addrtype --dst-type LOCAL -p tcp --dport 443 -j REDIRECT --to-ports 8006
COMMIT
```

## 部分防火墙规则解释 {#explanations}

```shell
-A INPUT -i lo -j ACCEPT
-A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
```

这两个放最前面，让本机流量 `-i lo` 和已经建立起来的 TCP / UDP 连接经过最少的链项，提高性能降低 CPU 使用量，这是因为 iptables 规则是按顺序逐条匹配的。

```shell
-I INPUT -i ens1f0 -j ACCEPT
-I INPUT -i ens1f1 -j ACCEPT
```

光纤内网不设防。
