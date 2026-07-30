{ lib
, stdenv
, fetchFromGitHub
, nodejs
, pnpm
, makeWrapper
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "sub-store";
  version = "2.36.26";

  src = fetchFromGitHub {
    owner = "sub-store-org";
    repo = "Sub-Store";
    rev = finalAttrs.version;
    hash = "sha256-3elHnLiPYvWin9e7PdyODc+UZB9EzYPvr/yz6CVTdPU=";
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
    hash = "sha256-c450ZhwUnrKpg7QOIMBlZMo+NWTqdhpb69eJGp0Gago=";
    fetcherVersion = 3;
  };

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
