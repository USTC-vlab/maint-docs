# 打包 Windows 镜像

!!! danger "警告"

    打包和维护 Windows 镜像非常麻烦并且很难 debug，<big><b>快跑！！！</b></big>

    <big><b>You have been warned. Run!!!</b></big>

由于 Proxmox VE 上的虚拟机使用 cloud-init 进行定制，并且 Windows 和 Unix 一套体系完全不在一个频道上，所以制作可以用 cloud-init 即使只是简单定制的 Windows 镜像也非常折腾。~~下面让我们一起来受罪吧！~~

## 一、准备虚拟机

### 安装虚拟机

学校买了正版的 Windows 10，可以在[软件正版化](https://zbh.ustc.edu.cn/)网站上下载，建议选中文版（因为是面向用户的）。旁边的 KMS 注册文件不用下载，实际只需要一行命令就能解决，后面会提到。

同时也要下载 [VirtIO Windows 驱动][virtio-win]，选 Stable ISO。

  [virtio-win]: https://github.com/virtio-win/virtio-win-pkg-scripts#downloads

- 创建一个虚拟机，选择一个 ID 和名称
- OS 页面注意在右边的 Guest OS 正确选择 Windows 10
- System 页面勾上 Qemu Agent，将 SCSI Controller 改为 Default
- **硬盘总线选 SATA**，存储和容量自定，推荐 32 GB 就够，除非你还要额外安装软件（建议别自找麻烦）
- CPU 内存按需分配，4 核 8 GB 算高配了
- 网卡接在 vmbr1 上（也就是用户内网），不然后面还有麻烦 :octicons-alert-24:
- 最后的确认页面先**不要**勾选 Start after created，创建完成后去添加一个串口设备（Serial 0），后面会用到

和一般的虚拟机安装过程一样，将 ISO 添加为 CD/DVD Drive，跟着安装程序走完流程即可，版本请选择教育版。

第一次重启后进入 Windows 的 OOBE，现在可以在后台把光驱换成 VirtIO 的驱动盘了。

### Windows OOBE

OOBE 阶段可以自行配置，不过既然是要用作面向用户的模板，选择一些设置时稍微考虑一下。

地区语言当然是中文了，键盘微软拼音（这是默认，下一步），然后一路到创建账户这里会有个错误提示码 OOBEAADV10，忽略掉它创建一个本地账户，命名为 Vlab，密码留空（不然后面要你填三个安全问题，WTF?）。

??? note "错误码 OOBEAADV10"

    这是 Windows 在尝试连接到 Azure Active Directory 时报的错，因为这个时候只有 IPv6 网络是通的（有 SLAAC），用户内网没有 DHCP。

位置服务、广告标识符这个页面全部关掉，Cortana 也别开，都是些浪费时间和资源的东西。

到这里就差不多进入桌面了，目前为止没有太多坑，除了密码必须留空之外（嗯，这种地方要求填安全问题是个奇怪的设定）。

## 二、配置虚拟机

### 暂停 Windows 更新

!!! danger "不然网络通畅后开始自动更新了，后面你就麻烦了"

### 设置网络

右键点击右下角的网络图标，打开“网络和 Internet”设置，在下面选择“更改适配器选项”，打开“以太网实例 0”的属性，再选中 Internet 协议版本 4，在这里指定一个临时的 IPv4 地址（参考[打包容器的流程](pack-ct-image.md#prepare-ct)），掩码是 `255.255.0.0`，网关是 `172.31.0.1`，DNS 服务器和网关一样，确定完成后就能上网了。

!!! danger "不要直接在“设置”应用里改"

    “设置”里直接改的时候，指定静态 IPv4 的时候就没有 IPv6 自动配置了。

### 激活 Windows

右键点击左下角的 :fontawesome-brands-windows: Windows，打开一个有管理员权限的 PowerShell 窗口，配置学校的 KMS 激活：

```bat
slmgr.vbs /skms kms.ustc.edu.cn
```

现在可以进设置应用里查看激活状态了。如果还没激活的话，点疑难解答，等它跑完就会告诉你已激活。

### 安装 VirtIO 驱动

打开光驱运行 `virtio-win-guest-tools.exe`，一路下一步安装即可。

这里唯一的坑点是，如果你在创建虚拟机时没有多一步添加一个串口设备的话，那么 VirtIO 串口驱动就不会安装，需要关机加好设备后再重新安装。

QEMU Guest Agent (Qemu GA) 以后会很有用，我们也把它装上吧。

### 其他自定义设置

任务栏里那块巨大的胶布（搜索框）可以隐藏起来，Cortana 图标隐藏起来，Task View 的图标也可以隐藏起来，这几个都是右键任务栏就可以勾选的选项。

“任务栏设置”里的“使用‘速览’预览桌面”出于性能考虑建议不要开，其他随意，例如“合并任务栏按钮”可以改成“任务栏已满时”等等，其他的桌面背景、颜色、开始菜单等都随意。

Windows 检测网络连接的功能经常坏，原因其实很简单，msftconnecttest.com 服务器在国外，很慢而且不稳定，可以修改注册表将这个功能替换成使用校内的服务。

??? abstract "注册表文件"

    ```registry
    Windows Registry Editor Version 5.00

    [HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\NlaSvc\Parameters\Internet]
    "ActiveDnsProbeContent"="202.38.64.1"
    "ActiveDnsProbeContentV6"="2001:da8:d800::1"
    "ActiveDnsProbeHost"="ns.ustc.edu.cn"
    "ActiveDnsProbeHostV6"="ns.ustc.edu.cn"
    "ActiveWebProbeContent"="USTC Mirrors Connect Test"
    "ActiveWebProbeContentV6"="USTC Mirrors Connect Test"
    "ActiveWebProbeHost"="mirrors.ustc.edu.cn"
    "ActiveWebProbeHostV6"="ipv6.mirrors.ustc.edu.cn"
    "ActiveWebProbePath"="connecttest.txt"
    "ActiveWebProbePathV6"="connecttest.txt"
    "EnableActiveProbing"=dword:00000001
    ```

## 三、安装 Cloudbase-init
