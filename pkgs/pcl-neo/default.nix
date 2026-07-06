{
  lib,
  fetchzip,
  appimageTools,
}:

let
  pname = "pcl-neo";
  version = "1.0";
  
  zipSrc = fetchzip {
    url = "https://github.com/LMQ00/PCL.Neo/releases/download/1.0/linux.x64.zip";
    hash = "sha256-9bhqE2ETxQtdIW3Q/soQh8enR2Xh/HdONJvBXlnXa8w=";
    stripRoot = false;
  };
  
  # AppImage 文件名
  appimage = "PCL.Neo.linux.x64.AppImage";
in
appimageTools.wrapType2 {
  inherit pname version;

  src = "${zipSrc}/${appimage}";

  # 添加 ICU 库作为运行时依赖
  extraPkgs = pkgs: [ pkgs.icu ];

  meta = with lib; {
    description = "A cross-platform Minecraft launcher based on Avalonia, rewritten from PCL2";
    homepage = "https://github.com/PCL-Community/PCL.Neo";
    downloadPage = "https://github.com/LMQ00/PCL.Neo/releases";
    license = licenses.mit;
    sourceProvenance = [ sourceTypes.binaryNativeCode ];
    maintainers = [];
    mainProgram = "pcl-neo";
    platforms = [ "x86_64-linux" ];
  };

  extraInstallCommands = ''
    mkdir -p $out/share/applications
    mkdir -p $out/share/pixmaps
    
    # 复制桌面文件（如果存在）
    if [ -f "$APPDIR/PCL.Neo.desktop" ]; then
      cp $APPDIR/PCL.Neo.desktop $out/share/applications/
      substituteInPlace $out/share/applications/PCL.Neo.desktop --replace-fail AppRun pcl-neo
    fi
    
    # 复制图标（如果存在）
    if [ -f "$APPDIR/PCL.Neo.png" ]; then
      cp $APPDIR/PCL.Neo.png $out/share/pixmaps/
    fi
  '';
}