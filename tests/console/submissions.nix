# Subtest fragment for tests/console/default.nix, covering issue #54's
# "submit code of all languages to ensure successful submission and
# testing" checklist item. Runs entirely against the "domjudge" node's own
# localhost REST API - by the time this runs (see default.nix's subtests
# ordering), judgehost.nix has already got a real judgehost registered, so
# a submission here is judged by that judgehost, not faked.
#
# Covers c, cpp, java, kotlin, python3 (see upstream LanguageFixture.php for
# these external IDs). "pypy3" is not a separate submittable DOMjudge
# language - this WISVCH build actually runs python3 submissions through
# pypy3 (see its version-check command in LanguageFixture.php), so
# python3 alone covers both of images/contestant/compilers.nix's
# python3/pypy3 packages. Kotlin is the only one of these languages
# requiring an explicit `entry_point` (see LanguageFixture.php's
# requireEntryPoint column).
{ pkgs }:
let
  lib = pkgs.lib;

  problemZip = import ./submissions/problem.nix { inherit pkgs; };

  cid = "icpcnixtest";

  languages = [
    { id = "c"; file = ./submissions/solutions/sum.c; entryPointFlag = ""; }
    { id = "cpp"; file = ./submissions/solutions/sum.cpp; entryPointFlag = ""; }
    { id = "java"; file = ./submissions/solutions/Main.java; entryPointFlag = ""; }
    {
      id = "kotlin";
      file = ./submissions/solutions/Main.kt;
      # Kotlin compiles a top-level `fun main()` in Main.kt to class MainKt -
      # DOMjudge's kotlin language requires an explicit entry_point since it
      # can't infer this itself (unlike java's 'java_javac_detect' script).
      entryPointFlag = "-F entry_point=MainKt ";
    }
    { id = "python3"; file = ./submissions/solutions/sum.py; entryPointFlag = ""; }
  ];

  submitOne = lang: ''
    print("Submitting the ${lang.id} solution")
    submission = json.loads(domjudge.succeed(
        "curl --fail --silent -u testteam:testpass "
        "-F problem=sum -F language=${lang.id} "
        "${lang.entryPointFlag}"
        "-F 'code[]=@${lang.file}' "
        "http://127.0.0.1/api/v4/contests/${cid}/submissions"
    ))
    verdict = wait_for_verdict("${cid}", submission["id"])
    assert verdict == "AC", f"${lang.id} solution should be judged correct, got {verdict!r}"
  '';
in
{
  name = "submissions";
  script = ''
    import json
    import time

    print("Seeding a test team account via users/accounts (same pattern as tests/contestant/domjudge.nix)")
    domjudge.succeed(
        "printf '%s' "
        "'[{\"id\":\"testteam\",\"username\":\"testteam\",\"name\":\"Test Team\","
        "\"password\":\"testpass\",\"type\":\"team\",\"team_id\":\"1\"}]' "
        "> /tmp/accounts.json"
    )
    domjudge.succeed("podman cp /tmp/accounts.json domserver:/tmp/accounts.json")
    domjudge.succeed(
        "podman exec domserver "
        "/opt/domjudge/domserver/webapp/bin/console api:call "
        "-m POST -f json=/tmp/accounts.json users/accounts"
    )

    def wait_for_verdict(cid, submission_id, timeout=120):
        deadline = time.time() + timeout
        while time.time() < deadline:
            judgements = json.loads(domjudge.succeed(
                "curl --fail --silent -u testteam:testpass "
                f"'http://127.0.0.1/api/v4/contests/{cid}/judgements?submission_id={submission_id}'"
            ))
            for j in judgements:
                if j.get("judgement_type_id"):
                    return j["judgement_type_id"]
            time.sleep(2)
        raise Exception(f"submission {submission_id} was not judged within {timeout}s")

    print("Importing the test contest")
    domjudge.succeed("podman cp ${./submissions/contest.yaml} domserver:/tmp/contest.yaml")
    domjudge.succeed(
        "podman exec domserver "
        "/opt/domjudge/domserver/webapp/bin/console api:call "
        "-m POST -f yaml=/tmp/contest.yaml contests"
    )

    print("Importing the sum problem into it")
    domjudge.succeed("podman cp ${problemZip} domserver:/tmp/sum.zip")
    domjudge.succeed(
        "podman exec domserver "
        "/opt/domjudge/domserver/webapp/bin/console api:call "
        "-m POST -f zip=/tmp/sum.zip contests/${cid}/problems"
    )

    ${lib.concatMapStrings submitOne languages}
  '';
}
