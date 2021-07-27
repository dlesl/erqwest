{ pkgs ? import ./pkgs.nix { } }:
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
