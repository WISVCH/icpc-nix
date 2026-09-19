{ multiverse }:

# The judged language toolchains, pinned to exact versions - the one place a
# contest's language versions are decided (issues #31, #74).
#
# Everything that compiles or runs a contestant's code takes its toolchain
# from here: the contestant image (modules/nixos/contestant/languages), and
# the judgehost image once it is built from WISVCH/domjudge-packaging. Both
# receive the same derivations, so they get the same store paths, not just
# matching version strings.
#
# Resolved through nixpkgs-multiverse rather than the system nixpkgs, so a
# nixpkgs bump never moves a language version: only editing `pins` does.
# checks.languages (see flake.nix) holds these to one nixpkgs revision and
# to the versions written here.
let
  pins = {
    gcc = "15.3.0";
    jdk21 = "21.0.12.1+1";
    kotlin = "2.4.20";
    pypy311 = "7.3.20";
    # Contestant-only: `python3` for contestants who type it, at the same
    # language level as the judged PyPy. Submissions run on pypy3.
    python311 = "3.11.16";
  };

  plan = multiverse.pinPlan pins;

  # The whole revision the pins resolve to, not just the pinned attributes:
  # gcc's static glibc and kotlin's JVM must come from that same revision.
  # checks.languages fails the build if the pins ever need more than one.
  p = multiverse.at (builtins.head plan.groups).revision.label;

  # A plain nixpkgs gcc cannot link -static ("cannot find -lc"): its wrapper
  # only knows the shared glibc. Point it at the static one as well.
  gcc = p.gcc.overrideAttrs (old: {
    postFixup = (old.postFixup or "") + ''
      echo "-L${p.glibc.static}/lib" >> $out/nix-support/cc-ldflags
    '';
  });

  jdk = p.jdk21;
  kotlin = p.kotlin.override { jre = jdk; };

  # The command lines are the ones published on chipcie.wisv.ch/systems
  # (JVM heap sized for the 2 GiB memory limit).
  #
  # `packages` are judged and shared with the judgehost; the first one is
  # the package `version` describes. `compile`/`run` are the commands
  # contestants get as my* and DOMjudge judges with.
  mkLanguage =
    {
      packages,
      version,
      compile ? null,
      run ? null,
      contestantPackages ? [ ],
    }:
    {
      inherit
        packages
        version
        compile
        run
        contestantPackages
        ;
      # Pinned toolchain first on PATH, so a my* command never picks up some
      # other gcc/java the image happens to have.
      commands =
        map
          (
            c:
            p.writeShellScriptBin c.name ''
              PATH=${p.lib.makeBinPath packages}:$PATH
              exec ${c.command}
            ''
          )
          (
            builtins.filter (c: c != null) [
              compile
              run
            ]
          );
    };
in
{
  inherit pins plan;
  # Each pinned attribute as the revision actually ships it, for
  # checks.languages to compare against `pins`.
  resolved = builtins.mapAttrs (attr: _: p.${attr}) pins;

  c = mkLanguage {
    packages = [ gcc ];
    version = pins.gcc;
    compile = {
      name = "mygcc";
      command = ''gcc -std=gnu17 -x c -Wall -O2 -static -pipe -o "$1" "$1.c" -lm'';
    };
  };

  cpp = mkLanguage {
    packages = [ gcc ];
    version = pins.gcc;
    compile = {
      name = "mygpp";
      command = ''g++ -std=gnu++20 -x c++ -Wall -O2 -static -pipe -o "$1" "$1.cpp" -lm'';
    };
  };

  java = mkLanguage {
    packages = [ jdk ];
    version = pins.jdk21;
    compile = {
      name = "myjavac";
      command = ''javac -encoding UTF-8 -sourcepath . -d . "$@"'';
    };
    run = {
      name = "myjava";
      command = ''java -Dfile.encoding=UTF-8 -XX:+UseSerialGC -Xss65536k -Xms1966080k -Xmx1966080k "$@"'';
    };
  };

  kotlin = mkLanguage {
    packages = [ kotlin ];
    version = pins.kotlin;
    compile = {
      name = "mykotlinc";
      command = ''kotlinc -d . "$@"'';
    };
    run = {
      name = "mykotlin";
      command = ''kotlin -Dfile.encoding=UTF-8 -J-XX:+UseSerialGC -J-Xss65536k -J-Xms1966080k -J-Xmx1966080k "$@"'';
    };
  };

  python = mkLanguage {
    packages = [ p.pypy311 ];
    version = pins.pypy311;
    run = {
      name = "mypython";
      command = ''pypy3 "$@"'';
    };
    # Without python311's passthru `doc` - a Sphinx build that isn't in the
    # binary cache and fails to build, yet buildEnv installs any attribute
    # named in environment.extraOutputsToInstall (NixOS includes "doc").
    # Its docs come from python.org instead, see
    # modules/nixos/contestant/localweb.nix.
    contestantPackages = [ (builtins.removeAttrs p.python311 [ "doc" ]) ];
  };
}
