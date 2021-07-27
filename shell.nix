let
  url =
    "https://github.com/NixOS/nixpkgs/archive/407ef1dc6f91f9ecf7f61e4dfaedcde052f2bd17.tar.gz";
in { pkgs ? import (fetchTarball url) { } }:
pkgs.mkShell {
  buildInputs = with pkgs; [
    bashInteractive
    cargo
    rust-analyzer
    rustc
    rustfmt
    openssl
    pkgconfig
    erlang
    rebar3
  ];
}
