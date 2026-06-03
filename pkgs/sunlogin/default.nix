{ lib
, stdenv
, fetchurl
, dpkg
, autoPatchelfHook
, makeWrapper
, libappindicator-gtk3
, xhost
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
    xhost
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
    # 复制整个解压后的目录
    cp -r usr/local/sunlogin $out/opt/sunlogin
    cp -r usr/share $out/share

    # 创建 bin 目录并包装二进制文件
    mkdir -p $out/bin
    makeWrapper $out/opt/sunlogin/bin/sunloginclient $out/bin/sunloginclient

    # 更新桌面文件中的路径
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
  };
}
