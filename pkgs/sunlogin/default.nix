{ lib
, stdenv
, fetchurl
, dpkg
, makeWrapper
, patchelf
, file
, buildFHSEnv
, libappindicator-gtk3
, xorg
, gtk3
, glib
, nss
, nspr
, cups
, libdrm
, mesa
, libGL
, libglvnd
, openssl
, libxcrypt
, zlib
, pango
, cairo
, gdk-pixbuf
, atk
, wayland
, libxkbcommon
, libsecret
, libnotify
, udev
, util-linux
, dbus
, fontconfig
, freetype
, alsa-lib
, libpulseaudio
, libepoxy
}:

let
  # 上游已将向日葵 Linux 客户端改名为 AweSun
  version = "16.6.0.32198";

  src = fetchurl {
    url = "https://dw.oray.com/sl/linux/awesun_${version}_amd64.deb";
    hash = "sha256-dtLVNEE6WKi79cV3teYXjj6vimhTBMAnrwL6TpItVjk=";
  };

  # libcrypt.so.1 兼容包装库
  # 程序原本依赖 glibc 的 libcrypt.so.1（提供 crypt@GLIBC_2.2.5）
  # 现代 glibc 已移除 libcrypt，改用 libxcrypt（提供 libcrypt.so.2, XCRYPT_2.0）
  # 这个包装库转发调用到 libcrypt.so.2，并保持 GLIBC_2.2.5 版本标签
  libcrypt-compat = stdenv.mkDerivation {
    pname = "libcrypt-compat";
    inherit version;

    dontUnpack = true;

    buildPhase = ''
      cat > libcrypt_compat.c << 'CEOF'
      #define _GNU_SOURCE
      #include <dlfcn.h>

      typedef char *(*crypt_fn)(const char *, const char *);
      typedef char *(*crypt_r_fn)(const char *, const char *, void *);

      static void *handle = 0;

      static void init(void) {
          handle = dlopen("${lib.getLib libxcrypt}/lib/libcrypt.so.2", RTLD_LAZY);
      }

      char *crypt(const char *key, const char *salt) {
          if (!handle) init();
          crypt_fn fn = (crypt_fn)dlsym(handle, "crypt");
          return fn(key, salt);
      }

      char *crypt_r(const char *key, const char *salt, void *data) {
          if (!handle) init();
          crypt_r_fn fn = (crypt_r_fn)dlsym(handle, "crypt_r");
          return fn(key, salt, data);
      }
      CEOF

      cat > libcrypt_compat.map << 'MEOF'
      GLIBC_2.2.5 {
          global:
              crypt;
              crypt_r;
      };
      MEOF

      gcc -shared -fPIC -o libcrypt.so.1 libcrypt_compat.c \
          -Wl,--version-script=libcrypt_compat.map \
          -Wl,-soname,libcrypt.so.1 \
          -ldl
    '';

    installPhase = ''
      mkdir -p $out/lib
      cp libcrypt.so.1 $out/lib/
    '';

    nativeBuildInputs = [ stdenv.cc ];
  };

  # 需要的库
  libs = [
    stdenv.cc.cc.lib
    libappindicator-gtk3
    xorg.libX11
    xorg.libXext
    xorg.libXScrnSaver
    xorg.libXtst
    xorg.libXdamage
    xorg.libXcomposite
    xorg.libXi
    xorg.libXcursor
    xorg.libXrender
    xorg.libXfixes
    xorg.libXrandr
    xorg.libXinerama
    xorg.libSM
    xorg.libICE
    xorg.libxcb
    xorg.xorgproto
    gtk3
    glib
    nss
    nspr
    cups
    libdrm
    mesa
    libGL
    libglvnd
    openssl
    libxcrypt
    zlib
    pango
    cairo
    gdk-pixbuf
    atk
    wayland
    libxkbcommon
    libsecret
    libnotify
    udev
    util-linux
    dbus
    fontconfig
    freetype
    alsa-lib
    libpulseaudio
    libepoxy
  ];

in
let
  # 原始 AweSun 包（未包装 FHS 环境）
  awesun-unwrapped = stdenv.mkDerivation rec {
    pname = "awesun-unwrapped";
    inherit version;

    inherit src;

    nativeBuildInputs = [
      dpkg
      makeWrapper
      patchelf
      file
    ];

    # 不使用 auto-patchelf
    dontAutoPatchelf = true;
    # 禁用自动 ELF 修补，防止覆盖手动设置的 RPATH
    dontPatchELF = true;

    unpackPhase = "dpkg-deb -x $src .";

    installPhase = ''
      runHook preInstall

      mkdir -p $out/opt
      cp -r usr/local/awesun $out/opt/awesun

      # 获取动态链接器路径
      INTERP="${stdenv.cc.bintools.dynamicLinker}"

      # 设置 RPATH，包含兼容库目录和 Flutter 插件库目录
      RPATH="${lib.makeLibraryPath libs}:${libcrypt-compat}/lib:$out/opt/awesun/lib"

      find $out/opt/awesun -type f | while read f; do
        if file "$f" | grep -q "ELF"; then
          chmod +w "$f"
          # 设置正确的动态链接器
          patchelf --set-interpreter "$INTERP" "$f" 2>/dev/null || true
          # 设置 RPATH（包含 libcrypt.so.1 兼容库）
          patchelf --set-rpath "$RPATH" "$f" 2>/dev/null || true
        fi
      done

      mkdir -p $out/bin
      mkdir -p $out/opt/awesun/log

      # GUI 入口
      ln -s $out/opt/awesun/awesun $out/bin/awesun

      # 更新桌面文件
      mkdir -p $out/share/applications
      cp usr/share/applications/awesun.desktop $out/share/applications/
      substituteInPlace $out/share/applications/awesun.desktop \
        --replace "/usr/local/awesun/awesun" "$out/opt/awesun/awesun" \
        --replace "/usr/local/awesun/awesun.png" "$out/opt/awesun/awesun.png"

      runHook postInstall
    '';

    meta = with lib; {
      description = "AweSun (formerly Sunlogin) remote desktop client (unwrapped)";
      homepage = "https://sunlogin.oray.com/";
      license = licenses.unfree;
      platforms = [ "x86_64-linux" ];
      maintainers = [ ];
    };
  };
in
# 使用 buildFHSEnv 创建 FHS 兼容环境
  # 解决程序硬编码 /usr/local/awesun 路径的问题
  # 程序内部构造 Flutter 资源路径和守护进程路径时直接使用 /usr/local/awesun
buildFHSEnv {
  pname = "sunlogin";
  inherit version;

  # 运行自定义启动脚本
  runScript = "/usr/local/sunlogin-start.sh";

  # 需要的包
  targetPkgs = pkgs: [
    awesun-unwrapped
  ] ++ libs;

  # 安装桌面文件和图标
  extraInstallCommands = ''
    mkdir -p $out/share/applications
    mkdir -p $out/share/icons/hicolor/256x256/apps
    cp ${awesun-unwrapped}/share/applications/awesun.desktop $out/share/applications/
    cp ${awesun-unwrapped}/opt/awesun/awesun.png $out/share/icons/hicolor/256x256/apps/
    substituteInPlace $out/share/applications/awesun.desktop \
      --replace "/usr/local/awesun/awesun" "sunlogin" \
      --replace "/usr/local/awesun/awesun.png" "awesun" \
      --replace "${awesun-unwrapped}/opt/awesun/awesun" "sunlogin" \
      --replace "${awesun-unwrapped}/opt/awesun/awesun.png" "awesun"
  '';

  # 在 FHS 环境中创建符号链接和启动脚本
  extraBuildCommands = ''
        mkdir -p $out/usr/local
        # 用真实目录而非 symlink 提供 /usr/local/awesun：
        # symlink 会被 execve 解析为 store 路径，导致 awesun_daemon 的
        # 客户端校验（readlink /proc/<pid>/exe 前缀匹配 /usr/local/awesun）失败，
        # GUI 连上 daemon 后被 RST（日志 Verify client failed），表现为登录/网络不可用。
        # bwrap 对 rootfs 中的目录使用 --ro-bind 挂载，进程 exe 路径保持 /usr/local/awesun/awesun。
        cp -r ${awesun-unwrapped}/opt/awesun $out/usr/local/awesun

        # 创建启动脚本（在 /usr/local 下，和 awesun 同级）
        cat > $out/usr/local/sunlogin-start.sh <<'SCRIPT'
    #!/bin/bash
    mkdir -p /tmp/awesun-$USER 2>/dev/null
    if ! pgrep -x awesun_daemon >/dev/null 2>&1; then
      /usr/local/awesun/bin/awesun_daemon -m server -name awesun &>/dev/null &
      sleep 1
    fi
    exec /usr/local/awesun/awesun "$@"
    SCRIPT
        chmod +x $out/usr/local/sunlogin-start.sh
  '';

  meta = with lib; {
    description = "AweSun (formerly Sunlogin) remote desktop client";
    homepage = "https://sunlogin.oray.com/";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
    maintainers = [ ];
    mainProgram = "sunlogin";
  };
}
