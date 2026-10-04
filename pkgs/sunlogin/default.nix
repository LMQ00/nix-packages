{ lib
, stdenv
, fetchurl
, dpkg
, makeWrapper
, binutils
, buildFHSEnv
, libappindicator-gtk3
, xorg
, gtk3
, glib
, glib-networking
, nss
, nspr
, cups
, libdrm
, mesa
, libGL
, libglvnd
, openssl
, libxcrypt
, zlib
, pango
, cairo
, gdk-pixbuf
, atk
, wayland
, libxkbcommon
, libsecret
, libnotify
, udev
, util-linux
, coreutils
, procps
, dbus
, fontconfig
, freetype
, alsa-lib
, libpulseaudio
, libepoxy
, webkitgtk_4_1
}:

let
  # 上游已将向日葵 Linux 客户端改名为 AweSun
  version = "16.6.0.32198";

  src = fetchurl {
    url = "https://dw.oray.com/sl/linux/awesun_${version}_amd64.deb";
    hash = "sha256-dtLVNEE6WKi79cV3teYXjj6vimhTBMAnrwL6TpItVjk=";
  };

  # libcrypt.so.1 兼容包装库
  # 程序原本依赖 glibc 的 libcrypt.so.1（提供 crypt@GLIBC_2.2.5）
  # 现代 glibc 已移除 libcrypt，改用 libxcrypt（提供 libcrypt.so.2, XCRYPT_2.0）
  # 这个包装库转发调用到 libcrypt.so.2，并保持 GLIBC_2.2.5 版本标签
  libcrypt-compat = stdenv.mkDerivation {
    pname = "libcrypt-compat";
    inherit version;

    dontUnpack = true;

    buildPhase = ''
      cat > libcrypt_compat.c << 'CEOF'
      #define _GNU_SOURCE
      #include <dlfcn.h>

      typedef char *(*crypt_fn)(const char *, const char *);
      typedef char *(*crypt_r_fn)(const char *, const char *, void *);

      static void *handle = 0;

      static void init(void) {
          handle = dlopen("${lib.getLib libxcrypt}/lib/libcrypt.so.2", RTLD_LAZY);
      }

      char *crypt(const char *key, const char *salt) {
          if (!handle) init();
          crypt_fn fn = (crypt_fn)dlsym(handle, "crypt");
          return fn(key, salt);
      }

      char *crypt_r(const char *key, const char *salt, void *data) {
          if (!handle) init();
          crypt_r_fn fn = (crypt_r_fn)dlsym(handle, "crypt_r");
          return fn(key, salt, data);
      }
      CEOF

      cat > libcrypt_compat.map << 'MEOF'
      GLIBC_2.2.5 {
          global:
              crypt;
              crypt_r;
      };
      MEOF

      gcc -shared -fPIC -o libcrypt.so.1 libcrypt_compat.c \
          -Wl,--version-script=libcrypt_compat.map \
          -Wl,-soname,libcrypt.so.1 \
          -ldl
    '';

    installPhase = ''
      mkdir -p $out/lib
      cp libcrypt.so.1 $out/lib/
    '';

    nativeBuildInputs = [ stdenv.cc ];
  };

  # 校验二进制 .sign 段签名。算法与 CFileSigner::verify_ex 一致：
  # RSA_public_decrypt(PKCS1) 还原出 16 字节，再与 MD5(整个文件去掉 .sign 段) 比较。
  # awesun_daemon 与 awesun --mod=service 用它校验客户端（GUI 与 bin/awesun），
  # 任何字节改动都会让校验失败 → GUI 停在「正在连接服务...」
  # （日志 [rpc/TcpSocket] Verify client failed!）。
  # 公钥取自校验方（bin/awesun_daemon）内嵌的 PEM。
  # 注：bin/awesun_daemon 自身的 .sign 用的是另一把（未内嵌的）私钥对应的公钥，
  # 无法在此验签；它作为"校验方"，不在客户端校验链路上。
  verifySignature = ''
    verify_signature() {
      local f="$1" keyfile="$2" off size
      off=$(${binutils}/bin/objdump -h "$f" | awk '$2 == ".sign" { print $6; exit }')
      size=$(${binutils}/bin/objdump -h "$f" | awk '$2 == ".sign" { print $3; exit }')
      if [ -z "$off" ] || [ -z "$size" ]; then
        echo "ERROR: $f 缺少 .sign 段 —— 客户端校验必然失败" >&2
        return 1
      fi
      off=$((16#$off))
      size=$((16#$size))
      {
        head -c "$off" "$f"
        tail -c "+$((off + size + 1))" "$f"
      } | ${openssl}/bin/openssl dgst -md5 -binary > sig-md5.bin
      dd if="$f" bs=1 skip="$off" count="$size" of=sig.bin status=none
      ${binutils}/bin/strings -a "$keyfile" \
        | sed -n '/-----BEGIN PUBLIC KEY-----/,/-----END PUBLIC KEY-----/p' > sig-pub.pem
      ${openssl}/bin/openssl pkeyutl -verifyrecover -pubin -inkey sig-pub.pem \
        -in sig.bin 2> /dev/null | tail -c 16 > sig-recovered.bin
      if ! cmp -s sig-recovered.bin sig-md5.bin; then
        echo "ERROR: $f 的 .sign 签名校验失败 —— 二进制被改写了（patchelf/autoPatchelfHook/strip？）" >&2
        return 1
      fi
    }
  '';

  # 需要的库
  libs = [
    stdenv.cc.cc.lib
    libappindicator-gtk3
    xorg.libX11
    xorg.libXext
    xorg.libXScrnSaver
    xorg.libXtst
    xorg.libXdamage
    xorg.libXcomposite
    xorg.libXi
    xorg.libXcursor
    xorg.libXrender
    xorg.libXfixes
    xorg.libXrandr
    xorg.libXinerama
    xorg.libSM
    xorg.libICE
    xorg.libxcb
    xorg.xorgproto
    gtk3
    glib
    nss
    nspr
    cups
    libdrm
    mesa
    libGL
    libglvnd
    openssl
    libxcrypt
    zlib
    pango
    cairo
    gdk-pixbuf
    atk
    wayland
    libxkbcommon
    libsecret
    libnotify
    udev
    util-linux
    dbus
    fontconfig
    freetype
    alsa-lib
    libpulseaudio
    libepoxy
    # 登录/设备等页面是内嵌 WebKit 视图（libwebview_linux_plugin.so 运行期
    # dlopen libwebkit2gtk-4.1.so.0，回退 libwebkit2gtk-4.0.so.37）。
    # 缺 webkit 时页面转圈（日志 WEBKIT_LOAD_FAILED）；缺 glib-networking 的
    # GIO TLS 模块时页面白屏（页面内报 "TLS support is not available"），
    # 两者都要在，见启动脚本里的 GIO_EXTRA_MODULES。
    glib-networking
    webkitgtk_4_1
  ];

in
let
  # 原始 AweSun 包（未包装 FHS 环境）
  awesun-unwrapped = stdenv.mkDerivation rec {
    pname = "awesun-unwrapped";
    inherit version;

    inherit src;

    nativeBuildInputs = [
      dpkg
      makeWrapper
      openssl
      binutils
    ];

    # ── 禁止任何改写 deb 内二进制的 fixup ──────────────────────────────────
    # 三种都会破坏 .sign 签名（见 installPhase 注释）：
    #   autoPatchelfHook（改解释器/RPATH）→ dontAutoPatchelf
    #   patchELF（RPATH shrink）          → dontPatchELF
    #   strip                             → dontStrip
    dontAutoPatchelf = true;
    dontPatchELF = true;
    dontStrip = true;

    unpackPhase = "dpkg-deb -x $src .";

    installPhase = ''
      runHook preInstall

      ${verifySignature}

      mkdir -p $out/opt
      cp -r usr/local/awesun $out/opt/awesun

      # ── 禁止改写 deb 内二进制 ──────────────────────────────────────────────
      # awesun（GUI）与 bin/awesun（--mod=service）都带 .sign 段（RSA-1024 签名）。
      # awesun_daemon / awesun --mod=service 的 RPC 服务端用 CTcpSocketService::Verify
      # 校验客户端：readlink(/proc/<peer>/exe) 与自身 /proc/self/exe 不同时，就用
      # 内嵌公钥校验 .sign（RSA 还原 16 字节 vs MD5(文件去掉 .sign 段)）。
      # 实测：deb 原始文件的签名有效；只要 patchelf 一次（改解释器/RPATH）就失效。
      # 签名失效 → 客户端被 RST → GUI 永远停在「正在连接服务...」
      # （日志 [rpc/TcpSocket] Verify client failed!）。
      # 运行库一律由 FHS rootfs（/usr/lib64 含全部依赖，/lib64/ld-linux-x86-64.so.2
      # 即 deb 期望的解释器）与启动脚本的 LD_LIBRARY_PATH 提供，不改文件。
      verify_signature "$out/opt/awesun/awesun" "$out/opt/awesun/bin/awesun_daemon" || exit 1
      verify_signature "$out/opt/awesun/bin/awesun" "$out/opt/awesun/bin/awesun_daemon" || exit 1

      mkdir -p $out/bin
      mkdir -p $out/opt/awesun/log

      # GUI 入口
      ln -s $out/opt/awesun/awesun $out/bin/awesun

      # 更新桌面文件
      mkdir -p $out/share/applications
      cp usr/share/applications/awesun.desktop $out/share/applications/
      substituteInPlace $out/share/applications/awesun.desktop \
        --replace "/usr/local/awesun/awesun" "$out/opt/awesun/awesun" \
        --replace "/usr/local/awesun/awesun.png" "$out/opt/awesun/awesun.png"

      runHook postInstall
    '';

    meta = with lib; {
      description = "AweSun (formerly Sunlogin) remote desktop client (unwrapped)";
      homepage = "https://sunlogin.oray.com/";
      license = licenses.unfree;
      platforms = [ "x86_64-linux" ];
      maintainers = [ ];
    };
  };
in
# 使用 buildFHSEnv 创建 FHS 兼容环境
  # 解决程序硬编码 /usr/local/awesun 路径的问题
  # 程序内部构造 Flutter 资源路径和守护进程路径时直接使用 /usr/local/awesun
buildFHSEnv {
  pname = "sunlogin";
  inherit version;

  # 运行自定义启动脚本
  runScript = "/usr/local/sunlogin-start.sh";

  # 需要的包
  targetPkgs = pkgs: [
    awesun-unwrapped
    # 启动脚本需要 pgrep/pkill（FHS env 默认只有 coreutils/gawk 等）
    procps
  ] ++ libs;

  # 安装桌面文件和图标
  extraInstallCommands = ''
    mkdir -p $out/share/applications
    mkdir -p $out/share/icons/hicolor/256x256/apps
    cp ${awesun-unwrapped}/share/applications/awesun.desktop $out/share/applications/
    cp ${awesun-unwrapped}/opt/awesun/awesun.png $out/share/icons/hicolor/256x256/apps/
    substituteInPlace $out/share/applications/awesun.desktop \
      --replace "/usr/local/awesun/awesun" "sunlogin" \
      --replace "/usr/local/awesun/awesun.png" "awesun" \
      --replace "${awesun-unwrapped}/opt/awesun/awesun" "sunlogin" \
      --replace "${awesun-unwrapped}/opt/awesun/awesun.png" "awesun"

    # 安装 systemd unit（用户假设的缺失服务，上游 deb 自带 runawesun.service）。
    # 注意：必须写在顶层输出（extraInstallCommands 的 $out，含 bin/sunlogin wrapper），
    # 不能写在 rootfs（extraBuildCommands 的 $out 里 /lib 是悬空 symlink，且无 wrapper）。
    # FHS env 包装器不接受参数（container-init 忽略 argv），故 unit 用
    # SUNLOGIN_DAEMON 环境变量切换 start script 为前台 daemon 模式。
    mkdir -p $out/lib/systemd/system
    cat > $out/lib/systemd/system/runawesun.service <<UNIT
    [Unit]
    Description=AweSun (formerly Sunlogin) remote desktop daemon
    After=network.target

    [Service]
    Type=simple
    Environment=SUNLOGIN_DAEMON=1
    ExecStart=$out/bin/sunlogin
    # daemon 崩溃后 Restart=always 重启时，残留的 root 所有 socket 文件
    # 会让新 daemon bind EADDRINUSE 崩溃循环 —— 启动前清理（root 可删）
    ExecStartPre=/bin/sh -c '${coreutils}/bin/rm -f /tmp/*_16090 /tmp/*_16308'
    KillMode=control-group
    ExecStop=${util-linux}/bin/kill -TERM \$MAINPID
    # daemon 被强杀后 /tmp/*_16090 等 RPC socket 文件残留（root 所有），
    # 会阻塞后续用户 daemon bind —— 停止时一并清理
    # 注意：NixOS 无 /bin/kill、/bin/rm，须用 store 路径；systemd 不展开
    # glob（也不经 shell），故 ExecStopPost 走 /bin/sh -c。
    ExecStopPost=/bin/sh -c '${coreutils}/bin/rm -f /tmp/*_16090 /tmp/*_16308'
    Restart=always
    RestartSec=5

    [Install]
    WantedBy=multi-user.target
    UNIT
  '';

  # 在 FHS 环境中创建符号链接和启动脚本
  extraBuildCommands = ''
        mkdir -p $out/usr/local
        # 用真实目录而非 symlink 提供 /usr/local/awesun：
        # symlink 会被 execve 解析为 store 路径，导致 awesun_daemon 的
        # 客户端校验（readlink /proc/<pid>/exe 前缀匹配 /usr/local/awesun）失败，
        # GUI 连上 daemon 后被 RST（日志 Verify client failed），表现为登录/网络不可用。
        # bwrap 对 rootfs 中的目录使用 --ro-bind 挂载，进程 exe 路径保持 /usr/local/awesun/awesun。
        cp -r ${awesun-unwrapped}/opt/awesun $out/usr/local/awesun

        # 最终运行树（rootfs 副本）再验一次签名：将来若在 unwrapped 之外
        # （例如 buildFHSEnv 环节）对二进制做 strip/patchelf，构建即失败。
        ${verifySignature}
        verify_signature $out/usr/local/awesun/awesun $out/usr/local/awesun/bin/awesun_daemon || exit 1
        verify_signature $out/usr/local/awesun/bin/awesun $out/usr/local/awesun/bin/awesun_daemon || exit 1

        # 创建启动脚本（在 /usr/local 下，和 awesun 同级）
        # ── daemon 与 GUI 的沙箱关系（决定 RPC 客户端校验能否通过）────────────
        # awesun_daemon / awesun --mod=service 的 RPC 服务端会校验客户端：
        # 先 readlink(/proc/<peer pid>/exe)，与自己的 /proc/self/exe 比较，
        # 不同则用 .sign 段做签名校验。关键约束：
        #   * 跨 bwrap user namespace 的 readlink 会 EPERM（兄弟 userns 之间，
        #     实测返回 -1），daemon 直接判定 Verify client failed；
        #   * KDE 每次点图标启动都是一个新 transient unit（app-awesun@<hash>.service）
        #     = 新沙箱，因此上一次启动残留的用户 daemon 永远无法服务本次 GUI；
        #   * 只有 root（初始 userns，具备 CAP_SYS_PTRACE）才能 readlink 任意用户
        #     沙箱里的 GUI —— 这是上游 runawesun.service 由 root 常驻的原因。
        # 因此脚本策略：有 root daemon 就用它；否则杀掉所有残留用户 daemon，
        # 在本沙箱内起一个同沙箱 daemon，并让它在 GUI 退出时一起回收。
        # 注意：pgrep/pkill 由 targetPkgs 的 procps 提供（FHS env 默认不含）。
        cat > $out/usr/local/sunlogin-start.sh <<'SCRIPT'
    #!/bin/bash
    # 运行库解析：deb 内二进制带 .sign 自校验，禁止 patchelf（见 installPhase 注释），
    # 库一律经环境变量提供；FHS rootfs 的 /usr/lib64 已含全部依赖，这里作兜底。
    export LD_LIBRARY_PATH="/usr/local/awesun/lib:${lib.makeLibraryPath libs}:${libcrypt-compat}/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    # WebKit/libsoup 的 HTTPS 走 GIO 的 TLS 后端（glib-networking 的 libgiognutls.so）。
    # FHS 环境自带的 GIO_EXTRA_MODULES 只有 dconf，不含 TLS 模块 → 内嵌 WebKit 页面
    # 全部报 "TLS support is not available" 白屏（登录页、设备页等）。这里补上模块目录。
    export GIO_EXTRA_MODULES="${lib.getLib glib-networking}/lib/gio/modules''${GIO_EXTRA_MODULES:+:$GIO_EXTRA_MODULES}"
    mkdir -p /tmp/awesun-$USER 2>/dev/null

    daemon_pids() { pgrep -x awesun_daemon 2>/dev/null; }

    # 杀掉 daemon 及其 --mod=service 子进程，并清理残留 RPC socket
    # （kill -9 不会 unlink socket 文件，残留会让新 daemon bind EADDRINUSE）
    kill_daemon_tree() {
      local p c
      for p in $(daemon_pids); do
        for c in $(pgrep -P "$p" 2>/dev/null); do
          kill -9 "$c" 2>/dev/null || true
        done
        kill -9 "$p" 2>/dev/null || true
      done
      rm -f /tmp/*_16090 /tmp/*_16308 2>/dev/null || true
    }

    # 是否有 root 拥有的 daemon（runawesun.service 或手动 root 启动）
    has_root_daemon() {
      local p uid
      for p in $(daemon_pids); do
        uid=$(awk '/^Uid:/ { print $2 }' /proc/$p/status 2>/dev/null)
        [ "$uid" = 0 ] && return 0
      done
      return 1
    }

    # SUNLOGIN_DAEMON=1：systemd 服务前台托管 daemon（Type=simple）
    if [ "''${SUNLOGIN_DAEMON:-0}" = 1 ]; then
      rm -f /tmp/*_16090 /tmp/*_16308 2>/dev/null || true
      exec /usr/local/awesun/bin/awesun_daemon -m server -name awesun
    fi

    # root daemon 已就绪就直接用（只有它才能校验任意用户沙箱里的 GUI），绝不触碰
    if has_root_daemon; then
      exec /usr/local/awesun/awesun "$@"
    fi

    # 无 root daemon：清掉跨沙箱的残留用户 daemon，本沙箱自带一个
    kill_daemon_tree
    sleep 0.3

    did=""
    if ! pgrep -x awesun_daemon >/dev/null 2>&1; then
      /usr/local/awesun/bin/awesun_daemon -m server -name awesun &>/dev/null &
      did=$!
      sleep 1
    fi

    cleanup() {
      if [ -n "$did" ]; then
        pkill -9 -P "$did" 2>/dev/null || true
        kill -9 "$did" 2>/dev/null || true
      fi
      rm -f /tmp/*_16090 /tmp/*_16308 2>/dev/null || true
    }
    trap cleanup EXIT
    trap 'exit 143' TERM
    trap 'exit 130' INT

    # 不 exec：需要等 GUI 退出后回收本沙箱 daemon，
    # 同一个 systemd unit 的 cgroup 才能干净排空、不留残留进程
    /usr/local/awesun/awesun "$@"
    SCRIPT
        chmod +x $out/usr/local/sunlogin-start.sh
  '';

  meta = with lib; {
    description = "AweSun (formerly Sunlogin) remote desktop client";
    homepage = "https://sunlogin.oray.com/";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
    maintainers = [ ];
    mainProgram = "sunlogin";
  };
}
