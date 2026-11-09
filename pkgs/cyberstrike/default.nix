{ lib
, stdenv
, fetchurl
, unzip
, autoPatchelfHook
, makeWrapper
, ripgrep
}:

let
  version = "2.0.0";

  srcs = {
    x86_64-linux = fetchurl {
      url = "https://github.com/CyberStrikeus/CyberStrike/releases/download/v${version}/cyberstrike-linux-x64.tar.gz";
      hash = "sha256-aUQG8JUqkEOKokSrsIfcMk7xNcxHHFe7te8DVUPxH3U=";
    };
    aarch64-linux = fetchurl {
      url = "https://github.com/CyberStrikeus/CyberStrike/releases/download/v${version}/cyberstrike-linux-arm64.tar.gz";
      hash = "sha256-hDxvvljRZLGyMC7vj8dqFiLCENLRLWRw8TUTr2bdKSg=";
    };
    x86_64-darwin = fetchurl {
      url = "https://github.com/CyberStrikeus/CyberStrike/releases/download/v${version}/cyberstrike-darwin-x64.zip";
      hash = "sha256-YcChjeN7V4wuY0ESgU6Oz+sux1tBPsX1zeRMIXTwX38=";
    };
    aarch64-darwin = fetchurl {
      url = "https://github.com/CyberStrikeus/CyberStrike/releases/download/v${version}/cyberstrike-darwin-arm64.zip";
      hash = "sha256-2RhuIO9h/cfRN/3TJSzLQnYX6c9Zz8vAFwl7LlgVGEA=";
    };
  };

  src = srcs.${stdenv.hostPlatform.system};

  # v2.0.0 的 tar 顶层是 {cyberstrike, web/, extension/}：1.1.16 的 hackbrowser-worker.js
  # 已随 worker 重写消失，但新增的 web/（内置 Web UI）与 extension/（MV3 浏览器扩展）
  # 都要在运行时从磁盘读。两处查找逻辑都以「二进制自身所在目录」为锚点：
  #   web/       CYBERSTRIKE_WEB_DIR → cwd/packages/app/dist → new URL(import.meta.url)
  #              → dirname(process.execPath)/web → <data>/web
  #              bun 打包后 import.meta.url 落在 /$bunfs 内，第三条恒为空；
  #              实测 dirname(execPath)/web/index.html 命中后即作为 UI 根目录。
  #   extension/ import.meta.dir/../../extension（落在 $bunfs 内则改用
  #              dirname(execPath)/extension，再退 dirname(execPath)/../extension）
  # 所以 web/ 与 extension/ 跟二进制同目录安装即可，wrapper 不需要 --chdir —— 那反而会
  # 改掉 TUI 的默认项目目录。CYBERSTRIKE_WEB_DIR 只是把首选项显式钉在 store 路径上。
  uiDir = "${placeholder "out"}/share/cyberstrike";

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
    cp -r cyberstrike-src/web cyberstrike-src/extension $out/share/cyberstrike/

    # ripgrep 是运行时的代码检索工具：上游先查 PATH（Bun.which("rg")），查不到才联网
    # 下载到 ~/.local/share/cyberstrike/bin，喂进 PATH 即可免掉这次下载
    makeWrapper $out/share/cyberstrike/cyberstrike $out/bin/cyberstrike \
      --prefix PATH : ${lib.makeBinPath [ ripgrep ]} \
      --set-default CYBERSTRIKE_WEB_DIR ${uiDir}/web \
      --set-default CYBERSTRIKE_DISABLE_AUTOUPDATE true

    runHook postInstall
  '';

  # 二进制由上游 CI 构建，Nix 侧不再跑 install check
  doInstallCheck = false;
}
