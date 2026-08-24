{ lib
, stdenv
, fetchurl
, makeWrapper
, pcre2
}:

let
  version = "18.0.4";

  srcs = {
    x86_64-linux = fetchurl {
      url = "https://github.com/can1357/oh-my-pi/releases/download/v${version}/omp-linux-x64";
      hash = "sha256-lOxC0X1xl1o4HiAzW7PABaf9fuwZsxk1jfbSLyjhazc=";
    };
    aarch64-linux = fetchurl {
      url = "https://github.com/can1357/oh-my-pi/releases/download/v${version}/omp-linux-arm64";
      hash = "sha256-8rfIoBloHt4xSsFlEAwcW1zUkAE5B1lI2oCcAEvsXOc=";
    };
    x86_64-darwin = fetchurl {
      url = "https://github.com/can1357/oh-my-pi/releases/download/v${version}/omp-darwin-x64";
      hash = "sha256-8hd1L19XnSsiCBhGL8UVrTM+ikEPG7/NYweCW3BSYPU=";
    };
    aarch64-darwin = fetchurl {
      url = "https://github.com/can1357/oh-my-pi/releases/download/v${version}/omp-darwin-arm64";
      hash = "sha256-1JMWOIe8+Pd7mZGrchn3dxK1sn3mVk969ygwZKyoSCQ=";
    };
  };

  src = srcs.${stdenv.hostPlatform.system};

  pname = "omp";

  dynamicLinker = "${stdenv.cc.bintools}/nix-support/dynamic-linker";

  meta = with lib; {
    description = "Terminal-first AI coding agent with IDE integration, subagents, and LSP/DAP support";
    longDescription = ''
      Omp (Oh My Pi) is a fork of Pi by Mario Zechner, rewritten as a
      coding-first surface. It features subagents, plan mode, LSP, DAP,
      hindsight memory, hashline edits, and time-traveling stream rules.
      Supports 40+ providers and 32 built-in tools.
    '';
    homepage = "https://omp.sh";
    license = licenses.mit;
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    maintainers = [ ];
    mainProgram = "omp";
    platforms = builtins.attrNames srcs;
  };
in
stdenv.mkDerivation {
  inherit pname version src meta;

  nativeBuildInputs = lib.optionals stdenv.isLinux [
    makeWrapper
  ];

  buildInputs = lib.optionals stdenv.isLinux [
    pcre2
  ];

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/share/omp

    cp $src $out/share/omp/omp
    chmod +x $out/share/omp/omp

  '' + lib.optionalString stdenv.isLinux ''
    # DO NOT use patchelf -- it corrupts the embedded bunfs data in
    # bun-compiled binaries. Instead, create a wrapper that invokes the
    # dynamic linker directly, and set LD_LIBRARY_PATH for native modules.
    makeWrapper \
      "$(cat ${dynamicLinker})" \
      $out/bin/omp \
      --add-flags "$out/share/omp/omp" \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ pcre2 ]}"
  '' + lib.optionalString stdenv.isDarwin ''
    ln -s $out/share/omp/omp $out/bin/omp
  '' + ''

    runHook postInstall
  '';
}
