{ lib
, stdenv
, fetchurl
, appimageTools
, unzip
, makeWrapper
}:

let
  version = "0.1.1-preview.4";

  srcs = {
    x86_64-linux = fetchurl {
      url = "https://github.com/Candouber/Astudio/releases/download/v${version}/AStudio-${version}-linux-x86_64.AppImage";
      hash = "sha256:611c29f95a4943dc6523b2473d31631abb3b80ce8c6fc99e71c74a4594c4ce2d";
    };
    x86_64-darwin = fetchurl {
      url = "https://github.com/Candouber/Astudio/releases/download/v${version}/AStudio-${version}-mac-x64.zip";
      hash = "sha256:b99561d9082714b48164e69634e0ff337fe6129baef25008ff3b16f6a58ddee1";
    };
    aarch64-darwin = fetchurl {
      url = "https://github.com/Candouber/Astudio/releases/download/v${version}/AStudio-${version}-mac-arm64.zip";
      hash = "sha256:f932f56feec77a5324a3f1f2126ca9d1b564920289ecabccb7e9085b85038f1b";
    };
  };

  src = srcs.${stdenv.hostPlatform.system};

  pname = "astudio";

  meta = with lib; {
    description = "Local-first multi-agent collaborative task execution workbench";
    longDescription = ''
      AStudio decomposes complex user requests into routeable, approvable,
      executable, traceable, and reusable task pipelines. It features Agent Zero
      routing, Studio Leader planning, and Sub-agent ReAct execution.
    '';
    homepage = "https://github.com/Candouber/Astudio";
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    license = licenses.mit;
    platforms = [ "x86_64-linux" "x86_64-darwin" "aarch64-darwin" ];
    maintainers = [ ];
    mainProgram = "astudio";
  };
in
if stdenv.isLinux then
  # Linux: 使用 appimageTools.wrapType2 处理 AppImage
  # 运行时需要 FUSE 支持（NixOS: programs.fuse.enable = true）
  appimageTools.wrapType2 {
    inherit pname version src meta;
  }
else
  # macOS: 解压 zip 安装 .app bundle
  stdenv.mkDerivation {
    inherit pname version src meta;

    nativeBuildInputs = [
      unzip
      makeWrapper
    ];

    unpackPhase = ''
      runHook preUnpack
      mkdir -p source
      unzip -q "$src" -d source
      runHook postUnpack
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out/bin
      mkdir -p "$out/Applications"
      cp -r source/*.app "$out/Applications/AStudio.app"
      ln -sf "$out/Applications/AStudio.app/Contents/MacOS/AStudio" "$out/bin/astudio"

      runHook postInstall
    '';
  }
