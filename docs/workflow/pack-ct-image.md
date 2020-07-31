# 打包容器镜像

Proxmox VE 的容器镜像和 LXC 略有不同，所以从 LXC 下载的镜像不宜直接用于 Proxmox VE。基准镜像可以直接使用已有的 vlab 镜像（推荐），或者使用 `pveam` 命令从 Proxmox 官方下载。

## 负一、打包前的工作

其实就是清理工作，避免把不必要的内容打包进镜像。下面是一些需要清理的东西：

- **`/etc/ssh`**：将生成的 Host Key 全部删掉（如果有），这样创建新容器的时候可以生成新的主机密钥对
- **`/run/`, `/tmp`, `/var/{backups,cache,crash,log,tmp}`**：全部清空，注意 `/tmp`, `/var/crash` 和 `/var/tmp` 这三个目录的权限是 1777 (rwxrwxrwt)，其他目录权限都是 0755 (rwxr-xr-x)。
- **`/root` 和 `/home/<user>`**：把 `.bash_history` 之类的文件都删掉，只留下最基本的内容（如果配置了桌面环境，谨慎清理 `.config`）。

## 一、基础工作

本节工作只需要对从 Proxmox 直接下载的“最原始”的镜像处理。

- **换源**：将 apt / yum 源换为 `mirrors.ustc.edu.cn` 或者 `mirrors.tuna.tsinghua.edu.cn`
- **加入 SSH CA 公钥**：这里请加入 Vlab User CA（[SSH 证书认证](../ssh-ca.md)这一页下面那个）

下面这些工作可以凭自己喜好选做：

- **更新 `/etc/skel`**：例如，在 `.bashrc` 里默认启用有颜色的 PS1（限 Ubuntu / Debian）
- **更新 `/etc/motd`**：也就 SSH 登录的时候显示一下，改不改没啥区别
