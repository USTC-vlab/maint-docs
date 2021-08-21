# 容器内网

容器内网使用 VXLAN 实现，在所有计算服务器上均使用 bond1 界面连接，创建命令为

```shell
ip link add vxlan0 type vxlan id 1 group 239.1.1.1 dev bond1
```

<s>[RFC 7348](https://tools.ietf.org/html/rfc7348) 指出 VXLAN 接收端口为 UDP 4789</s>，但由于历史原因包括 Linux 在内的一众厂商都在使用 UDP 8472，因此该端口必须在 bond1 上开放。实际上由于光纤界面没有外部接入，故不设防。

## IP 地址分配

内容已移至 [IP 地址分配](ips.md)。
