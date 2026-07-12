{ lib
, stdenv
, fetchurl
, makeWrapper
, pcre2
}:

let
  version = "16.4.6";

  srcs = {
    x86_64-linux = fetchurl {
      url = "https://github.com/can1357/oh-my-pi/releases/download/v${version}/omp-linux-x64";
      hash = "sha256-lDfPU9nZWRhs93KVwmUGyxAcaDW1BuKAT5UfQcZ0SmE=";
    };
    aarch64-linux = fetchurl {
      url = "https://github.com/can1357/oh-my-pi/releases/download/v${version}/omp-linux-arm64";
      hash = "sha256-rrlR+GCQT9fTw3Rpi4c8JzN5Y1lor/MtCw4AYBqikBw=";
    };
    x86_64-darwin = fetchurl {
      url = "https://github.com/can1357/oh-my-pi/releases/download/v${version}/omp-darwin-x64";
      hash = "sha256-JHWt50flnOHVkSX7u6fE2+b4F/1tniozqgqbVrgQ3vQ=";
    };
    aarch64-darwin = fetchurl {
      url = "https://github.com/can1357/oh-my-pi/releases/download/v${version}/omp-darwin-arm64";
      hash = "sha256-g+rEFTyLwOkwV4s5R9aG6ulA9bx4Ta5KUTlSiqPPTpI=";
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
