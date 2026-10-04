# Nix Packages

个人 Nix 包集合，使用 Nix Flake 管理。

## 包列表

| 包名 | 版本 | 描述 |
|------|------|------|
| [musicdl](https://github.com/CharlesPikachu/musicdl) | 2.14.0 | 多平台音乐下载工具 |
| [sunlogin](https://sunlogin.oray.com/) | 16.6.0.32198 | 向日葵远程桌面客户端 (AweSun) |
| [pywidevine](https://github.com/pywidevine/pywidevine) | 1.9.0 | Widevine DRM 工具库 |
| [pymp4](https://github.com/beardypig/pymp4) | 1.4.0 | 纯 Python MP4 解析器 |
| [construct](https://github.com/construct/construct) | 2.8.8 | 二进制数据解析库 |
| [wecom-wine](https://work.weixin.qq.com/) | 5.0.11.6018 | 企业微信 Windows 版 (Wine) |
| [sub-store](https://github.com/sub-store-org/Sub-Store) | 2.42.2 | 高级订阅管理工具 |
| [hanako](https://openhanako.com) | 0.450.0 | 有记忆、有性格的开源 AI 助理 |
| [astudio](https://github.com/Candouber/Astudio) | 0.1.1-preview.4 | 多 Agent 协作任务执行工作台 |
| [aurevoy](https://github.com/nullskymc/Aurevoy) | 0.6.14 | 本地运行的通用 AI Agent 桌面应用 |
| [omp](https://omp.sh) | 18.6.0 | 终端 AI 编码 Agent，支持 LSP/DAP、子代理、40+ 模型提供商 |
| [qq](https://im.qq.com/index/) | 3.2.34 | 腾讯 QQ Linux 客户端 (NT 架构) |
| [wechat](https://weixin.qq.com/) | 4.1.13 | 微信 Linux 版 (AppImage) |
| [baidunetdisk](https://pan.baidu.com/download) | 8.7.0 | 百度网盘 Linux 客户端 (官方 deb，FHS 环境原生运行) |
| [dsh](https://github.com/deepseek-ai/deepseek-harness) | 0.2.0-rc.2 | DeepSeek 官方 Agent Harness |
| [open-orpheus](https://github.com/YUCLing/open-orpheus) | 0.19.1 | 网易云音乐官方客户端网页资源（Orpheus 宿主）的 Linux 运行环境 |

## 使用方法

### 作为 Flake Input 使用

将本仓库添加到你的 Flake 输入中：

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-packages = {
      url = "github:LMQ00/nix-packages";
      inputs.nixpkgs.follows = "nixpkgs";  # 可选：跟随你的 nixpkgs 版本
    };
  };

  outputs = { self, nixpkgs, nix-packages }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ nix-packages.overlays.default ];
      };
    in {
      # 使用 overlay 后可以直接使用 pkgs.musicdl
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = [ pkgs.musicdl ];
      };
    };
}
```

### 直接安装

#### 临时使用

```bash
nix run github:LMQ00/nix-packages#musicdl
```

#### 添加到系统配置 (NixOS)

在 `configuration.nix` 中添加：

```nix
{
  inputs.nix-packages.url = "github:LMQ00/nix-packages";

  # 在你的配置中
  environment.systemPackages = [
    inputs.nix-packages.packages.${system}.musicdl
  ];
}
```

#### 使用 Home Manager

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager.url = "github:nix-community/home-manager";
    nix-packages.url = "github:LMQ00/nix-packages";
  };

  # ... 在 home.nix 中
  home.packages = [
    inputs.nix-packages.packages.${system}.musicdl
  ];
}
```

### sunlogin 守护进程说明

sunlogin (AweSun) 的本地服务由 `awesun_daemon` 提供，GUI 通过 `/tmp/*_16090`
等 unix socket 与它通信。daemon 会校验客户端（`readlink /proc/<pid>/exe` 比对
自身 exe，或用内嵌公钥校验客户端的 `.sign` 段签名），因此有两条硬约束：

1. **不要改写 deb 内的二进制**：`.sign` 段是 RSA 签名，覆盖
   `MD5(整个文件去掉 .sign 段)`。任何 patchelf / autoPatchelfHook / strip 都会让
   签名失效，daemon 会拒绝 GUI 连接（日志 `[rpc/TcpSocket] Verify client failed!`），
   界面停在「正在连接服务...」。本包不做任何字节改写（运行库经 FHS rootfs 与
   `LD_LIBRARY_PATH` 提供），构建期还会用内嵌公钥自校验，改坏即构建失败。
2. **跨 bwrap user namespace 的 `readlink /proc/<pid>/exe` 会 EPERM**，因此
   daemon 与 GUI 必须"同沙箱"，或 daemon 以 **root**（初始 user namespace，
   拥有 `CAP_SYS_PTRACE`）运行。KDE 每次启动都是一个新 transient unit（新沙箱），
   所以常驻的用户级 daemon 无法服务下一次启动的 GUI。

另外，界面里的登录页 / 设备页等是内嵌 WebKit 视图，依赖已在 `libs` 与
`sunlogin-start.sh` 中备好：`webkitgtk_4_1`（缺则页面一直转圈，
日志 `WEBKIT_LOAD_FAILED`）与 `glib-networking` 的 GIO TLS 模块
（缺则 HTTPS 页面白屏，页面内报 `TLS support is not available`，
脚本里用 `GIO_EXTRA_MODULES` 指向它）。

推荐（可无人值守、关掉 GUI 也能被远控）：以系统服务方式常驻 root daemon：

```nix
# configuration.nix（系统侧，不是 home-manager）
{
  systemd.packages = [ inputs.nix-packages.packages.${system}.sunlogin ];
  systemd.services.runawesun.wantedBy = [ "multi-user.target" ];
}
```

兜底（不启用上面的服务时）：`sunlogin-start.sh` 会清掉跨沙箱残留的用户 daemon，
在本次 GUI 自己的沙箱内起一个同沙箱 daemon，并在 GUI 退出时一并回收
（因此这种情况下"关掉 GUI"就等于服务下线）。若检测到已有 root daemon，
脚本直接复用它、不做任何清理。

### 使用 Overlay

Overlay 提供了更灵活的集成方式：

```nix
{
  # 将 overlay 应用到你的 nixpkgs
  pkgs = import nixpkgs {
    overlays = [ nix-packages.overlays.default ];
  };

  # 然后直接使用
  environment.systemPackages = [ pkgs.musicdl ];
}
```

## 支持的平台

- x86_64-linux
- aarch64-linux
- x86_64-darwin
- aarch64-darwin

## 构建说明

### 首次构建

首次构建时，需要替换 `pkgs/musicdl/default.nix` 中的占位 hash：

```nix
hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
```

将其替换为实际的 hash。可以通过以下方式获取：

```bash
# 方法 1：尝试构建，Nix 会显示期望的 hash
nix build .#musicdl 2>&1 | grep "got:"

# 方法 2：使用 nix-prefetch-url
nix-prefetch-url --unpack "https://github.com/CharlesPikachu/musicdl/archive/v2.12.5.tar.gz"

# 方法 3：使用 nix-update（如果安装了）
nix-update musicdl --url "https://github.com/CharlesPikachu/musicdl"
```

### 更新包版本

1. 修改 `pkgs/musicdl/default.nix` 中的 `version`
2. 将 `hash` 设置为 `lib.fakeHash` 或空的占位符
3. 运行 `nix build` 获取新的 hash
4. 更新 hash 值

## 开发

### 进入开发环境

```bash
nix develop
```

### 格式化代码

```bash
nix fmt
```

## 许可证

本仓库中的 Nix 包定义遵循 MIT 许可证。

各个包的许可证请参考其上游项目的许可证：
- musicdl: [PolyForm-Noncommercial-1.0.0](https://github.com/CharlesPikachu/musicdl/blob/main/LICENSE)
- sunlogin: 闭源商业软件 (unfree)
- wecom-wine: 闭源商业软件 (unfree)
- hanako: [Apache 2.0](https://github.com/liliMozi/openhanako/blob/main/LICENSE)
- astudio: [MIT](https://github.com/Candouber/Astudio/blob/main/LICENSE)
- aurevoy: [MIT](https://github.com/nullskymc/Aurevoy/blob/main/LICENSE)
- omp: [MIT](https://github.com/can1357/oh-my-pi/blob/main/LICENSE)
- qq: 闭源商业软件 (unfree)
- wechat: 闭源商业软件 (unfree)
- baidunetdisk: 闭源商业软件 (unfree)（官方 deb 原样运行；内联 gtkmm 2.24.5 供 libbrowserengine 使用）
- dsh: [MIT](https://github.com/deepseek-ai/deepseek-harness/blob/main/LICENSE)
- open-orpheus: [MIT](https://github.com/YUCLing/open-orpheus/blob/main/LICENSE)（不含网易所有的资源文件，首次启动时由程序从网易 CDN 下载到用户数据目录）

## 贡献

欢迎提交 Issue 和 Pull Request！

## 致谢

- [Nixpkgs](https://github.com/NixOS/nixpkgs) - Nix 包集合
- [CharlesPikachu/musicdl](https://github.com/CharlesPikachu/musicdl) - 上游项目
