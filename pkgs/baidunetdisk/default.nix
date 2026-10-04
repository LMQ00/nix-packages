# GTK2 C++ 栈的名字随 nixpkgs 版本变化：2026-08 起 nixpkgs 把 glibmm/cairomm/pangomm/
# libsigcxx 这些无 ABI 后缀的旧名改成 throw，只保留 glibmm_2_4 / cairomm_1_0 /
# pangomm_1_4 / libsigcxx_2_0；而本仓库 pin 仍是旧名。故每个库留两个候选形参
# （缺属性时 callPackage 不会传，未传的默认 null），运行时挑第一个可用的，见 pick。
{ lib
, stdenv
, fetchurl
, dpkg
, pkg-config
, buildFHSEnv
, writeShellScript
  # GTK2 C++ 栈：libbrowserengine.so（百度自有内嵌浏览器引擎）的运行期依赖
, gtk2
, atkmm
, glibmm ? null
, glibmm_2_4 ? null
, cairomm ? null
, cairomm_1_0 ? null
, pangomm ? null
, pangomm_1_4 ? null
, libsigcxx ? null
, libsigcxx_2_0 ? null
  # Electron 22 / 百度自有库依赖
, gtk3
, libgbm
, atk
, at-spi2-atk
, at-spi2-core
, nss
, nspr
, alsa-lib
, cups
, expat
, libdrm
, mesa
, libglvnd
, libxkbcommon
, libsecret
, libnotify
, libappindicator-gtk3
, libdbusmenu-gtk3
, dbus
, glib
, pango
, cairo
, gdk-pixbuf
, fontconfig
, freetype
, zlib
, libpulseaudio
, udev
, util-linux
, libuuid
, hicolor-icon-theme
, gsettings-desktop-schemas
, libx11
, libxcb
, libxcomposite
, libxcursor
, libxdamage
, libxext
, libxfixes
, libxi
, libxrandr
, libxrender
, libxscrnsaver
, libxt
, libxtst
}:

# 百度网盘 8.7.0（官方 deb 在 FHS 环境中原生运行）
#
# 为什么不 patchelf：deb 内的 Electron 22 prebuilt、百度自有 C++ 库
# （libbrowserengine/libkernel/netdisk_service 等）与自绘 UI 强绑定 Ubuntu 运行时。
# 历史尝试（autoPatchelfHook / patchELF / strip）都会让主进程确定性崩溃
# （SIGTRAP/int3）—— 与向日葵 .sign 被改写属同一类问题：官方二进制必须原样保留。
# buildFHSEnv 提供 deb 期望的 FHS 布局（/lib64/ld-linux-x86-64.so.2、/usr/lib 及
# ldconfig 缓存），二进制零改写即可运行，也不再需要 docker 容器。
#
# 运行库由 targetPkgs 合并进 rootfs 的 /usr/lib（ldconfig 建缓存），
# 因此不需要 LD_LIBRARY_PATH/RPATH 修补。
let
  # 候选依赖里 null（此 nixpkgs 无该属性）与旧名的 throw 都会被挡掉。
  # 注意 tryEval 只接得住 throw/assert，接不住 "expected a set but found null" 这类
  # 求值器类型错误，所以先用 isAttrs 短路。
  usable = x:
    let
      r = builtins.tryEval (builtins.isAttrs x && builtins.seq x.outPath true);
    in
    r.success && r.value;

  pick = what: candidates:
    let
      found = lib.findFirst usable null candidates;
    in
    if found == null then throw "baidunetdisk: nixpkgs 中没有可用的 ${what}" else found;

  # let 是递归的，绑定名不能与形参同名
  glibmmPkg = pick "glibmm（glibmm_2_4 / glibmm）" [ glibmm_2_4 glibmm ];
  cairommPkg = pick "cairomm（cairomm_1_0 / cairomm）" [ cairomm_1_0 cairomm ];
  pangommPkg = pick "pangomm（pangomm_1_4 / pangomm）" [ pangomm_1_4 pangomm ];
  libsigcxxPkg = pick "libsigcxx（libsigcxx_2_0 / libsigcxx）" [ libsigcxx_2_0 libsigcxx ];

  version = "8.7.0";

  src = fetchurl {
    url = "https://pkg-ant.baidu.com/issue/netdisk/LinuxGuanjia/${version}/baidunetdisk_${version}_amd64.deb";
    hash = "sha256-7HHCrRFRYJ/Q2LhtlRhMC0V9bbWqGIYeCxX8I8z+Afc=";
  };

  # ── gtkmm 2.24.5（内联）──────────────────────────────────────────────────
  # nixpkgs 于 2026-08-09 删除 gtkmm2（aliases.nix 改为 throw），但官方
  # libbrowserengine.so 的 NEEDED 含 libgtkmm-2.4.so.1 / libgdkmm-2.4.so.1，
  # 且 core.asar 在模块级 dlopen 该库 —— 缺它整个客户端无法启动。
  # 这里内联删除前的 nixpkgs 表达式（pkgs/by-name/gt/gtkmm2/package.nix），
  # 其余 GTK2 C++ 依赖现 nixpkgs 仍提供且 soname 与官方二进制一致：
  #   libglibmm-2.4.so.1 (glibmm) / libcairomm-1.0.so.1 (cairomm)
  #   libpangomm-1.4.so.1 (pangomm) / libatkmm-1.6.so.1 (atkmm)
  #   libsigc-2.0.so.0 (libsigcxx) / libgtk-x11-2.0.so.0 (gtk2)
  gtkmm2-legacy = stdenv.mkDerivation (finalAttrs: {
    pname = "gtkmm";
    version = "2.24.5";

    src = fetchurl {
      url = "mirror://gnome/sources/gtkmm/${lib.versions.majorMinor finalAttrs.version}/gtkmm-${finalAttrs.version}.tar.xz";
      sha256 = "sha256-BoClO3v5C05L9ETR2J5t9Bx3fgusyW6cCfxN0vX+a3I=";
    };

    outputs = [
      "out"
      "dev"
    ];

    nativeBuildInputs = [ pkg-config ];

    propagatedBuildInputs = [
      glibmmPkg
      gtk2
      atkmm
      cairommPkg
      pangommPkg
    ];

    # 上游 check 需要图形环境；此包仅作 libbrowserengine 的运行期依赖
    doCheck = false;

    enableParallelBuilding = true;

    meta = {
      description = "C++ interface to the GTK2 graphical user interface library (legacy, for libbrowserengine)";
      homepage = "https://gtkmm.org/";
      license = lib.licenses.lgpl2Plus;
      platforms = lib.platforms.unix;
    };
  });

  # ── 官方 deb 原样解包 ────────────────────────────────────────────────────
  baidunetdisk-unwrapped = stdenv.mkDerivation {
    pname = "baidunetdisk-unwrapped";
    inherit version src;

    nativeBuildInputs = [ dpkg ];

    # 禁止任何改写 deb 内二进制的 fixup（见文件头注释）：
    #   autoPatchelfHook（改解释器/RPATH）→ dontAutoPatchelf
    #   patchELF（RPATH shrink）          → dontPatchELF
    #   strip                             → dontStrip
    dontAutoPatchelf = true;
    dontPatchELF = true;
    dontStrip = true;

    # 不能用 dpkg-deb -x：deb 内 chrome-sandbox 带 setuid 位，
    # 解包时 chmod rwsr-xr-x 在构建沙箱中会 EPERM（open-orpheus 同款处理）
    unpackPhase = ''
      runHook preUnpack
      dpkg-deb --fsys-tarfile $src | tar -x --no-same-owner
      runHook postUnpack
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out/opt
      cp -r opt/baidunetdisk $out/opt/baidunetdisk
      chmod -R u+w $out/opt/baidunetdisk

      # 桌面项与图标：Exec 指向外层 FHS 包装器（宿主机看不到 /opt/baidunetdisk）
      mkdir -p $out/share/applications $out/share/icons/hicolor/scalable/apps
      cp $out/opt/baidunetdisk/baidunetdisk.svg \
        $out/share/icons/hicolor/scalable/apps/baidunetdisk.svg
      substituteInPlace $out/opt/baidunetdisk/baidunetdisk.desktop \
        --replace-fail "/opt/baidunetdisk/baidunetdisk" "baidunetdisk"
      cp $out/opt/baidunetdisk/baidunetdisk.desktop $out/share/applications/

      runHook postInstall
    '';

    meta = with lib; {
      description = "Baidu Netdisk desktop client (official deb payload, unmodified)";
      homepage = "https://pan.baidu.com/";
      license = licenses.unfree;
      sourceProvenance = with sourceTypes; [ binaryNativeCode ];
      platforms = [ "x86_64-linux" ];
      maintainers = [ ];
    };
  };

  # 运行库：全部合并进 FHS rootfs 的 /usr/lib，由 ldconfig 解析
  libs = [
    stdenv.cc.cc.lib
    gtkmm2-legacy
    gtk2
    gtk3
    glibmmPkg
    cairommPkg
    pangommPkg
    atkmm
    libsigcxxPkg
    atk
    at-spi2-atk
    at-spi2-core
    nss
    nspr
    alsa-lib
    cups
    expat
    libdrm
    # libgbm 是独立包（mesa/gbm.nix），显式列出保证 /usr/lib64/libgbm.so.1 一定在
    libgbm
    mesa
    libglvnd
    libxkbcommon
    libsecret
    libnotify
    libappindicator-gtk3
    libdbusmenu-gtk3
    dbus
    glib
    pango
    cairo
    gdk-pixbuf
    fontconfig
    freetype
    zlib
    libpulseaudio
    udev
    util-linux
    libuuid
    hicolor-icon-theme
    gsettings-desktop-schemas
    libx11
    libxcomposite
    libxcursor
    libxdamage
    libxext
    libxfixes
    libxi
    libxrandr
    libxrender
    libxscrnsaver
    # uiohook-napi 的原生模块（app.asar 内 build/Release/uiohook_napi.node）需要它
    libxt
    libxtst
    libxcb
  ];

  # 启动脚本：在 FHS 内经 ldconfig 解析依赖，二进制不改写
  startScript = writeShellScript "baidunetdisk-start" ''
    # Mesa 的 DRI 驱动（硬件加速）；FHS 已把 /run/opengl-driver/lib 写进 ld.so.conf
    export LIBGL_DRIVERS_PATH="''${LIBGL_DRIVERS_PATH:-/run/opengl-driver/lib/dri}"
    export LD_LIBRARY_PATH="/run/opengl-driver/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

    # store 中无法保存 setuid chrome-sandbox，必须禁用 Chromium 沙箱
    exec /opt/baidunetdisk/baidunetdisk --no-sandbox "$@"
  '';
in
buildFHSEnv {
  pname = "baidunetdisk";
  inherit version;

  runScript = startScript;

  targetPkgs = pkgs: [ baidunetdisk-unwrapped ] ++ libs;

  # 必须合并 targetPkgs 的依赖闭包：默认 includeClosures = false 时只合并各包自身
  # 输出，gtk2/gtk3/mesa 的传递依赖（libXt、libXmu、libICE… 与 libgbm 等）不会进
  # rootfs，表现为 Electron 的 .node 原生模块 dlopen 失败（node 只报第一个缺失的
  # soname）。打开后 rootfs 由闭包完整覆盖，等价于 Ubuntu 的 /usr/lib。
  includeClosures = true;

  # 不需要额外搬运 payload：FHS rootfs 的合并逻辑会把 targetPkgs 中 opt/** 的
  # 每个文件 symlink 到 /opt/baidunetdisk（见 nixpkgs 的 fhsenv rootfs-builder，
  # remap_multilib_path 对 opt/ 原样保留）。这些符号链接对百度二进制是安全的：
  # 主进程带 RPATH $ORIGIN，且 process.execPath 会解析成 store 内的 payload 目录，
  # 两种路径下 libffmpeg.so / netdisk_service / libbrowserengine.so / resources 都在。
  # 若将来发现程序把 /opt/baidunetdisk 当作可写目录或做路径前缀校验，再改为
  # extraBuildCommands 里的真实目录复制（sunlogin 的做法）。

  # 桌面项与图标装到包装器输出（宿主机可见）。
  # Exec 用 app 名而不是 store 路径：desktop 文件把命令交给 PATH（与 sunlogin 一致），
  # 避免把具体 store 路径写进桌面数据库。
  extraInstallCommands = ''
    mkdir -p $out/share/applications $out/share/icons/hicolor/scalable/apps
    cp ${baidunetdisk-unwrapped}/share/applications/baidunetdisk.desktop \
      $out/share/applications/baidunetdisk.desktop
    cp ${baidunetdisk-unwrapped}/share/icons/hicolor/scalable/apps/baidunetdisk.svg \
      $out/share/icons/hicolor/scalable/apps/baidunetdisk.svg
  '';

  meta = with lib; {
    description = "Baidu Netdisk desktop client (official deb, native FHS environment)";
    homepage = "https://pan.baidu.com/";
    license = licenses.unfree;
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    maintainers = [ ];
    mainProgram = "baidunetdisk";
  };
}
