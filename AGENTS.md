# Work 目录

## 概述

这是存放nix包的目录。

## 项目列表

### nix-packages

**路径**: `/home/LMQ/work/nix-packages`  
**仓库**: https://github.com/LMQ00/nix-packages  
**描述**: 个人 Nix 包集合，使用 Flake 管理

#### 包列表

| 包名 | 版本 | 描述 |
|------|------|------|
| musicdl | 2.12.5 | 多平台音乐下载工具 |
| sunlogin | 15.2.0.63064 | 向日葵远程桌面客户端 |
| pywidevine | 1.9.0 | Widevine DRM 工具库 |
| pymp4 | 1.4.0 | 纯 Python MP4 解析器 |
| construct | 2.8.8 | 二进制数据解析库 |
| wecom-wine | 5.0.8.6009 | 企业微信 Windows 版 (Wine) |
| sub-store | 2.24.7 | 高级订阅管理工具 |
| hanako | 0.350.2 | 有记忆、有性格的开源 AI 助理 |

#### 使用方式

```bash
# 直接运行
nix run github:LMQ00/nix-packages#musicdl --impure

# 构建
NIXPKGS_ALLOW_UNFREE=1 nix build .#<包名> --impure

# 示例
nix run github:LMQ00/nix-packages#wecom-wine --impure
```

#### 添加新包

1. 在 `pkgs/<包名>/default.nix` 创建包定义
2. 在 `flake.nix` 的 overlay 中添加 `callPackage`
3. 在 `flake.nix` 的 packages 中导出
4. **更新 `README.md` 的包列表和许可证说明**
5. 推送到 GitHub

#### ⚠️ 重要规则

**每次增改包必须同步更新以下文件：**
- `README.md` - 包列表、许可证说明
- `AGENTS.md` - 包列表（如在工作目录中）
- NixOS 配置（如需要安装到系统）

#### 🔧 构建规范

1. **禁止 FHS 环境**：不要使用 `buildFHSUserEnv` 或创建 FHS 环境。如遇实在需要，必须先询问用户确认

2. **原子化构建**：从最干净、最原子化的逻辑去构建，每次构建应该是独立的、可复现的

3. **构建后清理**：每次测试构建完成后，必须清理构建占用的环境（如 `nix-store --gc` 清理无用路径）

4. **提交规范**：测试完成后不要自行 commit，而是输出一段 commit message 给用户，由用户来 commit

## 常用命令

### Nix 相关

```bash
# 构建包
NIXPKGS_ALLOW_UNFREE=1 nix build .#<包名> --impure

# 运行包
nix run github:LMQ00/nix-packages#<包名> --impure

# 更新 flake 输入
nix flake update
```

## 注意事项

- 许可证为 unfree 的包（musicdl, sunlogin, wecom-wine）需要 `--impure` 标志
- sunlogin 依赖 libsoup_2_4（已忽略缺失）
- wecom-wine 首次运行会复制 Wine 前缀到 `~/.local/share/wecom-wine/`（约 500MB）
- 首次构建会下载依赖，可能需要较长时间
- 如遇 hash 错误，Nix 会提示正确的 hash

---

**最后更新**: 2026-06-07
