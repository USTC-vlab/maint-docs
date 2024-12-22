# 各软件的安装方式

## Code Server

仓库：[:simple-github: coder/code-server](https://github.com/coder/code-server)

更新脚本：

```shell title="pv1:/root/vlab-software/code-server.sh"
--8<-- "vlab-software/code-server.sh"
```

## Mathematica

（以下命令酌情修改）

本地：

```shell
docker run --rm -it -v $HOME/tmp/mathematica/:/opt/vlab/mathematica-14/ -v $(pwd)/Wolfram_14.1.0_LIN_Bndl.sh:/setup.sh ustclug/ubuntu:22.04
```

容器中安装：

- xz-utils

Mathematica 主体安装路径：`/opt/vlab/mathematica-14/`

Wolfram Script 随便找个路径，只是一堆软链接，之后放到 `/opt/vlab/bin` 即可，像这样：

```shell
for i in /opt/vlab/mathematica-14/Executables/*; do ln -sf $i $(basename $i); done
```

默认 mathematica 的文档是英文的。另外有个中文文档的安装包。考虑到我们最开始放了中文文档包，建议文档换成这个。脚本不会让你选安装路径，所以需要手动 `mv /usr/share/Wolfram/Documentation/14.1/zh-hans-cn/Documentation/ChineseSimplified /opt/vlab/mathematica-14/Documentation/`

然后 rsync 到 pv9 测试（pv9 不会自动更新 Vlab Software）。可以把自己的容器移到 pv9 用来测试效果。
