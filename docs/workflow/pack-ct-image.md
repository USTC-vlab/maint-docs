# 打包容器镜像

Proxmox VE 的容器镜像和 LXC 略有不同，所以从 LXC 下载的镜像不宜直接用于 Proxmox VE。基准镜像可以直接使用已有的 vlab 镜像（推荐），或者使用 `pveam` 命令从 Proxmox 官方下载。

同样由于镜像内容的不一致以及下面提到的一些与网络相关的设置，尝试在自己的 LXC / LXD 环境中进行镜像的配置工作可能会遇到各种各样的困难，例如权限问题、网络问题等，因此我们直接在现有的 Proxmox 集群中操作就行了。

打包的容器镜像应当在功能完整、追求开箱即用的情况下**尽可能保持精简**，例如 build-essential 可以安装，但是 Clang / LLVM 最好不要（

## 一、准备新的容器环境 {#prepare-ct}

登录集群新建一个容器，挑一个负载较低的节点（例如 pv8），把 Unprivileged container 取消勾选（默认是选中的，不取消的话后面打包时[要额外处理一下](#process-uid-for-unprivileged-containers)），模板选一个基础镜像，硬盘大小根据要装的东西估计，典型的 Ubuntu 20.04 镜像只要 4 GB 就够，这里可以选择存储为 local-lvm 以获得更好的硬盘性能（主机的 SSD）。CPU 和内存可以随意，反正这个容器是临时使用的。[容器网络](../networking/index.md)连接到 vmbr1，随便取一个没用过的 IPv4 地址（建议 172.31.0.240 - 172.31.0.255 之间），掩码是 /16，网关为 172.31.0.1，然后就可以直接下一步创建了。

## 二、基础工作 {#base-works}

本节工作只需要对从 Proxmox 直接下载的“最原始”的镜像处理。

- **换源**：将 apt / yum 源换为 `mirrors.ustc.edu.cn`
- **加入 SSH CA 公钥**：这里请加入 Vlab **User** CA（[SSH 证书认证](../ssh-ca.md)这一页下面那个）

    对于 Ubuntu 20.04 系统，其默认的 `sshd_config` 里有一行 Include，所以可以很方便地在 `/etc/ssh/sshd_config.d` 下新建一个文件用来写 `TrustedUserCAKeys`。对于其他系统，还是将配置直接追加至系统的 `sshd_config`。

- **设置系统语言**：使用 `dpkg-reconfigure locales` 生成 `en_US.UTF-8` 和 `zh_CN.UTF-8` 的语言并将中文设为默认。不要安装 `locales-all` 包，它太大了，我们用不上

下面这些工作可以凭自己喜好选做：

- **安装软件**：例如 `build-essential`, Git, Vim 等常用软件工具。请尽量保持精简
- **更新 `/etc/skel`**：例如，在 `.bashrc` 里默认启用有颜色的 PS1（限 Ubuntu / Debian），或者提供默认的 rc 类配置文件
- **更新 `/etc/motd`**：也就 SSH 登录的时候显示一下，改不改没啥区别

如果打包的目标不是带桌面环境的镜像的话，第三步就可以跳过了。

## 三、安装与测试桌面环境

桌面环境的配置较为复杂，因为要运行 VNC server 并将其作为桌面管理器的主显示输出。经过 pdlan 的调试，采用 LightDM + TigerVNC server 的组合，使用一个自己编写的启动脚本可以正常运行。这部分配置工作我们已经打包成了一个 Debian package，放在 <https://vlab.ustc.edu.cn/repo/vlab-vnc.deb>，可以直接安装，**注意使用 `--no-install-recommends`**。

由于后台 VNC server 采用了无密码的认证方式，因此额外使用 iptables 防火墙来限制只能从 web 服务器的地址连接 VNC server，该部分处理放在了 deb 的 postinst 操作中，会加上一条 IPv4 规则限制来源和一条 IPv6 规则拒绝所有连接。

桌面环境我们一般选用轻量的 Xfce（安装 `xfce4`，也要使用 `--no-install-recommends`），装好之后启动 `lightdm.service` 就可以测试了。

为了做到“开箱即用”，一般还会安装一些常用软件，如浏览器、文本编辑器等，同时安装合适的字体和输入法确保中文能够正常使用。具体来说，我们会安装：

- Firefox 浏览器
- Xfce 的小玩意 `xfce-goodies`，这个包会带上记事本计算器等小工具
- `ibus-pinyin` 或 `fcitx-libpinyin` 并配置好，作为默认的中文拼音输入法
- `fonts-droid-fallback` 或 `fonts-wqy-microhei` 作为中文字体。不要安装 `fonts-noto-sans` 等字体，它们太大了

由于桌面环境经常附带一堆用不上的东西，所以打包前多花点时间清理。

### 配置 Vlab Software

主文章：[Vlab Software](../vlab-software/index.md)

取决于所安装的桌面环境，在 `/etc/xdg/menus` 下的某个 `.menu` 文件最后的关闭标签**前**插入如下内容：

```xml
<!-- Vlab -->
<Menu>
  <Name>Vlab</Name>
  <Directory>Vlab.directory</Directory>
  <AppDir>/opt/vlab/applications</AppDir>
  <Include><And><Category>Vlab</Category></And></Include>
</Menu>
```

即将以上内容添加为最外层的 `<Menu>` 的一个子键。

创建 `/etc/profile.d/vlab.sh`，填入如下内容：

```shell
if [ -e /opt/vlab/path.sh ]; then
  . /opt/vlab/path.sh
fi
```

如果没有 `/etc/profile.d` 目录，就将这几行代码加在 `/etc/profile` 的末尾。

非 Ubuntu 虚拟机的 lightdm 可能不会加载 profile，所以需要：

```
ln -s /etc/profile.d/vlab.sh /etc/X11/Xsession.d/99vlab
```

让 lightdm 启动时更新 vlab 信息。

最后，记得替换上 Vlab 的**专属**桌面：<https://vlab.ustc.edu.cn/downloads/background.jpg>

### 测试桌面环境

只接入内网的容器中转发什么的比较麻烦（如果你会用 SSH 转发 `ssh -L` 的话当然也可以），这里提供一个使用 VNC 统一登录的办法，就是自己创建一个虚拟机，记录下 IP 之后关机，再把 IP 切换到正在安装配置的这个容器上，就可以使用 VNC 统一登录了。

LightDM 的关机重启功能无效是正常现象，放心忽略，只要 Logout 能用就基本 OK 了。

  [vlab-vnc]: https://github.com/iBug/vlab-deb/tree/master/vlab-vnc

## 四、打包前的工作 {#pre-packaging}

其实就是清理工作，避免把不必要的内容打包进镜像。下面是一些需要清理的东西：

- **`/etc/ssh`**：将生成的 Host Key 全部删掉（如果有），这样创建新容器的时候可以生成新的主机密钥对
- **`/run`, `/tmp`, `/var/{backups,cache,crash,log,tmp}`**：全部清空，注意 `/tmp`, `/var/crash` 和 `/var/tmp` 这三个目录的权限是 1777 (rwxrwxrwt)，其他目录权限都是 0755 (rwxr-xr-x)。
- **`/root` 和 `/home/<user>`**：把 `.bash_history` 之类的文件都删掉，只留下最基本的内容（如果配置了桌面环境，谨慎清理 `.config`）。

对于 Ubuntu/Debian 镜像，还（最好）要清除 apt 的缓存。可以使用 chroot 进入镜像运行 `apt-get clean`，也可以手动清空 `/var/lib/apt/lists` 目录。

当然清理之前要把容器关机了，不然 tmp 和 cache 之类的东西还会源源不断地冒出来。

## 五、打包 {#packaging}

根据第一步创建容器时选择的存储，这里涉及到的 VG 可能是 `user-data` 或 `pve`。

通过命令行登录主机，首先激活容器的文件系统：

```shell
lvchange -a y {vg}/vm-{id}-disk-0
mkdir tmp
mount /dev/{vg}/vm-{id}-disk-0 tmp
```

然后就可以进入 tmp 进行清理工作了。

最后打包要在 tmp 目录下（即容器的根目录）进行，因为（显然）tar 压缩包中的路径是有影响的。

```shell
tar zcvf /mnt/vz/template/cache/vlab99-example.tar.gz .
```

### Unprivileged container 打包后的 UID/GID 处理 {#process-uid-for-unprivileged-containers}

如果容器创建时设置为了 unprivileged，则其存在文件系统中的 UID/GID 等都被 LXC 映射到了 +100000（10 万）的数值，打包后需要将这增加的数值修改回来。参考[这个 Stack Overflow 主题][tar-uid]，使用这个 Go 程序可以改写 tar 中的文件信息：

  [tar-uid]: https://stackoverflow.com/q/39153605/5958455

??? abstract "Go 代码"

    ```go
    package main    

    import (
        "archive/tar"
        "io"
        "log"
        "os"
    )

    func main() {
        tr := tar.NewReader(os.Stdin)
        tw := tar.NewWriter(os.Stdout)

        for {
            hdr, err := tr.Next()
            if err == io.EOF {
                break
            } else if err != nil {
                log.Fatal(err)
            }

            hdr.Uid -= 100000
            hdr.Gid -= 100000
            if err := tw.WriteHeader(hdr); err != nil {
                log.Fatal(err)
            }

            if hdr.Typeflag == tar.TypeReg {
                if _, err := io.Copy(tw, tr); err != nil {
                    log.Fatal(err)
                }
            }
        }

        if err := tw.Close(); err != nil {
            log.Fatal(err)
        }
    }
    ```

!!! info "使用 Go 程序改写 tar 包"

    上面的 Go 示例程序只能处理未压缩的 tar 包，如果你在打包时加入了 `z` 或其他压缩参数，需要先解压再输入程序，例如：

    ```shell
    gunzip -c original.tar.gz | go run script.go | gzip -c9 > processed.tar.gz
    ```

打包完成后要把 django 前端 reload 一下才能在“新建虚拟机”的页面看到新镜像。
