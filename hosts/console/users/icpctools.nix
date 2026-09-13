{ ... }:

{
  users.users.icpctools = {
    isNormalUser = true;
    hashedPassword = "$y$j9T$WKPftiKUOrUjjvxzUS76o/$tS8nd3ja5WZK.AAmFjiF87ihOWrDmjIaX61Bf1J7H7B";
    extraGroups = [ "audio" ];
  };

  home-manager.users.icpctools.imports = [
    ../../../modules/home-manager/icpctools
  ];
}
