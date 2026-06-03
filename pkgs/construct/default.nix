{ lib
, python3Packages
, fetchPypi
}:

python3Packages.buildPythonPackage rec {
  pname = "construct";
  version = "2.8.8";
  pyproject = true;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-G4S4FH9v0VvPZLc3w+isUQCBGtgMgwy0slRRQFEcQVc=";
  };

  # 使用 pyproject.toml 构建
  build-system = with python3Packages; [
    setuptools
    wheel
  ];

  # 禁用测试
  doCheck = false;

  meta = with lib; {
    description = "A powerful declarative parser (and builder) for binary data";
    homepage = "https://github.com/construct/construct";
    license = licenses.mit;
    maintainers = [ ];
  };
}
