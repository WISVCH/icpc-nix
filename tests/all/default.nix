{
  pkgs,
  self,
  inputs,
  system,
  vars,
}:

# The suite CI runs: all three images booted once, against one DOMjudge.
#
# Previously tests/contestant and tests/console each stood up their own
# DOMjudge node, so every CI run booted mariadb + domserver + hostnames +
# pdns twice and waited through the database install/migration twice. Only
# one self-hosted runner is registered, so those two suites could never run
# in parallel either - the second boot was pure serial cost.
#
# The per-image suites still exist (tests/console, tests/contestant) and
# compose these same fragments; they're the short loop when you're iterating
# on one image. CI only runs this one.
let
  t = import ../lib.nix {
    inherit
      pkgs
      self
      inputs
      system
      vars
      ;
  };
in
t.mkSuite {
  name = "all";

  nodes = {
    server = t.serverNode;
    console = t.consoleNode;
    contestant = t.contestantNode;
  };

  # Both suites used 25 minutes on their own. This covers one server-node
  # boot (mariadb + domserver container start, DB install/migration, REST
  # seeding), the contestant checks, and then judgehost registering and
  # compiling/running five languages' worth of submissions - serially, in a
  # single boot.
  globalTimeout = 45 * 60;

  subtests = t.contestantSubtests ++ t.consoleSubtests;
}
