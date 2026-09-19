{ lib, ... }:

# Which toolchains the contestant image gets. The toolchains themselves, their
# versions and the my* commands come from the root languages.nix, shared with
# the judgehost - not from the system nixpkgs.
{
  options.modules.contestant.languages.enable = lib.mkEnableOption "programming language toolchains";

  imports = [
    ./c
    ./cpp
    ./python
    ./java
    ./kotlin
  ];
}
