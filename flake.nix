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
            config = {
              allowUnfree = true;
              permittedInsecurePackages = [
                "libsoup-2.74.3"
              ];
            };
          };
        in
        pkgs;
    in
    {
      # Overlay：供其他 flake 使用
      overlays.default = final: prev:
        let
          callPackage = final.callPackage;
        in
        {
          musicdl = callPackage ./pkgs/musicdl { };
          pywidevine = callPackage ./pkgs/pywidevine { };
          pymp4 = callPackage ./pkgs/pymp4 { };
          construct = callPackage ./pkgs/construct { };
          sunlogin = callPackage ./pkgs/sunlogin { };
          wecom-wine = callPackage ./pkgs/wecom-wine { };
          sub-store = callPackage ./pkgs/sub-store { };
          hanako = callPackage ./pkgs/hanako { };
          astudio = callPackage ./pkgs/astudio { };
          aurevoy = callPackage ./pkgs/aurevoy { };
          omp = callPackage ./pkgs/omp { };
          qq = callPackage ./pkgs/qq { };
          wechat = callPackage ./pkgs/wechat { };
          baidunetdisk = callPackage ./pkgs/baidunetdisk { };
        };

      # Packages：直接可安装的包
      packages = forAllSystems (system:
        let
          pkgs = pkgsForSystem system;
        in
        {
          musicdl = pkgs.musicdl;
          pywidevine = pkgs.pywidevine;
          pymp4 = pkgs.pymp4;
          construct = pkgs.construct;
          sunlogin = pkgs.sunlogin;
          wecom-wine = pkgs.wecom-wine;
          sub-store = pkgs.sub-store;
          hanako = pkgs.hanako;
          astudio = pkgs.astudio;
          aurevoy = pkgs.aurevoy;
          omp = pkgs.omp;
          qq = pkgs.qq;
          wechat = pkgs.wechat;
          baidunetdisk = pkgs.baidunetdisk;
          default = pkgs.musicdl;
        }
      );

      # 开发环境（可选）
      devShells = forAllSystems (system:
        let
          pkgs = pkgsForSystem system;
        in
        {
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
