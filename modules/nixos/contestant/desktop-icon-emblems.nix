{ ... }:
{
  # Thunar always overlays an "emblem-symbolic-link" badge on symlinks, with no
  # per-folder toggle to disable it. Every launcher on the contestant Desktop is a
  # symlink (home-manager's home.file mechanism symlinks the whole tree into the
  # Nix store), so contestants see a link badge on every icon. Strip the emblem
  # from every icon theme the xfce desktop manager installs so it never renders,
  # regardless of which theme ends up active.
  nixpkgs.overlays = [
    (final: prev: {
      adwaita-icon-theme = prev.adwaita-icon-theme.overrideAttrs (old: {
        postInstall = (old.postInstall or "") + ''
          find $out/share/icons -iname 'emblem-symbolic-link*' -delete
        '';
      });
      tango-icon-theme = prev.tango-icon-theme.overrideAttrs (old: {
        postInstall = (old.postInstall or "") + ''
          find $out/share/icons -iname 'emblem-symbolic-link*' -delete
        '';
      });
      xfce4-icon-theme = prev.xfce4-icon-theme.overrideAttrs (old: {
        postInstall = (old.postInstall or "") + ''
          find $out/share/icons -iname 'emblem-symbolic-link*' -delete
        '';
      });
    })
  ];
}
