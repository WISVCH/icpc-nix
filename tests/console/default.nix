{
  pkgs,
  self,
  inputs,
  system,
  vars,
  languages,
}:

# Console image only, against the shared server node - the short loop for
# iterating on the console image and its judgehost.
#
# CI runs tests/all instead, which composes these same fragments. Anything
# added here must be added as a fragment in ../lib.nix, not inline, or the
# merged suite won't pick it up.
let
  t = import ../lib.nix {
    inherit
      pkgs
      self
      inputs
      system
      vars
      languages
      ;
  };
in
t.mkSuite {
  name = "console";

  nodes = {
    server = t.serverNode;
    console = t.consoleNode;
  };

  # Covers the server node's mariadb + domserver container boot, DB
  # install/migration and REST seeding, plus judgehost registering and
  # actually compiling/running five languages' worth of submissions.
  globalTimeout = 25 * 60;

  subtests = t.consoleSubtests;
}
