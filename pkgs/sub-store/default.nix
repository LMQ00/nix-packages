{ lib
, stdenv
, fetchFromGitHub
, nodejs
, pnpm
, makeWrapper
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "sub-store";
  version = "2.24.7";

  src = fetchFromGitHub {
    owner = "sub-store-org";
    repo = "Sub-Store";
    rev = finalAttrs.version;
    # 首次构建时使用 lib.fakeHash，nix 会提示正确的 hash
    # 或使用以下命令计算:
    #   nix-prefetch-url --unpack https://github.com/sub-store-org/Sub-Store/archive/refs/tags/2.24.7.tar.gz
    #   nix hash to-sri --type sha256 <hash>
    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
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
    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };

  buildPhase = ''
    runHook preBuild
    pnpm bundle:esbuild
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    # 安装打包后的 JS 文件
    mkdir -p $out/share/sub-store
    cp sub-store.min.js $out/share/sub-store/

    # 创建可执行包装脚本
    mkdir -p $out/bin
    makeWrapper ${nodejs}/bin/node $out/bin/sub-store \
      --add-flags "$out/share/sub-store/sub-store.min.js"

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
