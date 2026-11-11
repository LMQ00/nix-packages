{ lib
, fetchurl
, appimageTools
, buildFHSEnv
, symlinkJoin
, writeShellScript
  # 安装器窗口（AppImage 自带的 Tk 9 + Xft）与游戏构建、游戏运行需要的库
, vulkan-loader
, libx11
, libxext
, libxcursor
, libxi
, libxfixes
, libxrandr
, libxscrnsaver
, libxtst
, libxrender
, libxft
, fontconfig
, freetype
, zlib
, alsa-lib
, libpulseaudio
, libxkbcommon
, wayland
, libdecor
, fribidi
, xdg-utils
  # SDL3 在 Linux 上经 libudev 枚举 hidraw 手柄，缺它 SDL3 会关掉 udev 集成
, udev
}:

let
  pname = "totk-recomp";
  version = "0.4.0";

  # 上游只发布两个资产：Windows 的 zip 与 Linux 的 x86_64 AppImage。本包取 Linux
  # 那一个。AppImage 内含一套完整的构建工具链（LLVM 23、CPython 3.14、Steam
  # Runtime 3 "sniper" sysroot、SDL3/libvpx/Opus），玩家在自己机器上把自己的
  # 游戏文件编译成本地可执行文件；它本身不含任何游戏数据。
  src = fetchurl {
    url = "https://github.com/valentderah/totk-pc-recomp/releases/download/v${version}/TotK-Setup-x86_64-${version}-linux.AppImage";
    hash = "sha256-DzMULZW8YWro/eiaol57HV0LvAAGcjsysdp6NzAgFhw=";
  };

  meta = with lib; {
    description = "Setup bundle that statically recompiles Tears of the Kingdom into a native x86-64 application";
    longDescription = ''
      TotK Recomp ships no game data. The `totk-recomp` program is the setup
      bundle: it turns the player's own legally dumped copy of the game (base
      plus one of updates 1.1.0, 1.2.1, 1.4.3) and that console's prod.keys into
      a native executable on the machine it runs on, using the LLVM toolchain,
      Python and the Steam Runtime 3 sysroot bundled inside. A first install
      peaks at about 36 GiB; the game then runs from that folder, outside the
      Nix store.

      `totk-recomp-game DIR` runs the game the setup built in DIR. It exists
      because that game is linked against a plain FHS layout: on NixOS it needs
      the Vulkan loader and several X/Wayland libraries that no Nix store path
      provides by default, so it starts in an FHS environment instead.

      The game needs Linux 6.7 or later (the write watch uses userfaultfd's
      asynchronous write protection; an older kernel warns and falls back to
      uploading whole pools), a Vulkan 1.3 device with
      VK_EXT_external_memory_host, and glibc 2.34 or later.
    '';
    homepage = "https://github.com/valentderah/totk-pc-recomp";
    license = licenses.mit;
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    maintainers = [ ];
    mainProgram = pname;
  };

  appimageContents = appimageTools.extract { inherit pname version src; };

  # 为什么要 FHS 而不是 patchelf：AppImage 里是 python-build-standalone、官方
  # LLVM 发行版和 Steam Runtime 的 sysroot，它们按 Ubuntu/Debian 的 FHS 布局写死
  # 了 /lib64/ld-linux-x86-64.so.2、/usr/lib 和 ldconfig 缓存。这个包是
  # binaryNativeCode，不做任何二进制改写，只提供它期望的根布局。
  #
  # 没用 appimageTools.wrapAppImage：它用 appimageTools 的默认目标集，会把 GTK4、
  # GStreamer、SDL2_mixer 这些整套拖进闭包（实测闭包 2.21 GiB vs 这里 1.44 GiB）。
  # 这里只要安装器窗口（Tk 9 + Xft）、Vulkan loader（check 步骤用 dlopen 探测 1.3
  # 设备）和游戏链接/运行期需要的 X11/Wayland/ALSA/pulse 库，外加 SDL3 用来枚举
  # 手柄的 libudev。两个入口共用这一组：setup 的 prepare 步骤会 subprocess 运行
  # 安装目录里的 totk，所以它也需要游戏那套库。
  basePkgs = _pkgs: [
    vulkan-loader
    libx11
    libxext
    libxcursor
    libxi
    libxfixes
    libxrandr
    libxscrnsaver
    libxtst
    libxrender
    libxft
    fontconfig
    freetype
    zlib
    alsa-lib
    libpulseaudio
    libxkbcommon
    wayland
    libdecor
    fribidi
    # SDL3 在 Linux 上经 libudev 枚举 hidraw 手柄，缺它 SDL3 打
    # "udev init failed, disabling udev integration" 并退化到轮询。两个入口都会
    # 初始化 SDL（setup 的 prepare 步骤会 subprocess 跑 totk），而 udev 的 store
    # 路径已随 libdecor/gtk3 进入闭包，加上它实测不涨体积。
    udev
  ];

  # xdg-utils 只被安装器的"打开文件夹"用（installer/gui.py 的 xdg-open），
  # 单独挂在 setup 上：它把 perl 和一堆 perl 模块拖进来，约 92 MiB。
  setupPkgs = pkgs: basePkgs pkgs ++ [ xdg-utils ];

  gamePkgs = basePkgs;

  setup = buildFHSEnv {
    # name 与 symlinkJoin 的同名会让 store 里出现两个 totk-recomp-0.4.0，
    # 加 -setup 后缀区分；bin 下的名字仍由 executableName 定成 totk-recomp。
    name = "${pname}-setup";
    executableName = pname;
    inherit meta;

    targetPkgs = setupPkgs;

    # AppRun 自己设置 PYTHONDONTWRITEBYTECODE / TCL_LIBRARY / TK_LIBRARY，并用
    # "$HERE/python/bin/python3 -m installer.gui" 启动。$HERE 在 /nix/store 里，
    # 只读，正好是 AppImage 预期的工作方式（原来挂在只读的 squashfs 上）。
    runScript = writeShellScript "${pname}-setup" ''
      exec ${appimageContents}/AppRun "$@"
    '';

    extraInstallCommands = ''
      mkdir -p $out/share/applications $out/share/icons/hicolor/256x256/apps
      cp ${appimageContents}/totk-setup.png $out/share/icons/hicolor/256x256/apps/${pname}.png
      # Exec 用 app 名而不是 store 路径：desktop 文件把命令交给 PATH（与
      # baidunetdisk / sunlogin 一致），避免把具体 store 路径写进桌面数据库。
      sed -e 's|^Exec=AppRun|Exec=${pname}|' \
          -e "s|^Icon=totk-setup|Icon=${pname}|" \
          ${appimageContents}/totk-setup.desktop > $out/share/applications/${pname}.desktop
    '';
  };

  # 安装出来的 totk 是普通 FHS 二进制：NEEDED 里只有 libc 和 libvulkan.so.1，SDL3
  # 被安装器拷到 totk 旁边（链接时写了 $ORIGIN rpath），但 Vulkan loader、以及
  # 运行时 dlopen 的 X11/Wayland/ALSA/pulse 都要由文件系统提供。NixOS 的 nix-ld
  # 默认库集不含这些，所以给游戏一个自己的 FHS 环境，按安装目录运行。
  game = buildFHSEnv {
    name = "${pname}-game";
    # mainProgram 是整个包的入口（totk-recomp 那个 setup），这里只复用其余元信息
    meta = lib.removeAttrs meta [ "mainProgram" ];

    targetPkgs = gamePkgs;

    runScript = writeShellScript "${pname}-game" ''
      usage() {
        echo "usage: ${pname}-game [--] <install folder> [game arguments...]" >&2
        echo "  <install folder> is the folder the setup built, holding totk and libSDL3.so.0" >&2
      }
      # -- 之后即使安装目录名以 - 开头也不会被当成选项
      if [ "''${1-}" = "--" ]; then shift; fi
      [ $# -lt 1 ] && { usage; exit 2; }
      dir="$1"
      shift
      if [ ! -f "$dir/totk" ] || [ ! -x "$dir/totk" ]; then
        echo "${pname}-game: no totk in $dir" >&2
        exit 2
      fi
      cd "$dir" || exit 2
      exec ./totk "$@"
    '';
  };
in
symlinkJoin {
  name = "${pname}-${version}";
  paths = [
    setup
    game
  ];
  inherit meta;
}
