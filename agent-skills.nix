# Matt Pocock's agent skills (https://github.com/mattpocock/skills), linked into
# the user skill directories of the coding agents, so they are available right
# after a fresh install without any plugin setup.
#
# The set of skills is the one his official plugin ships (.claude-plugin/plugin.json).
# Update to the latest version: `nix flake update mattpocock-skills`, then `rebuild`.
{ lib, inputs, ... }:

let
  src = inputs.mattpocock-skills;
  plugin = builtins.fromJSON (builtins.readFile "${src}/.claude-plugin/plugin.json");
  skillPaths = map (lib.removePrefix "./") plugin.skills;

  # Skill directories read by the agents:
  #   ~/.claude/skills                Claude Code (also the Claude provider in T3 Code)
  #   ~/.agents/skills                Codex, Gemini CLI, OpenCode, Pi, Cursor, Copilot, Amp
  #   ~/.gemini/antigravity-cli/skills  Antigravity CLI (agy)
  skillRoots = [ ".claude/skills" ".agents/skills" ".gemini/antigravity-cli/skills" ];

  # Real directories with symlinked files, so skills of your own can live next to them
  linkSkill = root: path: lib.nameValuePair "${root}/${baseNameOf path}" {
    source = "${src}/${path}";
    recursive = true;
  };
in
{
  home.file = lib.listToAttrs (lib.concatMap (root: map (linkSkill root) skillPaths) skillRoots);
}
