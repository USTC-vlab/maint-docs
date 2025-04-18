---
icon: material/clock-outline
---

# 更新历史

记录我们上线部署新功能（或 bug fix 等）的历史。

编写时请按时间倒序排序，即最新的日期在最上面。有专门的工作记录页面的请把时间链接到对应的页面。

## 更新记录

### 2024 年

11 月 5 日

:   配置了 KVM 虚拟机通过 [virtiofsd](kvm/virtiofsd.md) 使用 `/opt/vlab` 的方法，但是由于技术细节较为复杂（及与预期的 KVM 使用方式不符），暂时没有尝试自动化 KVM virtiofsd 配置。

7 月 18 日

:   为了处理学校邮件系统升级事宜，我们更换了存储服务器的 SMTP 邮件密码。[测试中发现 HPE MSA 如果要发送测试邮件，那么邮件等级必须要设置为最后一项（发送包括 information 在内的全部内容），否则测试邮件不会发送](https://support.hpe.com/hpesc/public/docDisplay?docId=sd00002146en_us&page=GUID-2FD89E8A-5484-44AE-BD6D-80BDF9B45270.html)。

    第一代的 HPE MSA 存储服务器由于未知原因，无法正常发信至学校服务器，因此设置为使用另一台邮件服务器代发信，作为临时的解决方案。新的存储服务器能够正常发信。

7 月 5 日

:   修复了使用较新的 OpenSSH 客户端（&gt;= 9.5）连接 sshmux，且虚拟机中的 OpenSSH 服务端较老（&lt; 9.5）时，按任意键盘按键会导致连接断开的问题。

    ??? example "细节"

        在 sshmux 中添加输出打印连接断开的理由，发现错误内容为：

        ```text
        ssh: disconnect, reason 2: Invalid ssh2 packet type: 192
        ```

        检查 `x/crypto/ssh` 的代码未发现相关字符串，然后在虚拟机内关闭 sshd 并手动以 debug 模式启动（`/usr/sbin/sshd -ddd`），发现如下输出：

        ```text
        debug3: receive packet: type 192
        debug2: sshpkt_disconnect: sending SSH2_MSG_DISCONNECT: Invalid ssh2 packet type: 192
        ```

        查询 SSH packet type，发现 [RFC 4250 § 4.1.3](https://datatracker.ietf.org/doc/html/rfc4250#section-4.1.3) 将 192-255 定义为 private use，也就是 OpenSSH 使用这些数值实现了自己的扩展。

        同时检查 `x/crypto/ssh` 和 OpenSSH 的代码，发现相互匹配的定义：

        ```go title="golang.org/x/crypto/ssh/handshake.go"
        // Transport layer OpenSSH extension. See [PROTOCOL], section 1.9
        const msgPing = 192

        type pingMsg struct {
            Data string `sshtype:"192"`
        }

        // Transport layer OpenSSH extension. See [PROTOCOL], section 1.9
        const msgPong = 193

        type pongMsg struct {
            Data string `sshtype:"193"`
        }
        ```

        ```c title="ssh2.h"
        /* transport layer: OpenSSH extensions */
        #define SSH2_MSG_PING                   192
        #define SSH2_MSG_PONG                   193
        ```

        继续搜索发现 [OpenSSH 9.5 (2023/08/27)](https://undeadly.org/cgi?action=article;sid=20230829051257) 引入了 Keystroke timing obfuscation，对应这两个新的 message type。

        问题在于，使用较新的客户端和较新的 `x/crypto` 写成的 sshmux 服务端会协商出这个扩展，而 sshmux 直接在客户端和上游服务端之间转发所有的 SSH packet，忽略的服务端支持的扩展，导致了客户端发送了一个服务端不认识的 packet，从而使服务端断开连接。

        OpenSSH 9.6 客户端和基于 `x/crypto` v0.24.0 服务端的日志节选如下：

        ```text
        debug1: SSH2_MSG_EXT_INFO received
        debug1: kex_ext_info_client_parse: server-sig-algs=<ssh-ed25519,sk-ssh-ed25519@openssh.com,sk-ecdsa-sha2-nistp256@openssh.com,ecdsa-sha2-nistp256,ecdsa-sha2-nistp384,ecdsa-sha2-nistp521,rsa-sha2-256,rsa-sha2-512,ssh-rsa,ssh-dss>
        debug1: kex_ext_info_check_ver: ping@openssh.com=<0>
        debug2: service_accept: ssh-userauth
        debug1: SSH2_MSG_SERVICE_ACCEPT received
        ```

        而同样的客户端直连 OpenSSH 8.9 服务端（Ubuntu 22.04）的日志节选如下：

        ```text
        debug1: SSH2_MSG_EXT_INFO received
        debug1: kex_ext_info_client_parse: server-sig-algs=<ssh-ed25519,sk-ssh-ed25519@openssh.com,ssh-rsa,rsa-sha2-256,rsa-sha2-512,ssh-dss,ecdsa-sha2-nistp256,ecdsa-sha2-nistp384,ecdsa-sha2-nistp521,sk-ecdsa-sha2-nistp256@openssh.com,webauthn-sk-ecdsa-sha2-nistp256@openssh.com>
        debug1: kex_ext_info_check_ver: publickey-hostbound@openssh.com=<0>
        debug2: service_accept: ssh-userauth
        debug1: SSH2_MSG_SERVICE_ACCEPT received
        ```

        因此确认问题为 sshmux 向客户端宣告支持 `ping@openssh.com` 扩展，并转发了 packet type 192。

        解决方法是在 `x/crypto/ssh` 中找到 `ext_info` 相关代码并从中删掉 `ping@openssh.com` 的支持：[`42b2075` @ USTC-vlab/sshmux](https://github.com/USTC-vlab/sshmux/commit/42b20754147cb6d9264d92c005b765fedb269593)

7 月 4 日

:   由于 RegreSSHion（CVE-2024-6387）漏洞，修改防火墙使虚拟机的 22 端口只能从 web 容器连接，避免用户内网内部互相扫描爆破。

    另外修复了 sshmux 由于上游 `x/crypto` 更新导致 SSH 连接出现 `sign_and_send_pubkey: no mutual signature supported` 的问题。

    ??? example "细节"

        OpenSSH 开启 DEBUG1 之后可以看到如下输出：

        ```text
        debug1: kex_ext_info_client_parse: server-sig-algs=<>
        ```

        检查 1 月份将 `x/crypto` [更新][x/crypto-v0.18.0]到 v0.18.0 的时候没有注意到 `ServerConfig` 添加了一个字段 `PublicKeyAuthAlgorithms`，且默认的列表仅在 `NewServerConn` 内设置（不像 `Config` 有 `SetDefaults` 方法）；而我们使用了自己写的 `NewPipeSession` 方法，因此这个字段一直为空。

        解决方法是在 `pipe.go` 中加一个函数将默认的 algorithm 列表导出：

        ```go
        func DefaultPublicKeyAuthAlgos() []string {
            return supportedPublicKeyAuthAlgos
        }
        ```

        然后在我们的前端代码中使用即可：

        ```go
        sshConfig := &ssh.ServerConfig{
            PublicKeyAuthAlgorithms: ssh.DefaultPublicKeyAuthAlgos(),
        }
        ```

  [x/crypto-v0.18.0]: https://github.com/USTC-vlab/sshmux/commit/8775b78a26631bdb74d0f69a50d027ae5d9eb237#diff-636282d8dee065d904d0a0074f64f4780fb719ef3354da1e22eab3609e6adc07

5 月 10 日

:   **:material-hammer-wrench: 修复**：更新 code-server 的脚本（`pv1:/root/vlab-software/code-server.sh`）调用 rsync 时忘记加 `--delete` 了，导致更新到 4.89.0 后出错。

4 月 13 日

:   在虚拟机管理页面新增了重命名虚拟机的选项和“管理员消息”功能，并将所有虚拟机的内存容量增加到了 6 GB（新创建虚拟机也采用 6 GB）。

3 月 8 日

:   调整了 SSL 证书的部署方式。

2 月 18 日

:   修复了 KVM 虚拟机默认不带 `zram.ko` 的问题（通过 `cloud.cfg` 加装 `linux-image-extra-virtual`），并更新了虚拟机镜像。

2 月 14 日

:   全面开放了 KVM 虚拟机权限，允许用户自行创建 KVM 虚拟机。

1 月 14 日

:   更新了 Ubuntu 22.04, Ubuntu 20.04 和 CECS 三个镜像，给 systemd-journald 加上了写盘和写 `/run` 的容量限制。

### 2023 年

[11 月 16 日](records/2023-11-18.md)

:   在 pv9 - pv14 上安装了新的 `intel-microcode` 包并安排计划重启，修复了 CVE-2023-23583。

    同时更新了 Django，在虚拟机 ID 后面显示节点名称。

10 月 2 日

:   Vlab Software 上线了 Vivado 2023.1，容量约为 29 GB。

    ```text
    /opt/vlab/applications/vivado2023.desktop
    /opt/vlab/bin/vivado2023
    /opt/vlab/vivado/Xilinx/Vivado/2023.1/
    ```

    测试发现 Vivado 2023.1 在开始综合和开始实现的时候都会闪退，被迫补上了祖传的 LD\_PRELOAD Ubuntu 18.04 的 `libudev.so.1.6.9`；接下来 route\_design 一步还是会异常结束（但程序没有整个闪退），又被迫补上了 `libdbus-glib-1.so.2.3.4`。

[10 月 1 日](records/2023-10-01.md)

:   按照规划了一个多月以来的方案全面切换到了 PVE Firewall，并更新了 vlab-vnc、vlab-vscode 等因此受益的软件。

9 月 15 日

:   测试发现 HPE MSA 1050 的 Virtual Volume 是支持 SCSI Unmap 的，因此在所有计算节点的 `/etc/lvm/lvm.conf` 中添加了 `issue_discard = 1`，然后通过创建一个临时 LV 的方式把所有未分配空间都 unmap 了一下：

    ```shell
    lvcreate -l 100%FREE -n test user-data
    blkdiscard -f user-data/test
    lvremove user-data/test
    ```

    存储服务器后台显示的 Allocated 从 30.3 TB 下降到了 17.1 TB。

9 月 5 日

:   实现了 Linux KVM 虚拟机镜像的可复现配置（见 labstrap 仓库中的 `kvmstrap` 代码，暂未全自动化），并据此构建出了第一份 可用的 KVM 镜像（VM 200）。

9 月 4 日

:   更新了 Django 代码，支持对不同主机上的虚拟机采用不同配置参数，并部署了更新后的代码。这标志着新一批服务器 pv9-14 及对应的存储服务器正式投入服务。

    交换了 pv8 和 pv9 的功能，现在 pv2-8 及 pv10-14 运行用户虚拟机。pv1 和 pv9 保留，分别用于运行 Vlab 核心服务及其他高配置需求的虚拟机。

    修改了 vscode-pdf 插件使其可以在 code-server 中正常运行（见[用户文档](https://vlab.ustc.edu.cn/docs/apps/vscode/#pdf)）。

8 月 23 日

:   配置好了 pv9 - pv14 六台机器和新的存储服务器，将新的计算节点升级到了 PVE 8 并加入了现有的集群。此处并没有踩什么坑。

    修改了 `/etc/pve/corosync.conf`，删除了 link 1（只保留了 link 0）。

8 月 22 日

:   为《计算系统综合实验》课程定制了系统环境：

    - 编译了 RISC-V 的 GCC 工具链（`riscv64-unknown-elf`），通过 `/opt/vlab/riscv64` 提供。
    - 编译了 Verilator 5.014，通过 `/opt/vlab` 提供。
    - 定制 `vlab21-CECS-ubuntu-desktop-mate-22.04` 镜像，通过 `apt install` 添加了一些相关软件。

    另外协助配置了 [soc.ustc.edu.cn](https://soc.ustc.edu.cn) 域名下的相关网页服务。

[8 月 6 日](records/2023-08-06.md)

:   将主机升级到了 PVE 8.0 与 PBS 3.0，同时更新了（7 月已开发完成的）Django KVM 相关功能支持。

7 月 4 日

:   修改了 `/opt/vlab/.dev/kvm` 权限为 `100000:100107 0660`（Proxmox VE 及 Ubuntu 镜像中的 `kvm` 组），`/opt/vlab/.dev/tun` 权限为 `100000:100000 0666`，使得虚拟机内的普通用户也可以访问 KVM 和 TUN。相关文档于 7 月 7 日更新。

4 月 10 日

:   vlab-earlyoom 已不再依赖于系统的 earlyoom 包，转为使用自己预编译的 earlyoom 程序；同时通知方式改为使用 Zenity 图形化通知框（[效果](https://vlab.ustc.edu.cn/docs/images/earlyoom.png)）。

    Django 修复了一个由于 `.save()` 会更新所有列导致的 race condition。

    由于磁盘空间爆满后会导致虚拟机无法开机，新创建的虚拟机已将 ext4 reserved space 从 0 改为 1%（在 vlab-pve-agent 中修改 `tune2fs -m` 的参数）。

[3 月 5 日](records/2023-03-05.md)

:   Django 的登录页面默认折叠用户名密码登录，并展示一个巨大的“统一身份认证登录”按钮，以鼓励用户使用 CAS 登录。

    以及一些与清退判断相关的后台逻辑调整。

[2 月 17 日](records/2023-02-17.md)

:   更新了 Django，限制并行执行的创建容器任务，加快容器创建，并改进了虚拟机管理页面的用户体验。同时在个人信息页面显示从 CAS 获取的用户邮箱。

    更新了 Filestash，添加了一些提示，使操作更直观。

[2 月 1 日](records/2023-01-28.md#github-actions)

:   将容器镜像的构建自动化，不再需要在自己的机器上手动运行构建脚本。

    同时修改了已有的容器，停用或错开了几个固定时间的 systemd timer 定时任务，尝试缓解每天 0 点和 6 点突发的 iowait。

### 2022 年

[9 月 20 日](records/2022-11-21.md)

:   将 post creation 从创建时执行改为首次启动时执行，使得创建容器的界面不再阻塞。

4 月 11 日

:   添加了网页 SSH 登录的功能，以及在 Chrome 与 Edge 浏览器下 noVNC 自动剪贴板的功能，方便用户使用。

2 月 14 日

:   对 LXC 虚拟机提供“恢复模式 SSH”接口，使用户可以在虚拟机断网的情况下通过 SSH 登录获得虚拟机的 shell，自主进行恢复工作。

1 月 28 日

:   修改版 Filestash 测试上线。本次更新主要添加了自动登录功能，并且修正了大量问题。

[1 月 26 日](records/2022-01-26.md)

:   紧急安全更新，同时更新了用户容器的 `sshd_config` 为接下来为所有 username 启用 SSH 证书登录做好准备。

### 2021 年

10 月 27 日

:   `vlab.ustc.edu.cn` 配置的 [HSTS](https://en.wikipedia.org/wiki/HTTP_Strict_Transport_Security) 从 1 小时升级至 1 周（`max-age=604800`）。

10 月 22 日

:   修复了 Grafana 显示的 VNC 在线时长每个月会有一个异常高峰的情况（MySQL 日期时间计算问题）。

    原来使用的 SELECT 项目是 `SUM(disconnect_time - connect_time)`，改为 `SUM(TIME_TO_SEC(TIMEDIFF(disconnect_time, connect_time)))` 后正常了。

10 月 1 日

:   更新了 01 号镜像，升级了所有软件包，清理了多余的软件包，并将 apt 源换回了科大镜像站。

[8 月 21 日](records/2021-08-21.md)

:   将集群全部升级至 Proxmox VE 7.0

8 月 12 日

:   修复了拥有多个学号或工号的用户通过不同学工号登录时数据不互通的问题。

4 月 11 日

:   通过 Vlab Software 提供了 RISC-V 的 GCC 工具链，以及 RARS 模拟器（已编写 `.desktop` 文件使用 Vlab Software 提供的 JDK 14 运行）

3 月 30 日

:   通过 Vlab Software 提供了 Xilinx Vivado 2016.3 版本，为 2019.1 版本的兼容性问题提供一个备选项。

### 2020 年

11 月 18 日

:   将故障损毁的 CT 100 恢复并重建。

11 月 14 日

:   Vivado 仿真的报错已经在镜像中修复，新创建的虚拟机（ID 大于 2266）不再受此影响。

    在线 VSCode 编程平台开放测试。

10 月 29 日

:   用户可以选择关闭 VNC 登录时显示的加入 QQ 群的通知。

!!! note 旧的记录可能不完整

    本页面于 2020 年 9 月初创建，因此 2020 年 8 月及以前的更新记录是不完整的。尽管编者已从讨论群的聊天记录等地尽可能恢复（补写）出了一些，但许多细节仍然难以保证完整性及准确性。

9 月 8 日

:   完成了在容器之间共享实验软件的设计（镜像 01 已经替换为新版本），这可以减少相同的实验软件重复存储的问题，并且将软件放置在 SSD 上，也预期可以提高性能。同时，新创建的容器也支持嵌套容器了。

9 月 5 日

:   虚拟机管理界面的**桌面连接**功能现在可以自动连接对应虚拟机（使用 URL parameters 传递信息）

9 月 3 日

:   SSH 统一登录可以使用了。预计将在一段时间之后关闭旧的登录方式（端口转发），具体时间待定

8 月 4 日

:   基于 Grafana + InfluxDB / MySQL 的用量数据统计页面

[8 月 1 日](records/2020-08-01.md)

:   光纤网络（ens1f0、ens1f1）的 MTU 现在是 1550 字节了

    修复了 pv8 的光纤网络

    noVNC 支持基于浏览器 cookie 的一键登录，减少重复输入用户名密码的麻烦

    配置并打包好了 Ubuntu 20.04 的镜像，暂时以编号 99 提供

[3 月 31 日](records/2020-03-31.md)

:   向 pv0 加装了 32 GB 内存，向 pv2~pv8 加装了 64 GB 内存，向 pv2~pv5 加装了 Netronome Agilio 系列网卡

3 月 25 日

:   2019 年秋季学期提供服务的单台服务器已格式化重装为 Proxmox VE 6.1 操作系统，命名为 pv0

2 月

:   [内网网关（CT 100）](servers/ct100.md)初步配置完成

    [Web 服务器（CT 101）](servers/ct101.md)切换到新的集群中的容器上，2019 年秋季的旧机器暂时闲置

    pdlan 使用 C++ 编写的 VNC 网关测试完成

    网页虚拟机管理器（Django）适配了 Proxmox VE API，删除了 LXC / LXD 相关的代码

    修改了开源软件 noVNC，提供了浏览器登录虚拟机的方式

    重新打包了几个新镜像，供用户在创建虚拟机时选择

    - 经过多番测试，选定了 LightDM + TigerVNC，兼容性最好且最容易配置

    - 测试了 fcitx 与 ibus，配置好了中文输入法

    通过镜像内置 SSH CA 的方式实现容器内远程命令执行

    更新了用户文档项目，更容易编写、阅读体验更好，并且更新了文档内容

    创建了维护者文档（即本文档）

    ……还有更多（当前一代的 vlab 基本都在这个月配置部署完成，时间“久远”难以仔细考证）

### 2019 年

9 月

:   初版 vlab 实验平台在《数字电路实验》课程选定的 30 人左右中进行测试
