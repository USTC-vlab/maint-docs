# 容器内网

容器内网使用 VXLAN 实现，在所有计算服务器上均使用 ens1f1 界面连接，创建命令为

```shell
ip link add vxlan0 type vxlan id 10 group 239.1.1.1 dstport 0 dev ens1f1
```

[RFC 7348](https://tools.ietf.org/html/rfc7348) 指出 VXLAN 接收端口为 UDP 4789，因此该端口必须在 ens1f1 上开放。实际上由于 ens1f0 和 ens1f1 这两个界面没有外部接入，故不设防。
