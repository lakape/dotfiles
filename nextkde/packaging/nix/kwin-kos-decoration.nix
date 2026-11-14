{
  lib,
  stdenv,
  cmake,
  kdePackages,
  src,
}:

stdenv.mkDerivation {
  pname = "kwin-kos-decoration";
  version = lib.removeSuffix "\n" (builtins.readFile "${src}/VERSION");
  src = "${src}/kwin/kos-decoration";

  postPatch = ''
    mkdir -p ../kos-bridge
    cp -r ${src}/kwin/kos-bridge/windowappearance ../kos-bridge/
  '';

  nativeBuildInputs = [
    cmake
    kdePackages.extra-cmake-modules
  ];

  buildInputs = [
    kdePackages.kdecoration
    kdePackages.kcoreaddons
    kdePackages.qtbase
  ];

  cmakeFlags = [ "-DCMAKE_BUILD_TYPE=Release" ];
  dontWrapQtApps = true;

  meta = with lib; {
    description = "KOS window decoration for KWin - draws the title bar and no buttons";
    homepage = "https://gitee.com/xiaoyintx_ciallo/test";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
