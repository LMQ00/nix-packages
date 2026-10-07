{ lib
, stdenv
, fetchurl
, autoPatchelfHook
, dpkg
, makeWrapper
  # Electron 运行时依赖
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
, gsettings-desktop-schemas
, gtk3
, libdrm
, libgbm
, libglvnd
, libnotify
, libpulseaudio
, libuuid
, libx11
, libxcb
, libxcomposite
, libxcursor
, libxdamage
, libxext
, libxfixes
, libxi
, libxkbcommon
, libxrandr
, libxrender
, mesa
, nspr
, nss
, pango
, systemd
, xdg-utils
, zlib
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "open-orpheus";
  version = "0.19.2";

  src = fetchurl {
    url = "https://github.com/YUCLing/open-orpheus/releases/download/v${finalAttrs.version}/open-orpheus_${finalAttrs.version}-1_amd64.deb";
    hash = "sha256-O8SuFRkLRi1WhDmOwtgJrxgMMjdJHzBphjMY8OGXcIk=";
  };

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
    gsettings-desktop-schemas
    gtk3
    libdrm
    libgbm
    libglvnd
    libnotify
    libpulseaudio
    libuuid
    libx11
    libxcb
    libxcomposite
    libxcursor
    libxdamage
    libxext
    libxfixes
    libxi
    libxkbcommon
    libxrandr
    libxrender
    mesa
    nspr
    nss
    pango
    systemd
    zlib
    stdenv.cc.cc.lib
  ];

  unpackPhase = ''
    runHook preUnpack
    # 上游 deb 里 chrome-sandbox 带 setuid 位（4755），dpkg-deb -x 会尝试还原它
    # 而在构建沙箱里 chmod 4755 必然失败；--fsys-tarfile 交给 tar 解包时，非 root
    # 默认不还原 setuid 位（store 里本来也不允许 setuid）。
    dpkg-deb --fsys-tarfile "$src" | tar -x --no-same-owner
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib $out/bin $out/share
    cp -r usr/lib/open-orpheus $out/lib/open-orpheus
    cp -r usr/share/applications usr/share/icons $out/share/

    # 上游 deb 里的 /usr/bin/open-orpheus 只是指向 lib 下 Electron 主程序的软链。
    # 主程序必须留在 lib/open-orpheus 里（它按自身路径找 ../resources/app.asar），
    # 这里改成 wrapper：
    # - --disable-setuid-sandbox：chrome-sandbox 在 Nix store 里拿不到 setuid 位，
    #   不显式关闭会让 Chromium 以「SUID helper 配置错误」直接退出；关掉后仍走
    #   非特权 user namespace 沙箱（NixOS 已启用），比 --no-sandbox 安全。
    # - ELECTRON_OZONE_PLATFORM_HINT=auto：Wayland 会话走原生 Wayland（上游主打的
    #   特性），否则回退 X11。
    # - XDG_DATA_DIRS 指向 gsettings-desktop-schemas：GTK 找不到 schema 时会报
    #   g_settings_schema_source_lookup: assertion 'source != NULL' failed。
    # - LD_LIBRARY_PATH：libglvnd/libpulseaudio 是 dlopen 加载的（不在 NEEDED 里，
    #   autoPatchelf 不会写进 RPATH），必须显式加进来才能拿到 GL 与 PulseAudio；
    #   /run/opengl-driver/lib 是 NVIDIA 驱动的 libGL/libEGL 与 dri 驱动所在处。
    # - xdg-utils：应用内打开外部链接走系统浏览器。
    makeWrapper $out/lib/open-orpheus/open-orpheus $out/bin/open-orpheus \
      --add-flags "--disable-setuid-sandbox" \
      --set ELECTRON_OZONE_PLATFORM_HINT "auto" \
      --prefix XDG_DATA_DIRS : "${gsettings-desktop-schemas}/share/gsettings-schemas/${gsettings-desktop-schemas.name}" \
      --prefix LD_LIBRARY_PATH : "$out/lib/open-orpheus" \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ libglvnd libpulseaudio ]}" \
      --prefix LD_LIBRARY_PATH : "/run/opengl-driver/lib" \
      --set LIBGL_DRIVERS_PATH "/run/opengl-driver/lib/dri" \
      --prefix PATH : "${lib.makeBinPath [ xdg-utils ]}"

    runHook postInstall
  '';

  autoPatchelfDirectoriesList = [ "$out/lib/open-orpheus" ];

  meta = with lib; {
    description = "Open-source implementation of Netease Cloud Music's Orpheus browser host";
    longDescription = ''
      Runs the official Netease Cloud Music client's web resources (the Orpheus
      browser host) on Linux. It ships no Netease-owned assets: the required
      `package`/`resource` files are downloaded from Netease's CDN on first start
      into the user data directory.
    '';
    homepage = "https://github.com/YUCLing/open-orpheus";
    license = licenses.mit;
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    maintainers = [ ];
    mainProgram = "open-orpheus";
    platforms = [ "x86_64-linux" ];
  };
})
