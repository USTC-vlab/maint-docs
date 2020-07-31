# 容器内网

容器内网使用 VXLAN 实现，在所有计算服务器上均使用 ens1f1 界面连接，创建命令为

```shell
ip link add vxlan0 type vxlan id 10 group 239.1.1.1 dstport 0 dev ens1f1
```

[RFC 7348](https://tools.ietf.org/html/rfc7348) 指出 VXLAN 接收端口为 UDP 4789，因此该端口必须在 ens1f1 上开放。实际上由于 ens1f0 和 ens1f1 这两个界面没有外部接入，故不设防。

## ARP 问题

!!! success "该问题已于 2020 年 7 月 31 日解决，见下"

默认情况下 Linux 会对本机的所有 IP 地址在所有界面上响应 ARP 请求（当然 127.0.0.0/8 和 loopback 是除外的），例如一个主机拥有两个界面 ifA 和 ifB，它们分别具有 IP 地址 ipA 和 ipB，那么 Linux 会在 ifA 上响应 who-has ipB 的请求，反之亦然。

这在 2020 年上半年研究 pv8 为什么连不上 VXLAN 的时候造成了很大的困惑，因为实际上 pv8 的 ens1f1 界面是坏的（可能是光纤没插好之类的），然后系统在 ens1f0 界面上响应了实际属于 ens1f1 的 IP 地址，在其他机器上看起来就像是 ens1f1 能连通但 vxlan0 连不通，而实际上是 10.0.0.28 被解析到了 pv8 的 ens1f0 上，没故障当然就能连通了。

!!! note "iBug 备注"

    这个地方我也没想到，其实只要在其他机器上看看 ARP 缓存表（`arp -a`）就能发现两个 IP 解析出来的 MAC 一样了

解决办法就是设置 Linux 参数让其只在“正确的”界面上响应，详细参数解释参见 Server Fault 上的[这个回答][1]。我们的做法是向 `/etc/sysctl.d/arp.conf` 里写入了如下内容：

```ini
net.ipv4.conf.all.arp_ignore=1
net.ipv4.conf.all.arp_announce=2
```


  [1]: https://serverfault.com/a/834519/450575
