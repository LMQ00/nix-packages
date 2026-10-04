{ lib
, buildNpmPackage
, fetchurl
, ffmpeg
, jq
, makeWrapper
, mpv
, nodejs
, runCommand
, versionCheckHook
}:

let
  version = "0.1.7";

  src = fetchurl {
    url = "https://registry.npmjs.org/@music163/ncm-cli/-/ncm-cli-${version}.tgz";
    hash = "sha256-2WefoqInGtAl8t1aERDR1eplycSza1rXCnVb51/gW7k=";
  };

  # npm tarball 不带 lockfile，需要自备一份（见同目录 package-lock.json）。
  # devDependencies（typescript/jest/esbuild…）只在打包 dist 时用到，发布包已含
  # 编译产物；删掉它们可避免 npm ci 拉入一堆与运行无关的依赖。
  srcWithLock = runCommand "ncm-cli-source" { nativeBuildInputs = [ jq ]; } ''
    mkdir -p $out
    tar -xzf ${src} -C $out --strip-components=1
    jq 'del(.devDependencies)' $out/package.json > $out/package.json.tmp
    mv $out/package.json.tmp $out/package.json
    cp ${./package-lock.json} $out/package-lock.json
  '';
in
buildNpmPackage {
  pname = "ncm-cli";
  inherit version;

  src = srcWithLock;

  npmDepsFetcherVersion = 2;
  npmDepsHash = "sha256-Up7oU4D4+E76xrEuA20O5x7K/dLjdbd2BX1bNDd2xiM=";

  # tarball 里已是编译好的 JS（dist/index.js，依赖不打包、由 node_modules 提供）
  dontNpmBuild = true;

  nativeBuildInputs = [ makeWrapper ];

  postInstall = ''
    # 上游 shebang 是 /usr/bin/env node；固定用包内 node，并把运行时外部程序
    # 放进 PATH：mpv 是本地播放后端，ffmpeg/ffprobe 供 fluent-ffmpeg 与
    # ffprobe-static 兜底（后者自带 linux/mac/win 三平台 ffprobe 二进制）。
    rm $out/bin/ncm-cli
    makeWrapper ${lib.getExe nodejs} $out/bin/ncm-cli \
      --add-flags "$out/lib/node_modules/@music163/ncm-cli/dist/index.js" \
      --prefix PATH : ${lib.makeBinPath [ ffmpeg mpv ]}
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];
  versionCheckProgramArg = "--version";

  meta = with lib; {
    description = "Netease Cloud Music CLI: search, playback, playlist management and TUI player";
    homepage = "https://www.npmjs.com/package/@music163/ncm-cli";
    license = licenses.mit;
    sourceProvenance = with sourceTypes; [
      binaryBytecode
      fromSource
    ];
    maintainers = [ ];
    mainProgram = "ncm-cli";
    # ffprobe-static 3.1.0 只带 linux/{ia32,x64} 与 darwin/{x64,arm64} 二进制，
    # 没有 linux/arm64，aarch64-linux 上取不到自带的 ffprobe，故不声明该平台。
    platforms = [
      "x86_64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
  };
}
