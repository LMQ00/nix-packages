{ lib
, stdenv
, fetchurl
, autoPatchelfHook
, dpkg
, makeWrapper
, webkitgtk_4_1
, gtk3
, libsoup_3
, libayatana-appindicator
, glib
, cairo
, gdk-pixbuf
, gst_all_1
, pango
, harfbuzz
, atk
, at-spi2-atk
, at-spi2-core
, libxkbcommon
, openssl
, libsecret
, libuuid
, zlib
, libx11
, libxcomposite
, libxcursor
, libxdamage
, libxext
, libxfixes
, libxi
, libxrandr
, libxrender
, libxtst
, libxcb
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "aurevoy";
  version = "0.6.10";

  src = fetchurl {
    url = "https://github.com/nullskymc/Aurevoy/releases/download/v${finalAttrs.version}/Aurevoy_${finalAttrs.version}_amd64.deb";
    hash = "sha256-fkfDS99m9wvSmA0ZHB/wQRcu3lH4DLyLTrQWyTrYkpI=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    dpkg
    makeWrapper
  ];

  buildInputs = [
    webkitgtk_4_1
    gtk3
    libsoup_3
    libayatana-appindicator
    glib
    cairo
    gdk-pixbuf
    gst_all_1.gst-plugins-base
    pango
    harfbuzz
    atk
    at-spi2-atk
    at-spi2-core
    libxkbcommon
    openssl
    libsecret
    libuuid
    zlib
    libx11
    libxcomposite
    libxcursor
    libxdamage
    libxext
    libxfixes
    libxi
    libxrandr
    libxrender
    libxtst
    libxcb
  ];

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb -x "$src" .
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out
    cp -r usr/* $out/

    mv $out/bin/desktop $out/bin/.aurevoy-wrapped
    makeWrapper $out/bin/.aurevoy-wrapped $out/bin/aurevoy \
      --prefix GST_PLUGIN_SYSTEM_PATH_1_0 : "${gst_all_1.gst-plugins-base}/lib/gstreamer-1.0" \
      --set WEBKIT_DISABLE_COMPOSITING_MODE 1

    substituteInPlace $out/share/applications/Aurevoy.desktop \
      --replace-fail "Exec=desktop" "Exec=aurevoy" \
      --replace-fail "Icon=desktop" "Icon=aurevoy"

    for icon in $out/share/icons/hicolor/*/apps/desktop.png; do
      mv "$icon" "$(dirname "$icon")/aurevoy.png"
    done

    runHook postInstall
  '';

  autoPatchelfDirectoriesList = [ "$out/bin" "$out/lib/Aurevoy" ];

  meta = with lib; {
    description = "Local desktop AI agent that plans and completes tasks on your machine";
    homepage = "https://github.com/nullskymc/Aurevoy";
    license = licenses.mit;
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    maintainers = [ ];
    mainProgram = "aurevoy";
    platforms = [ "x86_64-linux" ];
  };
})
