# T3 Code desktop app, packaged from the official AppImage.
#
# nixpkgs lags behind (0.1.8 on master), but T3 Code's data directory (~/.t3)
# must not be opened by an older version than the one that last wrote it.
# Update: change `version`, set `hash = lib.fakeHash;`, run `rebuild` and copy
# the hash Nix reports into this file.
{ lib, appimageTools, fetchurl }:

let
  pname = "t3code";
  version = "0.1.12";

  src = fetchurl {
    url = "https://github.com/pingdotgg/t3code/releases/download/v${version}/T3-Code-x86_64.AppImage";
    hash = "sha256-ZrkVUVcd9tKbVctZApXt9BHP+WyVqP6z9Bw8pZXXIuI=";
  };

  contents = appimageTools.extract { inherit pname version src; };
in
appimageTools.wrapType2 {
  inherit pname version src;

  extraInstallCommands = ''
    install -Dm644 ${contents}/t3code.desktop $out/share/applications/t3code.desktop
    substituteInPlace $out/share/applications/t3code.desktop \
      --replace-fail 'Exec=AppRun %U' 'Exec=t3code %U'
    mkdir -p $out/share
    cp -r ${contents}/usr/share/icons $out/share/icons
  '';

  meta = {
    description = "Desktop app for coding agents";
    homepage = "https://t3.codes";
    license = lib.licenses.mit;
    mainProgram = "t3code";
    platforms = [ "x86_64-linux" ];
  };
}
