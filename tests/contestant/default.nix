{ pkgs, self, inputs, system, vars }:

# Contestant image only, against the shared server node - the short loop for
# iterating on the contestant image without paying for the console node's
# judgehost registration and five-language submission run.
#
# CI runs tests/all instead, which composes these same fragments. Anything
# added here must be added as a fragment in ../lib.nix, not inline, or the
# merged suite won't pick it up.
let
  t = import ../lib.nix { inherit pkgs self inputs system vars; };
in
t.mkSuite {
  name = "contestant";

  nodes = {
    server = t.serverNode;
    contestant = t.contestantNode;
  };

  # Fail fast: the full contestant image has plenty of unit dependency chains
  # (printer detection, the firstboot self-test, GUI/login) that were never
  # designed to resolve inside an isolated test VM and can otherwise hang for
  # the full default hour before the framework gives up.
  globalTimeout = 25 * 60;

  subtests = t.contestantSubtests;
}
