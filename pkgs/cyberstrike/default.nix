{ lib
, stdenv
, fetchurl
, unzip
, autoPatchelfHook
, makeWrapper
, ripgrep
}:

let
  version = "1.1.16";

  srcs = {
    x86_64-linux = fetchurl {
      url = "https://github.com/CyberStrikeus/CyberStrike/releases/download/v${version}/cyberstrike-linux-x64.tar.gz";
      hash = "sha256-VKbaICIbSGHVLVbsedWYBB4vCTuzg8cQNds0rWwPZRs=";
    };
    aarch64-linux = fetchurl {
      url = "https://github.com/CyberStrikeus/CyberStrike/releases/download/v${version}/cyberstrike-linux-arm64.tar.gz";
      hash = "sha256-LnAOZc1TBDGnSAueUAWbcO5KY1zwMl/+D0rnXMud8fk=";
    };
    x86_64-darwin = fetchurl {
      url = "https://github.com/CyberStrikeus/CyberStrike/releases/download/v${version}/cyberstrike-darwin-x64.zip";
      hash = "sha256-D9yfJkBCrzBKwW7HttF1XnoGC0z/EkyB4vFGegrd5ZA=";
    };
    aarch64-darwin = fetchurl {
      url = "https://github.com/CyberStrikeus/CyberStrike/releases/download/v${version}/cyberstrike-darwin-arm64.zip";
      hash = "sha256-hueFJLwf73B5RXTmR2d0AjN9kxhrrmwO++F1GaPLHiY=";
    };
  };

  src = srcs.${stdenv.hostPlatform.system};

  # hackbrowser 的 worker 脚本按 Global.Path.bin（~/.local/share/cyberstrike/bin）
  # 查找，store 内只读，故首次运行时由 wrapper 拷入用户数据目录。
  # playwright（含约 400MB Chromium）上游本来就在首次使用时自建到该目录。
  workerBootstrap = ''
    _cs_data="''${XDG_DATA_HOME:-$HOME/.local/share}/cyberstrike"
    if ! [ -e "$_cs_data/bin/hackbrowser-worker.js" ]; then
      mkdir -p "$_cs_data/bin"
      cp -f ${placeholder "out"}/share/cyberstrike/hackbrowser-worker.js "$_cs_data/bin/hackbrowser-worker.js"
    fi
    unset _cs_data
  '';

  meta = with lib; {
    description = "Open-source AI-powered offensive security agent for automated penetration testing";
    longDescription = ''
      CyberStrike turns an LLM subscription into an autonomous red team agent
      with specialized pentesting subagents, a large security skill library and
      built-in OWASP test cases.
    '';
    homepage = "https://cyberstrike.io/";
    license = licenses.agpl3Only;
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    maintainers = [ ];
    mainProgram = "cyberstrike";
    platforms = builtins.attrNames srcs;
  };
in
stdenv.mkDerivation {
  pname = "cyberstrike";
  inherit version src meta;

  nativeBuildInputs = [ makeWrapper unzip ]
    ++ lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];

  unpackPhase = ''
    runHook preUnpack
    mkdir -p cyberstrike-src
    ${if stdenv.hostPlatform.isDarwin then "unzip -q $src -d cyberstrike-src" else "tar -xzf $src -C cyberstrike-src"}
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/share/cyberstrike
    install -Dm755 cyberstrike-src/cyberstrike $out/share/cyberstrike/cyberstrike
    install -Dm644 cyberstrike-src/hackbrowser-worker.js $out/share/cyberstrike/hackbrowser-worker.js

    # ripgrep 是运行时的代码检索工具，喂进 PATH 可免去上游再联网下载到数据目录
    makeWrapper $out/share/cyberstrike/cyberstrike $out/bin/cyberstrike \
      --prefix PATH : ${lib.makeBinPath [ ripgrep ]} \
      --run ${lib.escapeShellArg workerBootstrap} \
      --set-default CYBERSTRIKE_DISABLE_AUTOUPDATE true

    runHook postInstall
  '';

  # 二进制由上游 CI 构建，Nix 侧不再跑 install check
  doInstallCheck = false;
}
