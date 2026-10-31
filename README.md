# EasyTier for Omarchy

在 Omarchy 状态栏查看 EasyTier 本机和节点状态、复制虚拟 IP，并可通过 systemd 开关组网。不需要运行 EasyTier GUI 或额外的托盘进程。插件只负责显示和控制**已有的 EasyTier**，不会自动安装、配置或加入组网。

> **注意：**开关控制的是 EasyTier 组网服务，不是 Clash 代理。关闭服务会断开该服务承载的 EasyTier 连接；动态分配的虚拟 IP 在重启后也可能改变。

## 1. 准备 EasyTier

### 已经在使用 EasyTier？

如果本机已经有可用的 EasyTier，请**保留现有配置和身份，不要重新安装或创建第二个服务**。先在终端检查：

```sh
command -v easytier-cli
easytier-cli node
easytier-cli peer
```

如果这些命令可以正常显示本机和节点信息，直接跳到[安装插件](#2-安装插件)。如果找不到 `easytier-cli`，先检查安装目录以及 Omarchy shell 的 `PATH`；它需要能直接运行这个命令。命令可用但无法连接时，先排查 EasyTier 后台和 RPC 设置。

插件使用 `easytier-cli` 的**默认 RPC 连接**（通常是 `127.0.0.1:15888`），目前不支持在插件里配置其他地址或选择实例。`node` 能连上后台也不代表其他节点一定可达。

### 全新安装：命令行版本

下面是一个使用独立 systemd 系统服务的例子，适用于没有现成 EasyTier 组网的 Omarchy 机器。它不会安装 EasyTier GUI。已有其他安装方式或网络配置时，请使用自己原有的方式，而不是照此覆盖。

1. 在 [EasyTier 官方下载页](https://easytier.cn/guide/download.html) 下载与你的 Linux CPU 架构匹配的**命令行程序** ZIP，解压后在包含 `easytier-core` 和 `easytier-cli` 的目录打开终端：

   ```sh
   sudo install -m 755 easytier-core easytier-cli /usr/local/bin/
   easytier-core --version
   easytier-cli --version
   ```

   如果找不到文件，先进入解压后的实际目录。其他安装方式见 [EasyTier 官方安装文档](https://easytier.cn/guide/installation.html)。

2. 准备配置文件。先创建仅 root 可读的文件，再使用编辑器填写：

   ```sh
   sudo install -d -m 700 /etc/easytier
   sudo touch /etc/easytier/omarchy.toml
   sudo chmod 600 /etc/easytier/omarchy.toml
   sudoedit /etc/easytier/omarchy.toml
   ```

   示例内容如下，**替换网络名称和密钥**。同一组网的设备使用相同的网络名称和密钥；请使用独立、随机的强密钥，不要使用示例占位符或公开默认值。

   ```toml
   instance_name = "default"
   dhcp = true
   rpc_portal = "127.0.0.1:15888"

   [[peer]]
   uri = "tcp://public.easytier.top:11010"

   [network_identity]
   network_name = "替换为你的网络名称"
   network_secret = "替换为你的强随机网络密钥"
   ```

   这里的公共节点用于节点发现和必要时的连接转发；也可以按自己的网络方案替换成可信的自建节点。它是外部服务，请自行评估信任和隐私需求。示例开启 DHCP；固定地址、复杂组网和安全选项请参考 [官方快速组网](https://easytier.cn/guide/network/quick-networking.html)和[配置文件文档](https://easytier.cn/guide/network/config-file.html)。RPC 限制在本机，**不要将管理端口暴露到公网**。不要把包含密钥的配置文件、终端输出或截图提交到仓库或发给他人。

3. 创建系统服务。先确认没有重名文件：

   ```sh
   test ! -e /etc/systemd/system/easytier-omarchy.service && echo '可以创建服务文件'
   ```

   如果没有输出，说明文件已存在；请先检查，不要覆盖。否则运行：

   ```sh
   sudoedit /etc/systemd/system/easytier-omarchy.service
   ```

   填入并保存：

   ```ini
   [Unit]
   Description=EasyTier network
   Wants=network-online.target
   After=network-online.target

   [Service]
   Type=simple
   ExecStart=/usr/local/bin/easytier-core -c /etc/easytier/omarchy.toml
   Restart=on-failure
   RestartSec=3

   [Install]
   WantedBy=multi-user.target
   ```

   如果实际二进制路径或配置路径不同，须相应调整 `ExecStart`。启动并设置开机运行：

   ```sh
   sudo systemctl daemon-reload
   sudo systemctl enable --now easytier-omarchy.service
   systemctl status easytier-omarchy.service
   easytier-cli node
   easytier-cli peer
   ```

   至少另一台设备也加入同一组网后，再使用虚拟 IP 测试设备间连接。`active` 只表示服务在运行，不保证跨设备连接成功。修改 EasyTier 配置后需要重启服务，**重启会暂时断开组网**：

   ```sh
   sudo systemctl restart easytier-omarchy.service
   ```

## 2. 安装插件

需要支持 bar-widget 插件的 Omarchy shell、Python 3 和 Git。复制功能需要 `wl-copy`（Arch 包名 `wl-clipboard`）；可选的服务开关需要 systemd、`pkexec` 和正在运行的 polkit 图形认证代理。

```sh
omarchy pkg add python wl-clipboard polkit
omarchy plugin add https://github.com/lszhe/omarchy-easytier --enable
```

按提示确认安装并选择状态栏位置。插件以未沙箱化的代码运行，应先检查并信任其来源。已经安装过时不必再次 `add`；在插件是 Git 安装且远端可访问时，可用 `omarchy plugin update local.easytier` 更新。

如果图标没出现在希望的位置，可以移动到右侧：

```sh
omarchy bar move local.easytier --section right
```

## 3. 设置服务名

插件默认控制 `easytier-omarchy.service`，与上面的全新安装示例一致。如果你已经使用其他**系统级** EasyTier 服务，需要先找到其实际名称：

```sh
systemctl list-units --all 'easytier*'
systemctl list-unit-files 'easytier*'
```

例如，官方安装脚本通常创建 `easytier@default.service`；确认本机实际使用的是该服务后，在终端设置：

```sh
omarchy bar set local.easytier serviceName 'easytier@default.service'
```

也可以在 Omarchy 的插件设置里修改 **Systemd service name**。只填写服务名，不填写命令或路径。没有对应系统服务、服务状态无法判断或名称无效时，开关不可用，但 CLI 状态仍可单独显示。GUI 自己管理的进程、容器和 user systemd 服务不受这个开关控制。确保配置的服务确实是要控制的 EasyTier 服务；插件不会判断它承载了哪些网络。

## 4. 使用与检查

- 左键状态栏图标打开面板；中键刷新。
- 面板显示本机、节点和连接信息；点击复制按钮复制 IP（去掉 CIDR 前缀）。
- 点击开关，或按 `T`，先显示确认提示；`Y` 确认、`N` 取消。确认后由 `pkexec` 在需要时请求管理员授权；取消或授权失败不会被当成成功。服务状态会再次刷新。
- `C` 复制本机 IP，`R` 刷新，`Esc` 关闭。刷新间隔默认 30 秒，可在插件设置中调整。
- 状态显示 CLI 连接成功只表示能访问后台；请通过实际访问另一台设备的虚拟 IP 验证组网。

## 常见问题

- **找不到 CLI**：用 `command -v easytier-cli` 检查是否在 shell 的 `PATH`。如果终端能找到而插件找不到，检查 Omarchy shell 启动环境；仅修改当前终端的 `PATH` 不会自动修改已运行 shell 的环境。
- **无法连接后台**：检查 `systemctl status <实际服务名>`，以及 `easytier-cli node`。插件使用 CLI 默认 RPC；如果 core 使用其他地址、随机端口或其他实例，当前插件不能通过设置切换到它。
- **开关不可用**：确认配置的是已加载的 systemd **系统服务**全名，例如 `easytier@default.service`。后台仍在启动或停止时，请等待后刷新。
- **认证失败或取消**：检查 `pkexec`、polkit 图形认证代理及当前用户权限；不要通过设置免认证规则来绕过授权。手动在终端执行 `sudo systemctl status <服务名>` 可检查服务状态。
- **状态正常但节点无法访问**：检查另一台设备是否在线、网络名称和密钥是否一致、节点连接与防火墙；根据需要查阅 EasyTier 官方文档。不要公开密钥或未经脱敏的地址、节点名、截图和日志。

## 开发与许可

```sh
python3 -m unittest discover -s tests
omarchy plugin validate .
```

插件代码采用 MIT 许可；状态栏图标根据 EasyTier 上游图标简化，采用单独的 LGPL-3.0 许可，来源及许可见 [`assets/NOTICE.md`](assets/NOTICE.md)。本项目是社区插件，不隶属于 EasyTier。
