{ pkgs, lib, ... }:

{
  environment.etc = {
    block = {
      source = ./files/block.html;
      target = "localwww/block.html";
      mode = "0644";
    };

    jury-advice = {
      source = ./files/jury-advice.pdf;
      target = "localwww/jury-advice.pdf";
      mode = "0644";
    };
  };

  services.lighttpd = {
    enable = true;
    document-root = "/etc/localwww";
    port = 8080;
  };

}
