{ lib
, buildDotnetModule
, dotnetCorePackages
, fetchFromGitHub
, makeDesktopItem
, copyDesktopItems
}:

buildDotnetModule rec {
  pname = "pcl-neo";
  version = "0.1.0-unstable-2026-06-07";

  src = fetchFromGitHub {
    owner = "PCL-Community";
    repo = "PCL.Neo";
    rev = "b7fc14da685b63fd6698df03386eb2af91f76ae8";
    hash = "sha256-tAlVANudcGbk/abU6bthLvRmE1xIiM/CSyAJg1KVh20=";
  };

  # 使用主项目的 .csproj 文件
  projectFile = "PCL.Neo/PCL.Neo.csproj";

  # NuGet 依赖文件（需要通过 fetch-deps 脚本生成）
  nugetDeps = ./deps.json;

  # 使用 .NET 10 SDK 和运行时
  dotnet-sdk = dotnetCorePackages.sdk_10_0;
  dotnet-runtime = dotnetCorePackages.runtime_10_0;

  # 指定要安装的可执行文件
  executables = [ "PCL.Neo" ];

  # 桌面文件
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

  # 自定义安装阶段，在 dotnet 安装之后添加图标
  postInstall = ''
    # 创建图标目录
    mkdir -p $out/share/icons/hicolor/scalable/apps

    # 安装 SVG 图标
    if [ -f "$src/Icon.svg" ]; then
      cp $src/Icon.svg $out/share/icons/hicolor/scalable/apps/pcl-neo.svg
    fi
  '';

  meta = with lib; {
    description = "A cross-platform Minecraft launcher built with Avalonia";
    homepage = "https://github.com/PCL-Community/PCL.Neo";
    license = licenses.mit;
    maintainers = [ ];
    platforms = [ "x86_64-linux" "aarch64-linux" ];
    mainProgram = "PCL.Neo";
  };
}
