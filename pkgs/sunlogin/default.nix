{ lib
, stdenv
, fetchurl
, dpkg
, autoPatchelfHook
, makeWrapper
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
, alsa-lib
, libpulseaudio
}:

stdenv.mkDerivation rec {
  pname = "sunlogin";
  version = "15.2.0.63064";

  src = fetchurl {
    url = "https://down.oray.com/sunlogin/linux/SunloginClient_${version}_amd64.deb";
    hash = "sha256-3a5dNk64tpQGoOGDSQRQ/S+R8HKXKzcI6VGOiFLLimM=";
  };

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    makeWrapper
  ];

  # 忽略缺失的依赖（运行时通过 nix-ld 或 FHS 解决）
  autoPatchelfIgnoreMissingDeps = [
    "libwidevinecdm.so"
    "libgconf-2.so.4"
    "libcrypt.so.1"
    "libsoup-2.4.so.1"
  ];

  buildInputs = [
    libappindicator-gtk3
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
    alsa-lib
    libpulseaudio
  ];

  unpackPhase = "dpkg-deb -x $src .";

  installPhase = ''
    mkdir -p $out/opt
    cp -r usr/local/sunlogin $out/opt/sunlogin

    mkdir -p $out/bin
    makeWrapper $out/opt/sunlogin/bin/sunloginclient $out/bin/sunloginclient \
      --prefix LD_LIBRARY_PATH : "$out/opt/sunlogin/lib"

    # 更新桌面文件
    mkdir -p $out/share/applications
    cp usr/share/applications/sunlogin.desktop $out/share/applications/
    substituteInPlace $out/share/applications/sunlogin.desktop \
      --replace "/usr/local/sunlogin/bin/sunloginclient" "$out/bin/sunloginclient" \
      --replace "/usr/local/sunlogin/res/icon/sunlogin_client.png" "$out/opt/sunlogin/res/icon/sunlogin_client.png"
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
