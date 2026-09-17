{ pkgs }:

# The container images the server host runs, pinned by digest.
#
# Split out of ./containers.nix so tests/ can reference the same derivations
# without restating a digest: tests/server/module.nix loads all four up front
# rather than letting each container unit load its own (see the comment
# there), and needs the paths to do it. The follow-up in issue #74 is to build
# these *from* WISVCH/domjudge-packaging as a flake input instead of pulling
# fixed digests; when that happens, it happens here.
{
  mariadb = pkgs.dockerTools.pullImage {
    imageName = "mariadb";
    imageDigest = "sha256:a75328dabed542a3b704efe54086071cb3f99e6a640cc8a18d7273bc4de2e5e7";
    sha256 = "sha256-TN7daYQGIFfIpTd0Hq1K+M3sq2ZtvfkvL/UA+SA9CLo=";
    finalImageName = "mariadb";
    finalImageTag = "11";
  };

  domserver = pkgs.dockerTools.pullImage {
    imageName = "ghcr.io/wisvch/domjudge-packaging/domserver";
    imageDigest = "sha256:00b90f5e84b04aeb2cad4ed27a61e64c624c771a2687badfd5e1b09e3fc08a46";
    sha256 = "sha256-DmYsEara2YM++kz60qfuCwkXZRrBwW7tcajYK5Sc+yE=";
    finalImageName = "ghcr.io/wisvch/domjudge-packaging/domserver";
    finalImageTag = "packaging-e8150e1";
  };

  # Built from chipcie-dns's own Dockerfiles by its build-images workflow
  # (WISVCH/chipcie-dns#10) - that repo is private, but these two packages
  # were made public independently so no registry credentials are needed here,
  # same as the domserver image above.
  hostnames = pkgs.dockerTools.pullImage {
    imageName = "ghcr.io/wisvch/chipcie-dns/hostnames";
    imageDigest = "sha256:55903382833d5127b9a464f3086a029fb44222d856e3d32263f1c2977c29fbb5";
    sha256 = "sha256-/w2ZBJYz9rjy4xgHrMf+Ewyu3DHpeSsCXjYwN0GuhWE=";
    finalImageName = "ghcr.io/wisvch/chipcie-dns/hostnames";
    finalImageTag = "latest";
  };

  pdns = pkgs.dockerTools.pullImage {
    imageName = "ghcr.io/wisvch/chipcie-dns/pdns";
    imageDigest = "sha256:bfcbd99767aade60ab4579365df7c036af2bd069e142caabd5a528c21cf5c0df";
    sha256 = "sha256-NN4Q6MW0EWC4znN+TEW867VCbCnv7xlKPt8545W58FE=";
    finalImageName = "ghcr.io/wisvch/chipcie-dns/pdns";
    finalImageTag = "latest";
  };
}
