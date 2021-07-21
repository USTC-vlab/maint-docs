# 虚拟机 cloud-init 配置和使用

## 配置带有 cloud-init 的镜像

### 创建虚拟机，并安装 cloud-init

从本地选择 iso 创建虚拟机，装好系统后进入虚拟机，安装 cloud-init。如果在装系统时没有换源，就先换源。

```shell
sudo apt install cloud-init  # Ubuntu
sudo yum install cloud-init  # CentOS
```

cloud-init 的配置信息在文件 `/etc/cloud/cloud.cfg.d/*.cfg` 和 `/etc/cloud/cloud.cfg` 中。cloud-init 以字母顺序读取所有的 `*.cfg` 文件，相同参数后面的文件会覆盖前面的文件。

在 cloud.cfg 文件中，任务以 module 形式组织. 例如指定 `set_hostname` 的 moudle 时，cloud-init 会执行 hostname 任务，具体的配置参数由 metadata 指定。

我们需要在此文件中删除不需要的模块, 例如 `disable-ec2-metadata` 和 `byobu` 等。 

```yaml
cloud_config_modules:
- snap
- snap_config
- ubuntu-advantage
- disable-ec2-metadata
- byobu

cloud_final_modules:
- snappy
- fan
- landscape
- lxd
- puppet
- chef
- mcollective
- salt-minion
- rightscale_userdata
```

cloud-init 的数据文件放在 `/var/lib/cloud/data` 中，
日志文件放在 `/var/log/cloud-init-output.log` (每阶段输出)，
`/var/log/cloud-init.log` (每一个操作更详细的调试日志)，
`/run/cloud-init` 决定开启和关闭自身的某些功能。

### 解决从同一模板中创建的虚拟机有相同的 machine-id 问题

#### 方法 1

Proxmox 会对创建的新虚拟机自动分配不同的 MAC 地址。

但是对于 Ubuntu，从统一模板中创建的虚拟机有和模板相同的 machine-id，虚拟机使用此 machine-id 来获取 DHCP 的 lease，从导致多个虚拟机竞争同一个 IP 地址。

解决此问题的方法是文件 `/etc/machine-id` 删除，重新创建一个同名空白文件

```shell
sudo rm /etc/machine-id
sudo touch /etc/machine-id
```

之后，转到文件 `/var/lib/dbus/machine-id`，此文件会在每次虚拟机重启之后将 machine-id 复制到 `/etc/machine-id` 中。
所以将此文件删除，创建一个 `/etc/machine-id` 的符号链接到此处。

```shell
sudo rm /var/lib/dbus/machine-id
sudo ln -s /etc/machine-id /var/lib/dbus/machine-id
```

然后将此虚拟机关机（不是重启，否则会生成新的 machine-id），制作为模板。

#### 方法 2

修改 DHCP 的 identifier，`/etc/netplan/` 下文件，在 network 下的 ethernets 下的条目增加 `dhcp-identifier: mac`，即可使用 MAC 作为 DHCP 分配 IP 的唯一标志。
但 SSH 也使用 machine-id，所以此方法只解决了 ip 的问题。

### 安装必要软件包

安装 net-tools, openssh-server 等工具

### 设置 username 和 password (失败，无法使用在 proxmox web 页面上设置的 username 和 password 登录虚拟机)

完成上面的工作后将虚拟机关机，在 proxmox web 界面 hardware 栏中 add cloudinit Drive，然后在 Cloud-init 栏中设置用户名和密码（必须设置，否则无法进入由此模板创建的虚拟机）。

## cloud-init 简介和配置解释

### 阶段

cloud-init.cfg 文件中有五个 stage，cloud-init 分为五个阶段进行，具体以服务的形式注册到系统中按如下次序执行：

1. generator

    此阶段检测 ci 是否被禁用

2. local:cloud-init-local.service 

    当/挂载时执行，此阶段的任务主要是定位本地数据，将网络配置应用到本地。

    需要将网络 block

    此阶段没有用到的模块

3. network:cloud-init.service

    处理所有的 user-data, 包括任何 `#include` or `#include-once`, 解压缩所有压缩文件, 运行所有的 `part-handler`

4. config:cloud.config.service

    此阶段仅运行 config module, 其他阶段不起作用的模块都在这个阶段运行

5. final:cloud-final.service

    此阶段运行用户自定义的需要在登录系统后执行的脚本在此处运行。

每个阶段中执行的任务以模块的形式定义, 模块执行的具体任务由 metadata 决定

### User-Data

cloud-init 通过命令行 `--cicustom` 将用户自定义的 config 文件进行配置 

```shell
# Syntax
qm set <vid> --cicustom "user=<volume>, network=<volume>, meta=<volume>" 

# Example
qm set 9000 --cicustom "user=local:snippets/userconfig.yaml" 
```

cicustom 文件需要在支持 snippets 并且所有的 VM 都能 access 的节点上。

创建一个 snippets: 在 proxmox 的 web 界面上的 datacenter 中点击存储 - add-directory, 设置 id, 选择目录 content 选择 snippets, node 选 ALL (No restrictions)。

#### 关于 volumes

local 默认位置为 `/var/lib/vz`（定义在配置文件 `/etc/pve/storage.cfg` 中）

cloudinit 日志文件在 `/var/log/cloud-init-ouput.log` 中 

#### User-Data 格式

##### User-Data Script

通常用于仅需要执行一个 shell 脚本的时候 

格式：以 `#!` 开始或者当使用 MIME 归档时以 `Content-Type: text/x-shellscript` 开始

!!! example "示例"

    ```shell
    #!/bin/sh
    echo "Hello World. The time is now $(date -R)!" | tee /root/output.txt
    ```

在虚拟机的 `/var/lib/cloud/scripts` 目录下存放要执行的脚本文件。

##### Cloud Config Data

必须是合法的 yaml 格式

local 目录在 `/var/lib/vz` 下（在 `/etc/pve/storage.cfg` 中配置）

格式: 以 `#cloud-config` 开始或者当使用 MIME 时以 `Content-Type: text/cloud-config` 开始

各 module 对应下 config data 格式及功能说明：<https://cloudinit.readthedocs.io/en/latest/topics/modules.html>

!!! example "示例"

    ```yaml
    bootcmd:
       - echo 192.168.1.130 us.archive.com > /etc/hosts
       - [ cloud-init-per, one, mymkfs, mkfs, /dev/vdb ]
    ```

#### config 示例:

配置实例的 SSH key：<https://cloudinit.readthedocs.io/en/latest/topics/modules.html#ssh>

扩容：<https://cloudinit.readthedocs.io/en/latest/topics/modules.html#growpart>

##### Kernel Command Line

使用 NoCloud 时，用户可以将用户数据通过内核命令行参数传递。

##### 其他

其他格式还有 include, upstart job, cloud boothook, part handler 等

ci 有一个脚本 `make-mime.py` 可以将不同类型的用户数据综合在一起，例如将 cloud-config 类型的 config.yaml 和 x-shellscript 类型的 script.sh 组合在一起形成 user-data 数据:

```shell
./tools/make-mime.py -a config.yaml:cloud-config -a script.sh:x-shellscript > user-data
```

### 部署

#### 部署文件形式

* 通过 .cfg 文件:

   在虚拟机 `/etc/cloud/cloud.cfg.d/` 下有多个 `.cfg` 结尾的文件，这些 ci 配置文件将按照字母顺序执行，后面的 cfg 文件会覆盖前面的 cfg 文件中相同的配置。

   通过测试，新建一个 cfg 文件，使用模块 bootcmd，在此模块下编写的脚本程序将会被执行，例如新建文件 `/etc/cloud/cloud.cfg.d/test.cfg`，写入内容

   ```yaml
   bootcmd:
      - [ sh, -xc, "echo 'hello world' >> testfile" ]
   ```
   就将会在当前 .cfg 文件目录下建立一个内容为 "hello world" 的名为 testfile 的文件。

   虚拟机每次启动都会执行 bootcmd 其后的命令，通过将配置过程写成脚本的形式再作为 bootcmd 的参数写入 .cfg 配置文件中，虚拟机便能够完成配置任务。

   此外，bootcmd 是每次虚拟机启动都会执行，如果需要虚拟机只执行一次命令，可以使用 runcmd 选项。

* 通过 userdata script 文件:

   此外，也可以直接将配置过程以脚本的形式呈现，将其存储在 `/var/lib/cloud/scripts/` 下，虚拟机每次启动都会执行此脚本中的命令。

#### 部署方式

1. 虚拟机本地

    将 `.cfg` 和 `script` 文件存储在相应目录下，由虚拟机在启动的时候读取并执行配置过程

2. qm 命令从数据中心的命令行（未实现）

    从数据中心的终端上执行命令进行部署

    ```shell
    # 格式
    qm set <vmid> --cicustom "user=<volume>"

    # 示例
    qm set 101 --cicustom "user=local:snippets/userconfig.yaml"
    ```

#### 其他问题

修复报错:

1. 错误表现如下

    ```shell
    perl: warning: Setting locale failed.
    perl: warning: Please check that your locale settings:
       LANGUAGE = (unset),
       LC_ALL = (unset),
       LC_ADDRESS = "zh_CN.UTF-8",
       .....
       are supported and installed on your system.
    perl: warning: Falling back to a fallback locale ("en_US.UTF-8").
    ```

    解决方法：设置环境变量 `LC_ALL=C` 或 `LC_ALL=C.UTF-8`
