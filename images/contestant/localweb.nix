{ pkgs, lib, vars, ... }:

let
  # C and C++ share the same cppreference book; only the index page differs.
  cppreferenceDoc = pkgs.fetchzip {
    url = "https://github.com/PeterFeicht/cppreference-doc/releases/download/v20250209/html-book-20250209.tar.xz";
    hash = "sha256-bgflZLipY+lBn8tNYmSgPurErGBO2OGF3J0wyTiS0TE=";
  };

  openjdk17Doc = pkgs.fetchurl {
    url = "https://deb.debian.org/debian/pool/main/o/openjdk-17/openjdk-17-doc_17.0.20.1+1-1_all.deb";
    hash = "sha256-T1PqSa6fwWitUr9WsGUTVA1U/tZi/Uf4HEvlyHLr/2U=";
  };

  # The javadoc HTML actually ships under a path named for
  # openjdk-17-jre-headless inside this .deb's data.tar.xz - a Debian
  # packaging quirk, not a typo. No separate javadoc archive exists upstream.
  javaApiDocs = pkgs.stdenvNoCC.mkDerivation {
    pname = "openjdk-17-api-docs";
    version = "17.0.20.1+1-1";

    nativeBuildInputs = [ pkgs.binutils pkgs.gnutar pkgs.xz ];

    dontUnpack = true;

    buildPhase = ''
      runHook preBuild
      ar x ${openjdk17Doc}
      tar xf data.tar.xz ./usr/share/doc/openjdk-17-jre-headless/api
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mv usr/share/doc/openjdk-17-jre-headless/api "$out"
      runHook postInstall
    '';
  };

  # Pinned to a commit rather than a moving branch. This is JetBrains' old
  # PDF reference - they've never published a newer offline HTML bundle.
  kotlinReferencePdf = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/JetBrains/kotlin-web-site/20b7c7c3e527c30a2e876f411e29da297353140b/assets/kotlin-reference.pdf";
    hash = "sha256-QaxZ0bNyEOrW4CXhtCAWncy4AdUA1mUPHsv0bNZyn8o=";
  };

  # docs.python.org has no patch-pinned archive for 3.14 yet (matching this
  # image's actual python3 version), only this rolling, unversioned zip -
  # bump the hash here if upstream republishes it and the fetch starts
  # failing. PyPy3 has no separate stdlib doc set; it reuses this.
  python3Docs = pkgs.fetchzip {
    url = "https://docs.python.org/3.14/archives/python-3.14-docs-html.zip";
    hash = "sha256-N0i4IfRpsacJF/jA/dqSc3rzudR2Rs53zgm+YHvtPwo=";
  };

  docsIndex = pkgs.replaceVars ./files/docs-index.html {
    inherit (vars) domjudge_url;
  };
in
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

    docs-index = {
      source = docsIndex;
      target = "localwww/index.html";
      mode = "0644";
    };

    docs-c = {
      source = cppreferenceDoc;
      target = "localwww/c";
    };

    docs-cpp = {
      source = cppreferenceDoc;
      target = "localwww/cpp";
    };

    docs-java = {
      source = javaApiDocs;
      target = "localwww/java";
    };

    docs-kotlin = {
      source = kotlinReferencePdf;
      target = "localwww/kotlin/kotlin-reference.pdf";
      mode = "0644";
    };

    docs-python3 = {
      source = python3Docs;
      target = "localwww/python3";
    };
  };

  services.lighttpd = {
    enable = true;
    document-root = "/etc/localwww";
    port = 8080;
  };

}
