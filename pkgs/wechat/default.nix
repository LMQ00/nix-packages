{ lib
, stdenvNoCC
, fetchurl
, appimageTools
, patchelf
}:

# 腾讯官方直链打包的微信 Linux 版
# nixpkgs 中的 wechat 使用 web.archive.org 存档源（官方 dldir1v6 直链文件与
# nixpkgs 锁定的 hash 不一致），本包改用当前官方直链
# 注意：URL 不含版本号，上游会在同版本下重新打包（文件 mtime 变化即 hash 失效），
# 构建报 hash mismatch 时按新内容更新 hash，并到 https://linux.weixin.qq.com/ 核对版本号
let
  pname = "wechat";
  version = "4.1.13";

  src = fetchurl {
    url = "https://dldir1v6.qq.com/weixin/Universal/Linux/WeChatLinux_x86_64.AppImage";
    hash = "sha256-T1StKQLs1vb9xWgLc1R/gNVCO/RwsBI3pXmi5bPK7us=";
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
      patchelf --replace-needed libtiff.so.5 libtiff.so $out/opt/wechat/wechat
    '';
  };
in
appimageTools.wrapAppImage {
  inherit pname version meta;

  src = appimageContents;

  extraInstallCommands = ''
    mkdir -p $out/share/applications
    cp ${appimageContents}/wechat.desktop $out/share/applications/
    mkdir -p $out/share/icons/hicolor/256x256/apps
    cp ${appimageContents}/wechat.png $out/share/icons/hicolor/256x256/apps/

    substituteInPlace $out/share/applications/wechat.desktop --replace-fail AppRun wechat
  '';
}
