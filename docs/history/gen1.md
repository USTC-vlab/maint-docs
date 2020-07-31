# Vlab 第一代服务器

第一代 Vlab 远程虚拟桌面平台在 2019 年 6 月由李子天学长初步配置好，经过 @iBug 和 @taoky 等人进一步调整并编写前端管理系统后，于 2019 年秋季学期开始小范围测试（正式上线）。

## 硬件 {#hardware}

第一代 Vlab 服务器包含双路 Intel Xeon E5-2630 v4 处理器（共 20 核心、40 线程），安装内存 128 GB（8 x 16 GB DDR4 2400 ECC）。硬盘配置为一块 Intel Optane 905P 480GB（系统盘，swap 和缓存）和四块 HPE 2.4TB SAS 硬盘。

另外该服务器上还有一块 NVIDIA Tesla P4 GPU，原本计划用于加速深度学习等负载，实际上由于承担的课程实验任务类型不同，并未派上用场。

## 操作系统 {#operating-system}

搭建这台服务器的学长选择了 Ubuntu 18.04 LTS，但是将内核替换为 `3.10.0-514.61.1.el7.x86_64`（来自 RHEL 7.3 EUS），原因是 NVIDIA 的驱动（内核模块）需要编译，而且对内核版本非常敏感，为了保证这个难整的驱动能正常使用，不方便将内核交由 apt 管理升级。

## 虚拟化 {#containerization}

采用 [LXD](https://linuxcontainers.org/) 容器，运行一个定制的镜像（Ubuntu Minimal 安装了 Xfce 和 Xilinx Vivado），为 2019 年秋季学期的《数字电路实验》课程提供服务。

## 存储 {#storage}

最开始（2019 年暑假期间）没有任何特别的存储架构，直接用的 LXD 的 Directory（也就是纯目录）存储，后来在正式上线前由 iBug 替换成了 ZFS，并一直运行下去。

## 后续 {#follow-ups}

这台机器在 2020 年 3 月底被重装为 Proxmox VE 系统，内存由 128 GB 升级到 160 GB，重新指派 hostname 为 pv0，计划是提供 GPU 容器服务，，不过后来发现第二代的机器无法加装 GPU 之后就改为用作我们的开发测试环境了，不提供任何正式服务（也没有接入光纤内网）。
