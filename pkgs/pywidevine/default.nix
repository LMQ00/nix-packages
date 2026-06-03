{ lib
, python3Packages
, fetchPypi
, pymp4
}:

python3Packages.buildPythonPackage rec {
  pname = "pywidevine";
  version = "1.9.0";
  pyproject = true;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-Z0La9f15fFpIE+sTAO+zGB/83dDIxHjuKMfFNqoOUbI=";
  };

  # 使用 pyproject.toml 构建
  build-system = with python3Packages; [
    poetry-core
  ];

  # 放松依赖版本约束
  pythonRelaxDeps = [
    "protobuf"
  ];

  nativeBuildInputs = [
    python3Packages.pythonRelaxDepsHook
  ];

  # Python 依赖
  dependencies = with python3Packages; [
    protobuf
    pymp4
    pycryptodome
    click
    requests
    unidecode
    pyyaml
  ];

  # 禁用测试
  doCheck = false;

  meta = with lib; {
    description = "A tool for working with Widevine DRM";
    homepage = "https://github.com/pywidevine/pywidevine";
    license = licenses.unfree;  # 许可证未知
    maintainers = [ ];
  };
}
