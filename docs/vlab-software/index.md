# Vlab 实验软件套装

Vlab Software 是存放于各个主机上的 `/opt/vlab` 的软件组合，通过 bind mount 挂载进虚拟机的 `/opt/vlab` 目录，为用户提供预装的软件。因此我们也经常称为 /opt/vlab。

## 为虚拟机配置 Vlab Software

取决于所安装的桌面环境，在 `/etc/xdg/menus` 下的某个 `.menu` 文件最后的关闭标签**前**插入如下内容，也就是在最外层的 `<Menu>` 下添加一个子键。

```xml
<!-- Vlab -->
<Menu>
  <Name>Vlab</Name>
  <Directory>Vlab.directory</Directory>
  <AppDir>/opt/vlab/applications</AppDir>
  <Include><And><Category>Vlab</Category></And></Include>
</Menu>
```

例如，对于 MATE 桌面环境，文件是 `/etc/xdg/menus/mate-applications.menu`；对于 Xfce 文件名是 `xfce-applications.menu`。

同时为了使命令行环境能够正确加载 PATH，需要在 `/etc/profile.d` 下创建一个文件 `vlab.sh`：

```shell
if [ -e /opt/vlab/path.sh ]; then
  source /opt/vlab/path.sh
fi
```

如果没有 `/etc/profile.d` 目录，就将这几行代码加在 `/etc/profile` 的末尾。

最后，记得替换上 Vlab 的**专属**桌面：<https://vlab.ustc.edu.cn/downloads/background.jpg>（wget 下来放在合适的位置配置好桌面设置）
