{ lib
, fetchurl
, appimageTools
}:

# 腾讯官方直链打包的微信 Linux 版
# 4.1.13 起官方 AppImage 改为「安装器」形态：AppRun 要求 pkexec 把 wechat-payload.tar
# 安装到 /opt/wechat-appimage 再启动，Nix 环境下既不可写也没有 pkexec 流程。
# 这里在构建期解包 payload，换回一个直接 exec payload 内 wechat 的 AppRun。
# 注意：URL 不含版本号，上游会在同版本下重新打包（文件 mtime 变化即 hash 失效），
# 构建报 hash mismatch 时按新内容更新 hash，并到 https://linux.weixin.qq.com/ 核对版本号
let
  pname = "wechat";
  version = "4.1.13";

  src = fetchurl {
    url = "https://dldir1v6.qq.com/weixin/Universal/Linux/WeChatLinux_x86_64.AppImage";
    hash = "sha256-ZbFSuutgutjU8bjlq/gAse/WHkKUUh1pQFgQFos/wsM=";
  };

  meta = with lib; {
    description = "WeChat messaging and calling app for Linux";
    homepage = "https://weixin.qq.com/";
    license = licenses.unfree;
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    maintainers = [ ];
    mainProgram = "wechat";
  };

  appimageContents = appimageTools.extract {
    inherit pname version src;
    postExtract = ''
      tar -xf $out/wechat-payload.tar -C $out
      rm -f $out/wechat-payload.tar $out/wechat-payload.sha256 $out/install-apparmor.sh
      cat > $out/AppRun <<'EOF'
      #!/bin/sh
      APPDIR="$(cd "$(dirname "$0")" && pwd)"
      export APPDIR
      export PATH="$APPDIR:$PATH"
      exec "$APPDIR/wechat" "$@"
      EOF
      chmod +x $out/AppRun
    '';
  };
in
appimageTools.wrapAppImage {
  inherit pname version meta;

  src = appimageContents;

  # payload 只带自家 .so，宿主库仍需提供
  extraPkgs = pkgs: with pkgs; [
    alsa-lib
    at-spi2-core
    cups
    dbus
    fontconfig
    freetype
    glib
    gtk3
    libGL
    libdrm
    libgbm
    libpulseaudio
    libx11
    libxcb
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxkbcommon
    libxrandr
    nss
    systemd
  ];

  extraInstallCommands = ''
    mkdir -p $out/share/applications
    cp ${appimageContents}/wechat.desktop $out/share/applications/
    mkdir -p $out/share/icons/hicolor/256x256/apps
    cp ${appimageContents}/wechat.png $out/share/icons/hicolor/256x256/apps/

    substituteInPlace $out/share/applications/wechat.desktop --replace-fail AppRun wechat
  '';
}
