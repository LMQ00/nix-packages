{ lib
, stdenv
, fetchurl
, autoPatchelfHook
, dpkg
, makeWrapper
, writeShellScript
, bash
  # Electron runtime dependencies
, alsa-lib
, atk
, at-spi2-atk
, at-spi2-core
, cairo
, cups
, dbus
, expat
, fontconfig
, freetype
, gdk-pixbuf
, glib
, gtk3
, harfbuzz
, libdrm
, libglvnd
, libnotify
, libpulseaudio
, libxkbcommon
, libxml2
, mesa
, nspr
, nss
, pango
, pipewire
, systemd
, wayland
, xorg
, zlib
, libuuid
, libsecret
, libappindicator-gtk3
, sqlite
, libffi
, util-linux
, libcap
}:

let
  version = "0.421.24";
  src = fetchurl {
    url = "https://github.com/liliMozi/openhanako/releases/download/v${version}/HanaAgent-${version}-Linux-amd64.deb";
    hash = "sha256-/qc8zgFkOyCBZl1bmr7FBSteh+Kj2z/U1IehslLxegg=";
  };

  # 启动前修复 config 权限的外层包装
  wrapperScript = writeShellScript "hanako-wrapper" ''
    # 修复从 bundle 复制的只读配置文件权限
    HANA_HOME="''${HANA_HOME:-$HOME/.hanako}"
    if [ -d "$HANA_HOME/agents/hanako" ]; then
      chmod -R u+w "$HANA_HOME/agents/hanako" 2>/dev/null || true
    fi
    exec @out@/bin/.hanako-wrapped "$@"
  '';
in
stdenv.mkDerivation {
  pname = "hanako";
  inherit version src;

  nativeBuildInputs = [
    autoPatchelfHook
    dpkg
    makeWrapper
  ];

  buildInputs = [
    alsa-lib
    atk
    at-spi2-atk
    at-spi2-core
    cairo
    cups
    dbus
    expat
    fontconfig
    freetype
    gdk-pixbuf
    glib
    gtk3
    harfbuzz
    libcap
    libdrm
    libffi
    libglvnd
    libnotify
    libpulseaudio
    libsecret
    libuuid
    libxkbcommon
    libxml2
    mesa
    nspr
    nss
    pango
    pipewire
    sqlite
    systemd
    util-linux
    wayland
    xorg.libX11
    xorg.libXcomposite
    xorg.libXcursor
    xorg.libXdamage
    xorg.libXext
    xorg.libXfixes
    xorg.libXi
    xorg.libXrandr
    xorg.libXrender
    xorg.libXtst
    xorg.libxcb
    xorg.libxkbfile
    zlib
    stdenv.cc.cc.lib
  ]
  # 系统托盘支持（可选）
  ++ lib.optional (libappindicator-gtk3 != null) libappindicator-gtk3;

  unpackPhase = ''
    runHook preUnpack
    mkdir -p unpacked
    cd unpacked
    dpkg-deb -x "$src" .
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    # 安装应用文件
    mkdir -p $out/lib/hanako
    cp -r opt/HanaAgent/* $out/lib/hanako/

    # 修复文件权限：.deb 提取出的文件可能继承打包时的只读权限
    # 尤其是 resources/server/ 下的 Node.js 服务端需要在运行时写入配置
    chmod -R u+w $out/lib/hanako

    # 创建 bin 包装脚本
    mkdir -p $out/bin

    # 先用 makeWrapper 创建基础包装（环境变量 + GPU 加速路径）
    makeWrapper $out/lib/hanako/hanako $out/bin/.hanako-wrapped \
      --add-flags "--no-sandbox" \
      --set CHROME_SANDBOX "$out/lib/hanako/chrome-sandbox" \
      --set ELECTRON_OZONE_PLATFORM_HINT "x11" \
      --prefix LD_LIBRARY_PATH : "$out/lib/hanako" \
      --prefix LD_LIBRARY_PATH : "/run/opengl-driver/lib" \
      --set LIBGL_DRIVERS_PATH "/run/opengl-driver/lib/dri"

    # 外层 shell 包装：启动前修复 ~/.hanako/agents/hanako/ 的只读权限
    cp ${wrapperScript} $out/bin/hanako
    substituteInPlace $out/bin/hanako --replace-fail @out@ $out
    chmod +x $out/bin/hanako

    # 安装桌面快捷方式
    mkdir -p $out/share/applications
    substitute usr/share/applications/hanako.desktop $out/share/applications/hanako.desktop \
      --replace /opt/HanaAgent/hanako hanako

    # 安装图标
    mkdir -p $out/share/icons/hicolor/2048x2048/apps
    cp usr/share/icons/hicolor/2048x2048/apps/hanako.png $out/share/icons/hicolor/2048x2048/apps/

    runHook postInstall
  '';

  # 让 autoPatchelfHook 自动修补所有 ELF 文件
  # 包括 bundeld Electron 二进制、Node.js、以及 native addons
  autoPatchelfDirectoriesList = [ "$out/lib/hanako" ];

  meta = with lib; {
    description = "HanaAgent - a personal AI agent with memory, personality, and autonomy";
    longDescription = ''
      OpenHanako (HanaAgent) is a personal AI agent that has memory, personality, and autonomy.
      It can remember your preferences, help with daily tasks, and operate your computer.
      Built on Electron with a Node.js backend.
    '';
    homepage = "https://openhanako.com";
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    license = licenses.asl20;
    platforms = [ "x86_64-linux" ];
    maintainers = [ ];
    mainProgram = "hanako";
  };
}
