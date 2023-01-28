# Vlab 实验软件套装

Vlab Software 是存放于各个主机上的 `/opt/vlab` 的软件组合，通过 bind mount 挂载进虚拟机的 `/opt/vlab` 目录，为用户提供预装的软件。因此我们也经常称为 /opt/vlab。

为了保证各用户能够及时用上统一版本的 Vlab Software，我们在 pv1 上使用 crontab 每天凌晨将 `/opt/vlab` 同步至 pv2-pv7 上，其中 crontab 条目如下：

```crontab
47 4 * * * /root/sync-software.sh
```

对应的 shell 脚本如下：

```shell
#!/bin/bash

exec >/dev/null 2>/dev/null

for node in pv{2..7}; do
  rsync -avz --delete /opt/vlab/ "$node":/opt/vlab/ &
done
wait
```

如果有对 `/opt/vlab` 修改后需要立刻同步的（一般不需要），手动执行 `/root/sync-software.sh` 即可。

## 为虚拟机配置 Vlab Software

在 `/etc/skel/.config/menus/` 下新建 `mate-applications.menu` 内容如下：

```xml
<?xml version="1.0" ?>
<!DOCTYPE Menu
  PUBLIC '-//freedesktop//DTD Menu 1.0//EN'
  'http://standards.freedesktop.org/menu-spec/menu-1.0.dtd'>
<Menu>
  <Name>Applications</Name>
  <MergeFile type="parent">/etc/xdg/menus/mate-applications.menu</MergeFile>

  <!-- Vlab -->
  <Menu>
    <Name>Vlab</Name>
    <Directory>Vlab.directory</Directory>
    <AppDir>/opt/vlab/applications</AppDir>
    <Include><And><Category>Vlab</Category></And></Include>
  </Menu>
</Menu>
```

（其他桌面环境下文件名需要做类似修改）

??? info "旧的直接修改系统文件的方法"

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
