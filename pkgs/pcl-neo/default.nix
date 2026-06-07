{ lib
, buildDotnetModule
, dotnetCorePackages
, fetchFromGitHub
, makeDesktopItem
, copyDesktopItems
, skia
, libGL
, mesa
, fontconfig
, makeFontsConf
, runCommand
, liberation_ttf
, freefont_ttf
, noto-fonts-cjk-sans
}:

let
  fontsConf = runCommand "fonts.conf" { } ''
    substitute ${makeFontsConf {
      fontDirectories = [
        liberation_ttf
        freefont_ttf
        noto-fonts-cjk-sans
      ];
    }} $out \
      --replace-fail "/etc/" "${fontconfig.out}/etc/"
  '';
in
buildDotnetModule rec {
  pname = "pcl-neo";
  version = "0.1.0-unstable-2026-06-07";

  src = fetchFromGitHub {
    owner = "PCL-Community";
    repo = "PCL.Neo";
    rev = "b7fc14da685b63fd6698df03386eb2af91f76ae8";
    hash = "sha256-tAlVANudcGbk/abU6bthLvRmE1xIiM/CSyAJg1KVh20=";
  };

  projectFile = "PCL.Neo/PCL.Neo.csproj";
  nugetDeps = ./deps.json;

  dotnet-sdk = dotnetCorePackages.sdk_10_0;
  dotnet-runtime = dotnetCorePackages.runtime_10_0;

  executables = [ "PCL.Neo" ];

  # 禁用 PublishTrimmed，防止裁剪 Avalonia 嵌入资源（字体等）
  dotnetFlags = [
    "-p:PublishTrimmed=false"
  ];

  makeWrapperArgs = [
    "--set"
    "FONTCONFIG_FILE"
    "${fontsConf}"
    "--prefix"
    "LD_LIBRARY_PATH"
    ":"
    "${lib.makeLibraryPath [ fontconfig ]}"
  ];

  desktopItems = [
    (makeDesktopItem {
      name = "pcl-neo";
      desktopName = "PCL.Neo";
      comment = "A cross-platform Minecraft launcher";
      exec = "PCL.Neo %u";
      icon = "pcl-neo";
      terminal = false;
      type = "Application";
      categories = [ "Game" ];
    })
  ];

  nativeBuildInputs = [
    copyDesktopItems
  ];

  postInstall = ''
    mkdir -p $out/share/icons/hicolor/scalable/apps
    if [ -f "$src/Icon.svg" ]; then
      cp $src/Icon.svg $out/share/icons/hicolor/scalable/apps/pcl-neo.svg
    fi
  '';

  runtimeDependencies = [
    skia
    libGL
    mesa
    fontconfig
    liberation_ttf
    freefont_ttf
    noto-fonts-cjk-sans
  ];

  meta = with lib; {
    description = "A cross-platform Minecraft launcher built with Avalonia";
    homepage = "https://github.com/PCL-Community/PCL.Neo";
    license = licenses.mit;
    maintainers = [ ];
    platforms = [ "x86_64-linux" "aarch64-linux" ];
    mainProgram = "PCL.Neo";
  };
}