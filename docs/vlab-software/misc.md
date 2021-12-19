# Vlab 实验软件套装相关记录

## 在 LXC 中以 Ubuntu 18.04 Docker 容器运行 Vivado 2019.1

运行 Ubuntu 18.04 容器：

```shell
sudo docker run -it -e DISPLAY=$DISPLAY -e LANG="zh_CN.UTF-8" -v /tmp/.X11-unix/:/tmp/.X11-unix -v /opt/vlab:/opt/vlab -v /home/ubuntu:/user --rm ustclug/ubuntu:18.04
```

在启动的 Docker 容器中:

- 安装相关依赖
- 配置 locales（否则浏览文件中含中文会抛出异常）
- 添加用户（否则会出现权限错误 `connect(3, {sa_family=AF_UNIX, sun_path=@"/tmp/.X11-unix/X0"}, 20) = -1 ECONNREFUSED (Connection refused)`）：

```shell
apt update
apt install libx11-6 libxext6 libxrender1 libxtst6 libxi6 locales
locale-gen zh_CN.UTF-8
adduser vlab  # 需要让容器中用户 PID 与外面相同
su vlab
/opt/vlab/bin/vivado
```
