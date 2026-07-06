# Nix Packages

个人 Nix 包集合，使用 Nix Flake 管理。

## 包列表

| 包名 | 版本 | 描述 |
|------|------|------|
| [musicdl](https://github.com/CharlesPikachu/musicdl) | 2.12.5 | 多平台音乐下载工具 |
| [sunlogin](https://sunlogin.oray.com/) | 15.2.0.63064 | 向日葵远程桌面客户端 |
| [pywidevine](https://github.com/pywidevine/pywidevine) | 1.9.0 | Widevine DRM 工具库 |
| [pymp4](https://github.com/beardypig/pymp4) | 1.4.0 | 纯 Python MP4 解析器 |
| [construct](https://github.com/construct/construct) | 2.8.8 | 二进制数据解析库 |
| [wecom-wine](https://work.weixin.qq.com/) | 5.0.8.6009 | 企业微信 Windows 版 (Wine) |
| [sub-store](https://github.com/sub-store-org/Sub-Store) | 2.24.7 | 高级订阅管理工具 |
| [hanako](https://openhanako.com) | 0.350.2 | 有记忆、有性格的开源 AI 助理 |

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

## 贡献

欢迎提交 Issue 和 Pull Request！

## 致谢

- [Nixpkgs](https://github.com/NixOS/nixpkgs) - Nix 包集合
- [CharlesPikachu/musicdl](https://github.com/CharlesPikachu/musicdl) - 上游项目
