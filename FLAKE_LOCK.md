# Flake Lock 说明

`flake.lock` 文件需要通过以下命令生成：

```bash
cd nix-packages
nix flake lock
```

这会自动下载并锁定 nixpkgs 的版本，创建 `flake.lock` 文件。

## 为什么需要这个文件？

`flake.lock` 文件确保：
- 构建的可重现性
- 锁定所有依赖的精确版本
- 其他用户使用相同的依赖版本

## 更新依赖

```bash
# 更新所有输入
nix flake update

# 更新特定输入
nix flake update nixpkgs
```

## 注意事项

- 不要手动编辑 `flake.lock` 文件
- 首次克隆仓库后需要运行 `nix flake lock`
- 提交 `flake.lock` 到版本控制以确保可重现性
