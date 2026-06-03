{
  description = "Nix packages collection";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      # 支持的系统列表
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      # 辅助函数：为每个支持的系统生成属性
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

      # 创建特定系统的包集合
      pkgsForSystem = system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ self.overlays.default ];
          };
        in pkgs;
    in
    {
      # Overlay：供其他 flake 使用
      overlays.default = final: prev:
        let
          callPackage = final.callPackage;
        in {
          musicdl = callPackage ./pkgs/musicdl {};
          pywidevine = callPackage ./pkgs/pywidevine {};
          pymp4 = callPackage ./pkgs/pymp4 {};
          construct = callPackage ./pkgs/construct {};
          sunlogin = callPackage ./pkgs/sunlogin {};
        };

      # Packages：直接可安装的包
      packages = forAllSystems (system:
        let
          pkgs = pkgsForSystem system;
        in {
          musicdl = pkgs.musicdl;
          pywidevine = pkgs.pywidevine;
          pymp4 = pkgs.pymp4;
          construct = pkgs.construct;
          sunlogin = pkgs.sunlogin;
          default = pkgs.musicdl;
        }
      );

      # 开发环境（可选）
      devShells = forAllSystems (system:
        let
          pkgs = pkgsForSystem system;
        in {
          default = pkgs.mkShell {
            buildInputs = with pkgs; [
              nixpkgs-fmt
              nil
            ];
          };
        }
      );
    };
}
