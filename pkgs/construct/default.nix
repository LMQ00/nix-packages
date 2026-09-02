{ lib
, python3Packages
, fetchPypi
}:

python3Packages.buildPythonPackage rec {
  pname = "construct";
  # 2.10.x 将 Const 构造器改为 (value, subcon)，与 pywidevine 1.9.0 的
  # Const(Int8ub, 2) 旧签名调用不兼容（TypeError: subcon should be a Construct field），
  # 上游 pywidevine 仓库已下架无修复，保持 2.8.8 可用版本
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
