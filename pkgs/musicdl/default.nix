{ lib
, python3Packages
, fetchFromGitHub
, ffmpeg
, nodejs
, nix-update-script
, pywidevine
}:

python3Packages.buildPythonApplication rec {
  pname = "musicdl";
  version = "2.14.2";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "CharlesPikachu";
    repo = "musicdl";
    rev = "e204b2e2c3592d577b8e8443a407a2819dc07882"; # master branch (2026-11-19)
    hash = "sha256-kGhkdixeksDESTuMl1OiyVQJ6pg76Oo1ZC19oIs1ljc=";
  };

  # 使用 pyproject.toml 构建
  build-system = with python3Packages; [
    setuptools
    wheel
  ];

  # 放松依赖版本约束
  pythonRelaxDeps = [
    "json-repair"
    "orjson"
    "cryptography"
    "platformdirs"
    "puremagic"
    "rich"
  ];

  # 移除缺失的依赖
  pythonRemoveDeps = [
    "nodejs-wheel"
  ];

  nativeBuildInputs = [
    python3Packages.pythonRelaxDepsHook
  ];

  # Python 依赖
  dependencies = with python3Packages; [
    click
    json-repair
    prettytable
    pycryptodomex
    pycryptodome
    orjson
    requests
    cryptography
    fake-useragent
    pathvalidate
    rich
    emoji
    bleach
    beautifulsoup4
    aigpy
    av
    tabulate
    mutagen
    ytmusicapi
    m3u8
    tinytag
    curl-cffi
    platformdirs
    lxml
    prompt-toolkit
    brotli
    filetype
    puremagic
    websocket-client
    pywidevine
  ];

  # 系统依赖
  buildInputs = [
    ffmpeg
    nodejs
  ];

  # 将 FFmpeg 和 Node.js 添加到 PATH
  postFixup = ''
    wrapProgram $out/bin/musicdl \
      --prefix PATH : ${lib.makeBinPath [ ffmpeg nodejs ]}
  '';

  # 禁用测试（如果测试需要网络或其他依赖）
  doCheck = false;

  meta = with lib; {
    description = "A tool for downloading music from various platforms";
    homepage = "https://github.com/CharlesPikachu/musicdl";
    license = licenses.unfree; # PolyForm-Noncommercial-1.0.0 (not in nixpkgs)
    maintainers = [ ];
    mainProgram = "musicdl";
  };
}
