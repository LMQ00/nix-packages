{ lib
, stdenv
, fetchurl
, dpkg
, makeWrapper
, patchelf
, file
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
stdenv.mkDerivation rec {
  pname = "sunlogin";
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
    makeWrapper $out/opt/sunlogin/bin/sunloginclient $out/bin/sunloginclient \
      --set SUNLOGIN_HOME "$out/opt/sunlogin"

    # 更新桌面文件
    mkdir -p $out/share/applications
    cp usr/share/applications/sunlogin.desktop $out/share/applications/
    substituteInPlace $out/share/applications/sunlogin.desktop \
      --replace "/usr/local/sunlogin/bin/sunloginclient" "$out/bin/sunloginclient" \
      --replace "/usr/local/sunlogin/res/icon/sunlogin_client.png" "$out/opt/sunlogin/res/icon/sunlogin_client.png"

    runHook postInstall
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
