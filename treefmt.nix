# Repo-wide formatting, evaluated by treefmt-nix from flake.nix.
#
# Only Nix is wired up today. Adding a language is a `programs.<tool>.enable`
# line here plus any excludes it needs; see https://github.com/numtide/treefmt-nix
# for the available formatters. The tools themselves come from this repo's
# pinned nixpkgs (treefmt-nix follows it in flake.nix), so the formatter
# version only moves when that pin moves - not when treefmt-nix bumps its own.
{
  projectRootFile = "flake.nix";

  # RFC 166 style, the same formatter nixpkgs itself enforces.
  programs.nixfmt.enable = true;
}
