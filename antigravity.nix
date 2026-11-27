# Antigravity CLI (`agy`), the ACP runtime T3 Code uses for its Antigravity
# provider. T3 Code finds it on PATH, so no per-machine setup is needed.
#
# Google publishes a prebuilt binary only. Update: read the current version,
# URL and sha512 from
#   https://antigravity-cli-auto-updater-974169037036.us-central1.run.app/manifests/linux_amd64.json
# and convert the hash with `nix hash convert --hash-algo sha512 --to sri <hex>`.
{ lib, stdenv, fetchurl, autoPatchelfHook }:

stdenv.mkDerivation rec {
  pname = "antigravity-cli";
  version = "1.5.18";

  src = fetchurl {
    url = "https://storage.googleapis.com/antigravity-public/antigravity-cli/${version}-6386224290725888/linux-x64/cli_linux_x64.tar.gz";
    hash = "sha512-7zeeyGlxkRL2lujHz933dmGHEuWPw45T34CAHWUoq7Rnd4LHyHePnAnJEj+kTCwyZ10ijAbyqPeo9CFOdfW7Jg==";
  };

  sourceRoot = ".";
  nativeBuildInputs = [ autoPatchelfHook ];
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 antigravity $out/bin/agy
    runHook postInstall
  '';

  meta = {
    description = "Google Antigravity command-line agent (ACP runtime for T3 Code)";
    homepage = "https://antigravity.google";
    license = lib.licenses.unfree;
    mainProgram = "agy";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
