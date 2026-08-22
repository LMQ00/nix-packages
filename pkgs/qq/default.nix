{ lib
, stdenv
, fetchurl
, dpkg
, autoPatchelfHook
, makeShellWrapper
, wrapGAppsHook3
, writeShellScript
, alsa-lib
, at-spi2-core
, cups
, glib
, gtk3
, libdrm
, libpulseaudio
, libgcrypt
, libkrb5
, libgbm
, nss
, libxdamage
, systemd
, libssh2
, libayatana-appindicator
, libnotify
, libGL
, libuuid
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "qq";
  version = "3.2.32";

  src = fetchurl {
    url = "https://qqdl.gtimg.cn/qqfile/QQNT/9.9.33/release/3f89efc5/QQ_${finalAttrs.version}_260812_amd64_01.deb";
    hash = "sha256-0IXdiTlyJQYeufGUMI9ogSmBjtRFd36XpKChbhPXsOg=";
  };

  # 禁用 QQ 内置自动更新
  # QQ 会通过 versions/config.json 检查并自动更新，把 baseVersion/curVersion
  # 固定为当前安装版本并设为只读，防止自动更新破坏 Nix 包
  versionConfigScript = writeShellScript "qq-version-config.sh" ''
    set -e

    if [[ -z "$INTERNAL_VERSION" ]]; then
      echo "INTERNAL_VERSION is not set, skipping version config management"
      exit 0
    fi

    CONFIG_PATH="$HOME/.config/QQ/versions/config.json"
    CONFIG_DIR="$(dirname "$CONFIG_PATH")"

    if [[ ! -f "$CONFIG_PATH" ]]; then
      if [[ ! -d "$CONFIG_DIR" ]]; then
        echo "Creating QQ version config directory at $CONFIG_DIR"
        mkdir -p "$CONFIG_DIR"
      fi
    else
      baseVersion=$(sed -n 's/.*"baseVersion"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$CONFIG_PATH")
      currentVersion=$(sed -n 's/.*"curVersion"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$CONFIG_PATH")

      if [[ "$baseVersion" == "$INTERNAL_VERSION" && "$currentVersion" == "$INTERNAL_VERSION" ]]; then
        echo "Version config file already up to date"

        if [[ -w "$CONFIG_PATH" ]]; then
          echo "Making existing version config file read-only"
          chmod u-w "$CONFIG_PATH"
        fi

        exit 0
      fi

      if [[ ! -w "$CONFIG_PATH" ]]; then
        echo "Making existing version config file writable temporarily"
        chmod u+w "$CONFIG_PATH"
      fi
    fi

    cat > "$CONFIG_PATH" << EOF
    {
      "_comment": "This file is managed by the qq-version-config.sh to disable auto updates, do not edit it manually.",
      "baseVersion": "$INTERNAL_VERSION",
      "curVersion": "$INTERNAL_VERSION",
      "buildId": "''${INTERNAL_VERSION##*-}"
    }
    EOF

    chmod u-w "$CONFIG_PATH"
  '';

  nativeBuildInputs = [
    autoPatchelfHook
    makeShellWrapper
    wrapGAppsHook3
    dpkg
  ];

  buildInputs = [
    alsa-lib
    at-spi2-core
    cups
    glib
    gtk3
    libdrm
    libpulseaudio
    libgcrypt
    libkrb5
    libgbm
    nss
    libxdamage
  ];

  dontWrapGApps = true;

  runtimeDependencies = map lib.getLib [
    systemd
    libkrb5
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    cp -r opt $out/opt
    cp -r usr/share $out/share
    substituteInPlace $out/share/applications/qq.desktop \
      --replace-fail "/opt/QQ/qq" "$out/bin/qq" \
      --replace-fail "/usr/share" "$out/share"
    makeShellWrapper $out/opt/QQ/qq $out/bin/qq \
      --prefix XDG_DATA_DIRS : "$GSETTINGS_SCHEMAS_PATH" \
      --prefix LD_PRELOAD : "${lib.makeLibraryPath [ libssh2 ]}/libssh2.so.1" \
      --prefix LD_LIBRARY_PATH : "${
        lib.makeLibraryPath [
          libGL
          libuuid
        ]
      }" \
      --add-flags "''${NIXOS_OZONE_WL:+''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true --wayland-text-input-version=3}}" \
      "''${gappsWrapperArgs[@]}" \
      --set INTERNAL_VERSION "$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' $out/opt/QQ/resources/app/package.json)" \
      --run '${finalAttrs.versionConfigScript} || true'

    # QQ 自带的旧 libssh2 会导致运行时崩溃，删除后用系统的（见 LD_PRELOAD）
    rm -r $out/opt/QQ/resources/app/libssh2.so.1

    # 修复缺失的托盘/通知库
    ln -s ${libayatana-appindicator}/lib/libayatana-appindicator3.so \
      $out/opt/QQ/libappindicator3.so

    ln -s ${libnotify}/lib/libnotify.so \
      $out/opt/QQ/libnotify.so

    runHook postInstall
  '';

  meta = with lib; {
    description = "Tencent QQ messaging client for Linux";
    homepage = "https://im.qq.com/index/";
    license = licenses.unfree;
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    maintainers = [ ];
    mainProgram = "qq";
  };
})
