# cptofs (from lkl, used by make-disk-image.nix to populate the disk image)
# never resets errno before calling readdir(), so a stale errno left over from
# an earlier LKL syscall gets misreported as "error while reading directory
# ... Invalid argument" on ordinary, successful end-of-directory. Harmless but
# extremely noisy in CI logs - patch it at the source instead of filtering
# the output.
_final: prev: {
  lkl = prev.lkl.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./cptofs-reset-errno-before-readdir.patch ];
  });
}
