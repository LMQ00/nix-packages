{ lib
, bashInteractive
, buildNpmPackage
, fetchurl
, jq
, makeWrapper
, nodejs
, runCommand
, versionCheckHook
}:

let
  version = "0.2.0-rc.2";

  src = fetchurl {
    url = "https://registry.npmjs.org/@deepseek-ai/dsh/-/dsh-${version}.tgz";
    hash = "sha256-vSeEfERc1opWWsH5HAa7vMdjnvkwcfZ4u1nF66/ziFk=";
  };

  # npm tarball 不带 lockfile，需要自备一份（见同目录 package-lock.json）。
  # devDependencies 指向未发布的 @deepseek-ai 包（registry 返回 E404），
  # 因此 lockfile 生成时同样用 --omit=dev，并把 package.json 里的 devDependencies 删掉。
  srcWithLock = runCommand "dsh-source" { nativeBuildInputs = [ jq ]; } ''
    mkdir -p $out
    tar -xzf ${src} -C $out --strip-components=1
    jq 'del(.devDependencies)' $out/package.json > $out/package.json.tmp
    mv $out/package.json.tmp $out/package.json
    cp ${./package-lock.json} $out/package-lock.json
  '';
in
buildNpmPackage {
  pname = "dsh";
  inherit version;

  src = srcWithLock;

  npmDepsFetcherVersion = 2;
  npmDepsHash = "sha256-S5kMHGouilUPjuvT2uI3Qi03Xnr3HlKpZxqGHYwIfMI=";

  # tarball 里已是编译好的 JS（lib/*.js），无需再跑构建
  dontNpmBuild = true;

  nativeBuildInputs = [ makeWrapper ];

  postInstall = ''
    # /bin/bash does not exist on NixOS
    substituteInPlace \
      $out/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai/dsh-terminal-bash/lib/index.js \
      --replace-fail '"/bin/bash"' '"${lib.getExe bashInteractive}"'

    # dsh 启动时用 node-addon-require-builtin 反汇编 Node 二进制来取内部模块。
    # nixpkgs 默认加固项 zerocallusedregs（gcc -fzero-call-used-regs=used-gpr）
    # 会在 node::PrincipalRealm::builtin_module_require() 的 ret 前插入
    # `xor %edi,%edi`，addon 的模式匹配失败并报 Unsupported/no-getter，
    # dsh 随即中止启动（官方 Node 发行版没有这条加固）。
    # 上游在存在 --expose-internals 时本来就优先走普通 require（见
    # cordis-plugin-loader），这里用同样方式绕开 addon；wrapper 始终带该参数。
    # https://github.com/NixOS/nixpkgs/issues/565667
    for f in \
      $out/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai/dsh-app-boot/lib/index.js \
      $out/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai/dsh-app-boot/lib/worker/profile-resolution-bootstrap.js
    do
      substituteInPlace "$f" \
        --replace-fail \
          'createRequire(import.meta.url)("node-addon-require-builtin")' \
          '{ requireBuiltin: createRequire(import.meta.url) }'
    done

    rm $out/bin/dsh
    makeWrapper ${lib.getExe nodejs} $out/bin/dsh \
      --argv0 dsh \
      --add-flags "--expose-internals" \
      --add-flags "$out/lib/node_modules/@deepseek-ai/dsh/lib/bin.js"
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];
  versionCheckProgramArg = "--version";

  meta = with lib; {
    description = "Open-source agent harness developed by DeepSeek AI";
    homepage = "https://github.com/deepseek-ai/deepseek-harness";
    changelog = "https://github.com/deepseek-ai/deepseek-harness/releases";
    license = licenses.mit;
    sourceProvenance = with sourceTypes; [
      binaryBytecode
      fromSource
    ];
    maintainers = [ ];
    mainProgram = "dsh";
    platforms = platforms.all;
  };
}
