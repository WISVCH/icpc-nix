{ pkgs, lib, ... }:

{
  environment.systemPackages = with pkgs; [
    # C
    gcc

    # C++
    boost
    catch2
    cmake

    # Java
    zulu17

    # Kotlin
    kotlin

    # Python3
    python3
    pypy3
  ];
}
