{ lib
, stdenv
, fetchurl
, wine
, makeWrapper
, writeShellScript
}:

let
  version = "5.0.8.6009";

  src = fetchurl {
    url = "https://dldir1.qq.com/wework/work_weixin/WeCom_${version}.exe";
    hash = "sha256-yI42hV8LclQbxpEZS9wM5JXpP7JTcpbGrTe+RsEhhkc=";
  };

  # 启动脚本模板（在 installPhase 中使用 substituteInPlace 替换路径）
  startScriptTemplate = writeShellScript "wecom-wine" ''
    # 用户 Wine 前缀目录（持久化数据）
    USER_WINEPREFIX="''${WECOM_WINEPREFIX:-$HOME/.local/share/wecom-wine/wineprefix}"
    TEMPLATE_WINEPREFIX="@WINEPREFIX_TEMPLATE@"

    # 如果用户前缀不存在，从模板复制
    if [ ! -d "$USER_WINEPREFIX" ]; then
      echo "首次启动，正在初始化企业微信环境..."
      mkdir -p "$(dirname "$USER_WINEPREFIX")"
      cp -r "$TEMPLATE_WINEPREFIX" "$USER_WINEPREFIX"
      chmod -R u+w "$USER_WINEPREFIX"
    fi

    export WINEPREFIX="$USER_WINEPREFIX"
    export WINEDEBUG=-all

    # 查找企业微信可执行文件
    WECOM_EXE=""
    for exe in \
      "$WINEPREFIX/drive_c/Program Files/WXWork/WXWork.exe" \
      "$WINEPREFIX/drive_c/Program Files/Tencent/WeCom/WeCom.exe" \
      "$WINEPREFIX/drive_c/Program Files (x86)/Tencent/WeCom/WeCom.exe"; do
      if [ -f "$exe" ]; then
        WECOM_EXE="$exe"
        break
      fi
    done

    if [ -z "$WECOM_EXE" ]; then
      echo "错误：找不到企业微信可执行文件"
      exit 1
    fi

    # 运行企业微信
    exec "@WINE_BIN@" "$WECOM_EXE" "$@"
  '';

in
stdenv.mkDerivation {
  pname = "wecom-wine";
  inherit version;
  inherit src;

  nativeBuildInputs = [
    wine
    makeWrapper
  ];

  # 禁用默认阶段（.exe 文件不需要解压）
  dontUnpack = true;
  dontPatchELF = true;
  dontStrip = true;
  dontFixup = true;

  # 预安装阶段：在构建时用 Wine 安装企业微信
  # 生成一个包含已安装程序的 Wine 前缀模板
  buildPhase = ''
    runHook preBuild

    # 创建 Wine 前缀目录
    export WINEPREFIX=$out/share/wineprefix
    mkdir -p $WINEPREFIX

    # 抑制 Wine 调试输出
    export WINEDEBUG=-all

    # 初始化 Wine 前缀
    echo "初始化 Wine 环境..."
    wineboot --init 2>/dev/null || true
    sleep 2

    # 运行企业微信安装程序（静默模式）
    echo "正在安装企业微信..."
    wine "$src" /S 2>/dev/null || true
    sleep 3

    # 关闭 Wine 服务
    wineserver -k 2>/dev/null || true

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    # 创建启动脚本
    mkdir -p $out/bin
    cp ${startScriptTemplate} $out/bin/wecom-wine
    chmod +x $out/bin/wecom-wine
    substituteInPlace $out/bin/wecom-wine \
      --replace "@WINEPREFIX_TEMPLATE@" "$out/share/wineprefix" \
      --replace "@WINE_BIN@" "${wine}/bin/wine"
    chmod +x $out/bin/wecom-wine

    # 创建桌面文件
    mkdir -p $out/share/applications
    cat > $out/share/applications/wecom-wine.desktop << 'DESKTOP'
[Desktop Entry]
Name=企业微信 (Wine)
Comment=企业微信 Windows 版 (通过 Wine 运行)
Exec=wecom-wine %u
Icon=wecom-wine
Terminal=false
Type=Application
Categories=Network;InstantMessaging;Office;
DESKTOP

    runHook postInstall
  '';

  meta = with lib; {
    description = "企业微信 Windows 版 (通过 Wine 运行)";
    homepage = "https://work.weixin.qq.com/";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
    maintainers = [ ];
    mainProgram = "wecom-wine";
  };
}
