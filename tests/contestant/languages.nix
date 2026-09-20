{ languages }:

# Subtest fragment. Composed by tests/lib.nix into the merged tests/all
# suite that CI runs, and into the per-image suite for iteration - it is
# not tied to either one.
#
# Every my* command a contestant is told about (chipcie.wisv.ch/systems)
# compiles and runs a hello world, and every toolchain on PATH reports the
# version languages.nix pins. Regression test for #31: mygcc/mygpp's
# -static used to fail outright on this image ("cannot find -lc"), unnoticed
# because submissions are judged elsewhere.
let
  # Version strings as the tools print them: jdk's "+build" suffix isn't.
  expected = builtins.mapAttrs (_: v: builtins.head (builtins.split "\\+" v)) languages.pins;
in
{
  name = "languages";
  script = ''
    import struct

    contestant.succeed("mkdir -p /tmp/langs")

    def assert_static(name):
        # No PT_INTERP program header means no dynamic loader: statically
        # linked. (Grepping for "ld-linux" doesn't work - static glibc
        # binaries still carry the string.)
        contestant.copy_from_vm(f"/tmp/langs/{name}", "langs")
        elf = (contestant.out_dir / "langs" / name).read_bytes()
        phoff, = struct.unpack_from("<Q", elf, 0x20)
        phentsize, phnum = struct.unpack_from("<HH", elf, 0x36)
        types = [struct.unpack_from("<I", elf, phoff + i * phentsize)[0] for i in range(phnum)]
        assert 3 not in types, f"{name} is dynamically linked"

    def compile_and_run(files, commands, expected):
        for name, source in files.items():
            contestant.succeed(f"cat > /tmp/langs/{name} <<'SRC'\n{source}\nSRC")
        out = contestant.succeed(f"cd /tmp/langs && {commands}")
        assert expected in out, f"expected {expected!r} from {commands!r}, got {out!r}"

    compile_and_run(
        {"hello.c": '#include <stdio.h>\nint main(void) { puts("hello c"); return 0; }'},
        "mygcc hello && ./hello",
        "hello c",
    )
    assert_static("hello")

    compile_and_run(
        {"hellocpp.cpp": '#include <iostream>\nint main() { std::cout << "hello cpp" << std::endl; }'},
        "mygpp hellocpp && ./hellocpp",
        "hello cpp",
    )
    assert_static("hellocpp")

    compile_and_run(
        {"Main.java": 'public class Main { public static void main(String[] a) { System.out.println("hello java"); } }'},
        "myjavac Main.java && myjava Main",
        "hello java",
    )

    compile_and_run(
        {"hello.kt": 'fun main() { println("hello kotlin") }'},
        "HOME=/tmp/langs mykotlinc hello.kt && mykotlin HelloKt",
        "hello kotlin",
    )

    compile_and_run(
        {"hello.py": 'print("hello python")'},
        "mypython hello.py",
        "hello python",
    )

    # What's on PATH is what languages.nix pins - not the system nixpkgs'.
    for command, version in [
        ("gcc --version", "${expected.gcc}"),
        ("g++ --version", "${expected.gcc}"),
        ("java -version 2>&1", "${expected.jdk21}"),
        ("kotlin -version 2>&1", "${expected.kotlin}"),
        ("pypy3 --version", "PyPy ${expected.pypy311}"),
        ("python3 --version", "Python ${expected.python311}"),
    ]:
        out = contestant.succeed(command)
        assert version in out, f"{command!r}: expected {version!r}, got {out!r}"
  '';
}
