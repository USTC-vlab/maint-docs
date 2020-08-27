# 虚拟机cloud-init配置和使用
## 配置带有cloud-init的镜像
### 创建虚拟机,并安装cloud-init
   从本地选择iso创建虚拟机,配置后进入虚拟机,安装cloud-init(如果没有在配置时换源,先换源)
   > sudo apt-get/yum install cloud-init
   
   cloud-init的配置信息在文件 /etc/cloud/cloud.cfg.d/*.cfg和/etc/cloud/cloud.cfg中,cloud-init以字母顺序读取所有的\*.cfg文件,相同参数后面的文件会覆盖前面的文件.
   在cloud.cfg文件中,任务以module形式组织. 例如当指定了set_hostname的moudle,则表示cloud-init会执行hostname任务,但具体的配置参数由metadata指定.
   所以我们需要在此文件中删除不需要的模块, 例如disable-ec2-metadata,byobu, etc. . 

   ```shell
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

   cloud-init的`数据文件`放在/var/lib/cloud/data中.
   `日志文件`放在/var/log/cloud-init-output.log(每阶段输出),
   /var/log/cloud-init.log(每一个操作更详细的调试日志),
   /run/cloud-init:决定开启和关闭自身的某些功能
### 解决从同一模板中创建的虚拟机有相同的machine-id问题
   promox会对创建的新虚拟机自动分配不同的MAC地址.
   但是对于ubuntu,从统一模板中创建的虚拟机有和模板相同的machine-id,虚拟机使用此machine-id来获取DHCP的lease,从导致多个虚拟机竞争同一个IP地址.
   解决此问题的方法是文件/etc/machine-id删除,重新创建一个同名空白文件
   > sudo rm /etc/machine-id
   > sudo touch /etc/machine-id
   之后,转到文件/var/lib/dbus/machine-id,此文件会在每次虚拟机重启之后将machine-id复制到/etc/machine-id中.
   所以将此文件删除,创建一个/etc/machine-id的符号链接到此处.
   > sudo rm /var/lib/dbus/machine-id
   > sudo ln -s /etc/machine-id /var/lib/dbus/machine-id
   然后将此虚拟机关机(不是重启,否则会生成新的machine-id),制作为模板.

   方法2:
   修改DHCP的identifier,/etc/netplan/下文件,在network下的ethernets下的条目增加dhcp-identifier:mac,即可使用MAC作为DHCP分配IP的唯一标志.
   但SSH也使用machine-id,所以此方法只解决了ip的问题

### 安装必要软件包
   安装net-tools,openssh-server等工具

### 设置user name和password(失败,无法使用在promox web页面上设置的username和passwd登录虚拟机)
   完成上面的工作后将虚拟机关机,在promox web界面hardware栏中add cloudinit Drive,然后在Cloud-init栏中设置用户名和密码(必须设置,否则无法进入由此模板创建的虚拟机).

## cloud-init简介和配置解释
### 阶段
   cloud-init.cfg文件中有五个stage,cloud-init分为五个阶段进行,具体以服务的形式注册到系统中按如下次序执行:
   1. generator
      此阶段检测ci是否被禁用

   2. local:cloud-init-local.service 
      当/挂载时执行,此阶段的任务主要是定位本地数据,将网络配置应用到本地
      需要将网络block
      此阶段没有用到的模块
   
   3. network:cloud-init.service
      处理所有的user-data,包括任何`#include`or`#include-once`,解压缩所有压缩文件,运行所有的`part-handler`
   
   4. config:cloud.config.service
      此阶段仅运行config moudle,其他阶段不起作用的模块都在这个阶段运行

   5. final:cloud-final.service
      此阶段运行用户自定义的需要在登录系统后执行的脚本在此处运行.

   每个阶段中执行的任务以模块的形式定义,模块执行的具体任务由metadata决定

### User-Data
cloud-init通过命令行--cicustom将用户自定义的config文件进行配置
> qm set \<vid\> --cicustom "user=\<volume\>,network=\<volume\>,meta=\<volume\>"
> e.g. qm set 9000 --cicustom "user=local:snippets/userconfig.yaml"
cicustom 文件需要在支持snippets并且所有的VM都能access的节点上.
创建一个snippets: 在proxmox的web界面上的datacenter中点击存储-add-directory,设置id,选择目录content选择snippets,node选ALL(No restrictions).
关于volumes:
   local默认位置为/var/lib/vz(定义在配置文件/etc/pve/storage.cfg)
   cloudinit 日志文件在/var/log/cloud-init-ouput.log中

#### UserData格式
* User-Data Script
   
   通常用于仅仅需要执行一个shell脚本的时候
   格式: 以`#!`开始或者当使用MIME归档时以`Content-Type:text/x-shellscript`开始
   example:
   ```shell
   #!/bin/sh
   echo "Hello World.  The time is now $(date -R)!" | tee /root/output.txt
   ```

   在`虚拟机`的`/var/lib/cloud/scripts`目录下存放要执行的脚本文件.

* Cloud Config Data
   必须是合法的yaml格式
   local目录在/var/lib/vz下(在/etc/pve/storage.cfg中配置)
   格式: 以`#cloud-config`开始或者当使用MIME时以`Content-Type:text/cloud-config`开始
   各moudle对应下config data格式及功能说明:https://cloudinit.readthedocs.io/en/latest/topics/modules.html
   例如:
   ```script
   bootcmd:
     -echo 192.168.1.130 us.archive.com > /etc/hosts
     - [ cloud-init-per, one, mymkfs,mkfs,/dev/vdb]
   ```
   
#### config 示例:

配置实例的ssh key:https://cloudinit.readthedocs.io/en/latest/topics/modules.html#ssh

扩容:https://cloudinit.readthedocs.io/en/latest/topics/modules.html#growpart

* Kernel Command Line
   使用NoCloud时,用户可以将用户数据通过内核命令行参数传递

* 其他
   其他格式还有include,upstart job,cloud boothook,part handler等
   ci有一个脚本make-mime.py可以将不同类型的用户数据综合在一起,例如将cloud-config类型的config.yaml和x-shellscript类型的script.sh组合在一起形成user-data数据:
   > ./tools/make-mime.py -a config.yaml:cloud-config -a script.sh:x-shellscript > user-data

### 部署
#### 部署文件形式
   * 通过.cfg文件:
   
      在虚拟机/etc/cloud/cloud.cfg.d/下有多个`.cfg`结尾的文件,这些ci配置文件将按照字母顺序执行,后面的cfg文件会覆盖前面的cfg文件中相同的配置.
      通过测试,新建一个cfg文件,使用模块bootcmd,在此模块下编写的脚本程序将会被执行,例如新建文件/etc/cloud/cloud.cfg.d/test.cfg,写入内容
      ```script
      bootcmd:
         - [sh, -xc, "echo 'hello world' >> testfile"]
      ```
      就将会在当前.cfg文件目录下建立一个内容为"hello world"的名为testfile的文件

      虚拟机每次启动都会执行bootcmd其后的命令,通过将配置过程写成脚本的形式再作为bootcmd的参数写入.cfg配置文件中,虚拟机便能够完成配置任务.
      此外,bootcmd是每次虚拟机启动都会执行,如果需要虚拟机只执行一次命令,可以使用runcmd选项.
   
   * 通过userdata script文件:

      此外,也可以直接将配置过程以脚本的形式呈现,将其存储在/var/lib/cloud/scripts/下,虚拟机每次启动都会执行此脚本中的命令.
#### 部署方式
   1. 虚拟机本地
      将.cfg和script文件存储在相应目录下,由虚拟机在启动的时候读取并执行配置过程

   2. qm 命令从数据中心的命令行(未实现)
      从数据中心的终端上执行命令进行部署
      > 格式: qm set \<vimd\> --cicustom "user=\<volume\>"

      > 示例: qm set 101 --cicustom "user=local:snippets/userconfig.yaml" 


#### 其他问题
修复报错:

1. 
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
   将~/.bashrc文件末尾添加`export LC_ALL=c`后执行source ~/.bashrc
