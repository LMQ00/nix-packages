{ lib
, stdenv
, fetchFromGitHub
, nodejs
, pnpm
, makeWrapper
}:

let
  # 2.44.6 起上游把 shoutrrr-ts 以 GitHub tarball 形式依赖，但 lockfile 里该
  # 条目只有 tarball 没有 integrity，pnpm >= 10.34.1 会在抓取阶段直接以
  # ERR_PNPM_MISSING_TARBALL_INTEGRITY 中止（--trust-lockfile 只跳过 lockfile
  # 供应链校验，跳不过抓取阶段的断言）。故给该条目补上实测的 sha512：pnpm 会
  # 校验下载内容，比原来完全不校验更严格；内容本身仍由 pnpmDeps 的
  # fixed-output hash 兜底。上游修好 lockfile 后这段可以删掉。
  lockfileIntegrityFix = ''
    sed -i 's|resolution: {tarball: https://github.com/Delusions6515/shoutrrr-ts/releases/download/v0.2.0/shoutrrr-ts-0.2.0.tgz}|resolution: {integrity: sha512-K/Cj26Dbg1epa163VfprhsP50aFmGTi71ocI9ch0uSZFdUr+P11bgLGdk88bX2w/w/nlwm8jZJ5dCugfYhqDUw==, tarball: https://github.com/Delusions6515/shoutrrr-ts/releases/download/v0.2.0/shoutrrr-ts-0.2.0.tgz}|' pnpm-lock.yaml
  '';
in

stdenv.mkDerivation (finalAttrs: {
  pname = "sub-store";
  version = "2.44.6";

  src = fetchFromGitHub {
    owner = "sub-store-org";
    repo = "Sub-Store";
    rev = finalAttrs.version;
    hash = "sha256-fS1N6sHFp+t+fPrb8yyLZIVesIYEDxQlIa2Nw9F3Fbc=";
  };

  # Sub-Store 的 Node.js 项目在 backend 子目录中
  sourceRoot = "source/backend";

  nativeBuildInputs = [
    nodejs
    pnpm.configHook
    makeWrapper
  ];

  # 预取 pnpm 依赖（用于离线构建）
  # 首次构建时使用 lib.fakeHash，nix 会提示正确的 hash
  pnpmDeps = pnpm.fetchDeps {
    inherit (finalAttrs) pname version src;
    sourceRoot = "source/backend";
    hash = "sha256-KPH5h9ofuyu0PZlSSE0PjI/0yYFTKs72Q10h0y+KF74=";
    fetcherVersion = 4;
    prePnpmInstall = lockfileIntegrityFix;
  };

  # 同上：构建阶段的 pnpm install 也要读这份 lockfile，故同样先修一遍。
  postPatch = lockfileIntegrityFix;

  buildPhase = ''
    runHook preBuild
    pnpm bundle:esbuild
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    # 安装打包后的 JS 文件（使用 Node.js 版本的 bundle）
    mkdir -p $out/share/sub-store
    cp dist/sub-store.bundle.js $out/share/sub-store/

    # 创建可执行包装脚本
    mkdir -p $out/bin
    makeWrapper ${nodejs}/bin/node $out/bin/sub-store \
      --add-flags "$out/share/sub-store/sub-store.bundle.js"

    runHook postInstall
  '';

  # 测试需要网络访问，禁用
  doCheck = false;

  meta = with lib; {
    description = "Advanced Subscription Manager for QX, Loon, Surge, Stash and Shadowrocket";
    homepage = "https://github.com/sub-store-org/Sub-Store";
    license = licenses.gpl3Only;
    maintainers = [ ];
    mainProgram = "sub-store";
    platforms = platforms.all;
  };
})
