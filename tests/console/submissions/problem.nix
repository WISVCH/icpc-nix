# Zips ./problem into a DOMjudge problem archive. The zip's basename (sans
# .zip) becomes the problem's externalid/shortname if domjudge-problem.ini
# doesn't set them (see DOMjudge's ImportProblemService::importZippedProblem)
# - named "sum.zip" here so the imported problem's shortname is "sum",
# matching the `problem=sum` field submissions.nix submits against.
{ pkgs }:

pkgs.runCommand "sum.zip" { nativeBuildInputs = [ pkgs.zip ]; } ''
  cp -r --no-preserve=mode ${./problem} problem
  cd problem
  zip -r -X $out .
''
