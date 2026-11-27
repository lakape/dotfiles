# Local speech-to-text for T3 Code's voice input, set up ahead of time so the
# microphone button works right after a fresh install: no model download and no
# voice setup in the app.
#
# Model: Parakeet Ultra. Among the models T3 Code offers, it has the best German
# accuracy of those that also detect the spoken language by themselves (needed
# for mixing German and English with "Speech language: Auto"; T3 Code falls
# back to English for models without language detection), and it stays fast on
# a laptop CPU (740 MB, ~2 s per 30 s of audio in T3 Code's benchmark).
# Silero VAD is the small silence filter T3 Code downloads alongside any model.
#
# The values are from T3 Code's model catalog (src/speech/catalog.json and
# src/speech/silero.ts in the app). Check them when updating t3code.nix: if a
# file no longer matches, T3 Code simply offers the model for download again.
{ pkgs, lib, ... }:

let
  speechModel = {
    id = "handy-computer/parakeet-ultra-gguf";
    revision = "39eeb55181f0d354fd934f06e92fd8d5037fed8e";
    filename = "parakeet-ultra-Q8_0.gguf";
    sha256 = "007a59761e9258779f189df396b50d12b83bb5b79e66df4b955c230d2f2a0a59";
  };
  sileroVad = {
    id = "handy-computer/silero-vad-v6.2-gguf";
    revision = "97bbd75179f535e4708bccdf61e9278b8b60dfc7";
    filename = "silero-vad-v6.2-F32.gguf";
    sha256 = "0d871a800c420fdd5d1b17a3aea4296d1c39608f0ff4a9295eb76457eb1c88e6";
  };

  fetchModel = model: pkgs.fetchurl {
    name = model.filename;
    url = "https://huggingface.co/${model.id}/resolve/${model.revision}/${model.filename}";
    inherit (model) sha256;
  };

  userdata = "$HOME/.t3/userdata";
in
{
  home.activation.t3codeSpeechModels = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    [ -d "${userdata}" ] || run install -d -m 700 "${userdata}"
    models="${userdata}/speech/models"
    run mkdir -p "$models"

    # Remove links to models from older generations
    for file in "$models"/*; do
      if [ -L "$file" ] && [ ! -e "$file" ]; then run rm -f "$file"; fi
    done

    # T3 Code verifies the files (size and SHA-256) and uses them as if it had
    # downloaded them. A copy it already downloaded itself is identical and kept.
    linkModel() {
      if [ -e "$2" ] && [ ! -L "$2" ]; then return 0; fi
      run ln -sfn "$1" "$2"
    }
    ${lib.concatMapStrings (model: ''
      linkModel ${fetchModel model} "$models/${model.filename}"
    '') [ speechModel sileroVad ]}

    # Select the model once (T3 Code defaults to an English-only model). Later
    # choices in Settings → Speech are kept; T3 Code picks up the change live.
    settings="${userdata}/settings.json"
    seeded="${userdata}/.dotfiles-speech-model"
    if [ ! -e "$seeded" ] && [ ! -v DRY_RUN ]; then
      [ -s "$settings" ] || echo '{}' > "$settings"
      tmp="$(mktemp "$settings.XXXXXX")"
      if ${pkgs.jq}/bin/jq --arg id "${speechModel.id}" '.speechModelId = $id' "$settings" > "$tmp"; then
        chmod 600 "$tmp"
        mv "$tmp" "$settings"
        touch "$seeded"
      else
        rm -f "$tmp"
        echo "T3 Code settings are not valid JSON; select the speech model in the app." >&2
      fi
    fi

    # On a fresh install, choose this computer as the place where speech is
    # turned into text ("Transcribe with" in Settings → Voice), so the
    # microphone button records right away instead of opening the voice setup.
    # T3 Code keeps that choice in its browser Local Storage, but on the first
    # start of a new profile it imports the Local Storage of an older ("V1")
    # profile once, without overwriting anything. The seed below is such a
    # profile. The choice names this computer's T3 Code environment, so its id
    # is created first; T3 Code keeps an existing id.
    appProfile="$HOME/.config/t3code-v2"
    seedProfile="$HOME/.config/t3code"
    if [ ! -v DRY_RUN ] && [ ! -e "$appProfile/v1-local-storage-imported" ] \
        && [ ! -e "$seedProfile" ] && [ ! -e "$HOME/.config/T3 Code (Alpha)" ]; then
      environmentId="${userdata}/environment-id"
      [ -s "$environmentId" ] || cat /proc/sys/kernel/random/uuid > "$environmentId"
      grant="$(printf '{"id":"%s","destination":{"kind":"environment","environmentId":"%s"}}' \
        "$(cat /proc/sys/kernel/random/uuid)" "$(tr -d '[:space:]' < "$environmentId")")"
      install -d -m 700 "$seedProfile"
      touch "$seedProfile/.dotfiles-seed"
      if ! ${pkgs.python3}/bin/python3 -I ${./scripts/seed-chromium-local-storage.py} \
          "$seedProfile/Local Storage/leveldb" t3code://app t3code:voice-audio-grant:v1 "$grant"; then
        rm -rf "$seedProfile"
        echo "Could not preselect the T3 Code dictation destination; choose it in Settings → Voice." >&2
      fi
    fi
    # Once T3 Code has imported the seed, it is no longer needed
    if [ -e "$appProfile/v1-local-storage-imported" ] && [ -e "$seedProfile/.dotfiles-seed" ]; then
      run rm -rf "$seedProfile"
    fi
  '';
}
