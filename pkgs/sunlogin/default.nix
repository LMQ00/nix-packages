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
, gconf
, fontconfig
, freetype
, alsa-lib
, libpulseaudio
}:

let
  version = "15.2.0.63064";

  src = fetchurl {
    url = "https://down.oray.com/sunlogin/linux/SunloginClient_${version}_amd64.deb";
    hash = "sha256-3a5dNk64tpQGoOGDSQRQ/S+R8HKXKzcI6VGOiFLLimM=";
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
    gconf
    fontconfig
    freetype
    alsa-lib
    libpulseaudio
  ];

in
let
  # 原始 sunlogin 包（未包装 FHS 环境）
  sunlogin-unwrapped = stdenv.mkDerivation rec {
    pname = "sunlogin-unwrapped";
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
      cp -r usr/local/sunlogin $out/opt/sunlogin

      # 创建 locale 文件的符号链接
      # 程序对 locale 文件使用不同于 CEF 资源的路径解析机制：
      # - CEF 资源 (cef.pak 等): 通过符号链接路径 /usr/local/sunlogin/res/cef.pak ✅
      # - Locale 文件: 通过解析后的真实路径 /nix/store/.../res/zh-CN.pak（缺少 locales/ 子目录）❌
      # 解决方案: 在 res/ 目录下创建指向 res/locales/ 的符号链接
      for locale_file in $out/opt/sunlogin/res/locales/*.pak; do
        if [ -f "$locale_file" ]; then
          base_name=$(basename "$locale_file")
          ln -sf "locales/$base_name" "$out/opt/sunlogin/res/$base_name"
        fi
      done

      # 获取动态链接器路径
      INTERP="${stdenv.cc.bintools.dynamicLinker}"
      
      # 设置 RPATH，包含兼容库目录
      RPATH="${lib.makeLibraryPath libs}:${libcrypt-compat}/lib:$out/opt/sunlogin/lib:$out/opt/sunlogin/lib/back:$out/opt/sunlogin/lib/swiftshader"

      find $out/opt/sunlogin -type f | while read f; do
        if file "$f" | grep -q "ELF"; then
          chmod +w "$f"
          # 设置正确的动态链接器
          patchelf --set-interpreter "$INTERP" "$f" 2>/dev/null || true
          # 设置 RPATH（包含 libcrypt.so.1 兼容库）
          patchelf --set-rpath "$RPATH" "$f" 2>/dev/null || true
        fi
      done

      mkdir -p $out/bin
      mkdir -p $out/opt/sunlogin/log





      # 更新桌面文件
      mkdir -p $out/share/applications
      cp usr/share/applications/sunlogin.desktop $out/share/applications/
      substituteInPlace $out/share/applications/sunlogin.desktop \
        --replace "/usr/local/sunlogin/bin/sunloginclient" "$out/bin/sunloginclient" \
        --replace "/usr/local/sunlogin/res/icon/sunlogin_client.png" "$out/opt/sunlogin/res/icon/sunlogin_client.png"

      runHook postInstall
    '';

    meta = with lib; {
      description = "Sunlogin remote desktop client (unwrapped)";
      homepage = "https://sunlogin.oray.com/";
      license = licenses.unfree;
      platforms = [ "x86_64-linux" ];
      maintainers = [ ];
    };
  };
in
# 使用 buildFHSEnv 创建 FHS 兼容环境
# 解决程序硬编码 /usr/local/sunlogin 路径的问题
# 程序内部构造 CEF 参数：--locales-dir-path=/usr/local/sunlogin/res
# 和 --resources-dir-path=/usr/local/sunlogin/res
buildFHSEnv {
  pname = "sunlogin";
  inherit version;

  # 运行自定义启动脚本
  runScript = "/usr/local/sunlogin-start.sh";

  # 需要的包
  targetPkgs = pkgs: [
    sunlogin-unwrapped
  ] ++ libs;

  # 安装桌面文件和图标
  extraInstallCommands = ''
    mkdir -p $out/share/applications
    mkdir -p $out/share/icons/hicolor/256x256/apps
    cp ${sunlogin-unwrapped}/share/applications/sunlogin.desktop $out/share/applications/
    cp ${sunlogin-unwrapped}/opt/sunlogin/res/icon/sunlogin_client.png $out/share/icons/hicolor/256x256/apps/
    substituteInPlace $out/share/applications/sunlogin.desktop \
      --replace "/usr/local/sunlogin/bin/sunloginclient" "sunlogin" \
      --replace "/usr/local/sunlogin/res/icon/sunlogin_client.png" "sunlogin_client" \
      --replace "${sunlogin-unwrapped}/bin/sunloginclient" "sunlogin" \
      --replace "${sunlogin-unwrapped}/opt/sunlogin/res/icon/sunlogin_client.png" "sunlogin_client"
  '';

  # 在 FHS 环境中创建符号链接和启动脚本
  extraBuildCommands = ''
    mkdir -p $out/usr/local
    ln -sf ${sunlogin-unwrapped}/opt/sunlogin $out/usr/local/sunlogin

    # 创建启动脚本（在 /usr/local 下，和 sunlogin 同级）
    cat > $out/usr/local/sunlogin-start.sh <<'SCRIPT'
#!/bin/bash
mkdir -p /tmp/sunlogin-$USER/log 2>/dev/null
if ! pgrep -x oray_rundaemon >/dev/null 2>&1; then
  /usr/local/sunlogin/bin/oray_rundaemon -m server &>/dev/null &
  sleep 1
fi
exec /usr/local/sunlogin/bin/sunloginclient --no-sandbox "$@"
SCRIPT
    chmod +x $out/usr/local/sunlogin-start.sh
  '';

  meta = with lib; {
    description = "Sunlogin remote desktop client";
    homepage = "https://sunlogin.oray.com/";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
    maintainers = [ ];
    mainProgram = "sunloginclient";
  };
}
