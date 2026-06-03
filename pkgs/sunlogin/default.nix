{ lib
, stdenv
, fetchurl
, dpkg
, autoPatchelfHook
, makeWrapper
, libappindicator-gtk3
, xorg
, libxcrypt
, gtk3
, glib
, libX11
, libXext
, libXrandr
, libXtst
, libXdamage
, libXcomposite
, libXi
, libXcursor
, libXrender
, libXfixes
, libXau
, libXdmcp
, libpthreadstubs
, libxcb
, xorgproto
, libdrm
, mesa
, libGL
, libglvnd
, openssl
, zlib
, libgcc
, nss
, nspr
, cups
, libgbm
, pango
, cairo
, gdk-pixbuf
, atk
, wayland
, libxkbcommon
, libsecret
, libnotify
, libsoup_2_4
, libxml2
, sqlite
, udev
, libpulseaudio
, alsa-lib
, libv4l
, libusb1
, libmtp
, libgudev
, libimobiledevice
, libplist
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

  buildInputs = [
    libappindicator-gtk3
    xorg.xhost
    libxcrypt
    gtk3
    glib
    libX11
    libXext
    libXrandr
    libXtst
    libXdamage
    libXcomposite
    libXi
    libXcursor
    libXrender
    libXfixes
    libXau
    libXdmcp
    libpthreadstubs
    libxcb
    xorgproto
    libdrm
    mesa
    libGL
    libglvnd
    openssl
    zlib
    libgcc
    nss
    nspr
    cups
    libgbm
    pango
    cairo
    gdk-pixbuf
    atk
    wayland
    libxkbcommon
    libsecret
    libnotify
    libsoup_2_4
    libxml2
    sqlite
    udev
    libpulseaudio
    alsa-lib
    libv4l
    libusb1
    libmtp
    libgudev
    libimobiledevice
    libplist
  ];

  unpackPhase = "dpkg-deb -x $src .";

  installPhase = ''
    mkdir -p $out
    cp -r opt/sunlogin $out/opt/
    cp -r usr/share $out/share

    # 创建 bin 目录并包装二进制文件
    mkdir -p $out/bin
    makeWrapper $out/opt/sunlogin/bin/runsunloginclient $out/bin/sunloginclient

    # 将桌面文件中的路径更新为 Nix 路径
    substituteInPlace $out/share/applications/runsunloginclient.desktop \
      --replace "/opt/sunlogin/bin/runsunloginclient" "$out/bin/sunloginclient"
  '';

  meta = with lib; {
    description = "Sunlogin remote desktop client";
    homepage = "https://sunlogin.oray.com/";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
    maintainers = [ ];
  };
}
