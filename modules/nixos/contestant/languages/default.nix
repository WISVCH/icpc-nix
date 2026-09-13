{ lib, ... }:

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
