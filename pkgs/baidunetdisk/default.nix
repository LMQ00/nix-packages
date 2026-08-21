{ lib
, stdenv
, fetchurl
, docker
, writeShellScript
}:

# 百度网盘 8.x（官方 deb + Ubuntu 容器）
#
# 为什么用容器：百度网盘 8.6.0 的官方二进制深度绑定 Ubuntu 运行时
# （deb 自带 Electron 22 prebuilt + 百度自研 C++ 库 libbrowserengine 依赖
# gtkmm2.4 等老 C++ 栈）。在 NixOS 上直接跑（patchelf + autoPatchelfHook）会
# 因 glibc/gcc 版本差异导致主进程确定性崩溃（SIGTRAP/int3，所有路径实测
# 均失败：electron 11 外部 asar、官方二进制、electron 22 prebuilt、
# electron 42 + N-API 模块替换）。容器提供官方 Ubuntu 运行时，100% 可用。
#
# 首次启动会拉取 ubuntu:24.04 镜像并安装依赖和 deb（约 3-5 分钟），
# 之后直接启动。容器持久化在 docker 中，数据（登录态、下载）保留。

let
  pname = "baidunetdisk";
  version = "8.7.0";
  containerName = "baidunetdisk";

  deb = fetchurl {
    url = "http://wppkg.baidupcs.com/issue/netdisk/Linuxguanjia/${version}/baidunetdisk_${version}_amd64.deb";
    sha256 = "ec71c2ad1151609fd0d8b86d95184c0b457d6db5aa18861e0b15fc23ccfe01f7";
  };

  startScript = writeShellScript "baidunetdisk" ''
    set -e

    CONTAINER="${containerName}"
    DEB="@DEB@"

    # 查找当前 XWayland 的 Xauthority 文件（KDE Wayland 生成在 /run/user/$UID/）
    find_xauth() {
      if [ -n "$XAUTHORITY" ] && [ -f "$XAUTHORITY" ]; then
        echo "$XAUTHORITY"
        return
      fi
      if [ -f "$HOME/.Xauthority" ]; then
        echo "$HOME/.Xauthority"
        return
      fi
      for f in /run/user/"$(id -u)"/xauth_*; do
        [ -f "$f" ] && echo "$f" && return
      done
    }

    XAUTH_FILE="$(find_xauth || true)"

    # 首次启动：创建容器并安装
    if ! docker inspect "$CONTAINER" > /dev/null 2>&1; then
      echo "首次启动：正在初始化百度网盘容器（拉取 ubuntu:24.04 并安装依赖，约 3-5 分钟）..."
      docker pull ubuntu:24.04

      XAUTH_ARGS=""
      if [ -n "$XAUTH_FILE" ]; then
        XAUTH_ARGS="-e XAUTHORITY=/tmp/xauth -v $XAUTH_FILE:/tmp/xauth:ro"
      fi

      docker run -d --name "$CONTAINER" \
        --network host \
        -e DISPLAY="''${DISPLAY:-:0}" \
        $XAUTH_ARGS \
        -v /tmp/.X11-unix:/tmp/.X11-unix \
        -v "$DEB:/tmp/baidunetdisk.deb:ro" \
        ubuntu:24.04 sleep infinity

      # Ubuntu 24.04 包名（t64 迁移），22.04 为 libasound2/libgtkmm-2.4-1v5
      docker exec "$CONTAINER" bash -c '
        set -e
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -qq
        apt-get install -y -qq \
          libnss3 libxss1 libgtk-3-0 libgbm1 libasound2t64 \
          libgtkmm-2.4-1t64 libnotify4 xdg-utils
        dpkg -i /tmp/baidunetdisk.deb
      '
    fi

    # 确保容器运行
    docker start "$CONTAINER" > /dev/null 2>&1 || true

    exec docker exec "$CONTAINER" /opt/baidunetdisk/baidunetdisk --no-sandbox "$@"
  '';
in
stdenv.mkDerivation {
  inherit pname version;

  nativeBuildInputs = [ docker ];

  dontUnpack = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin $out/share/applications
    substitute ${startScript} $out/bin/baidunetdisk \
      --replace "@DEB@" "${deb}"
    chmod +x $out/bin/baidunetdisk

    cat > $out/share/applications/baidunetdisk.desktop <<EOF
    [Desktop Entry]
    Name=百度网盘
    Name[en]=Baidu Netdisk
    Comment=Baidu Netdisk desktop client (Ubuntu container)
    Exec=$out/bin/baidunetdisk %U
    Terminal=false
    Type=Application
    Icon=baidunetdisk
    Categories=Network;
    StartupWMClass=baidunetdisk
    MimeType=x-scheme-handler/baiduyunguanjia;
    EOF
    runHook postInstall
  '';

  meta = with lib; {
    description = "Baidu Netdisk desktop client (official deb in Ubuntu container)";
    homepage = "https://pan.baidu.com/";
    license = licenses.unfree;
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    maintainers = [ ];
    mainProgram = "baidunetdisk";
  };
}
