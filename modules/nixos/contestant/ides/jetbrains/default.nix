{ lib, ... }:

# Umbrella only - no packages of its own. Each JetBrains product
# (idea/, pycharm/, clion/) only installs when both its own flag and this
# one are enabled, so this single switch turns all of them off at once
# (e.g. during development, when the extra build/disk cost isn't worth it).
{
  options.modules.contestant.ides.jetbrains.enable = lib.mkEnableOption "JetBrains IDEs (IDEA/PyCharm/CLion)";
}
