{ lib
, python3Packages
, fetchPypi
, construct
}:

python3Packages.buildPythonPackage rec {
  pname = "pymp4";
  version = "1.4.0";
  pyproject = true;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-vJ53cyqKFD00w4qoYqVBgHFiRpOOS/PgdYXRklK3e7U=";
  };

  # 使用 pyproject.toml 构建
  build-system = with python3Packages; [
    poetry-core
  ];

  # 放松依赖版本约束
  pythonRelaxDeps = [
    "construct"
  ];

  nativeBuildInputs = [
    python3Packages.pythonRelaxDepsHook
  ];

  # Python 依赖
  dependencies = [
    construct
  ];

  # 禁用测试
  doCheck = false;

  meta = with lib; {
    description = "A pure python MP4 parser";
    homepage = "https://github.com/beardypig/pymp4";
    license = licenses.mit;
    maintainers = [ ];
  };
}
