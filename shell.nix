{ pkgs ? import ./pkgs.nix { } }:
pkgs.mkShell {
  buildInputs = with pkgs;
    ([
      bashInteractive
      cargo
      rust-analyzer
      rustc
      rustfmt
      openssl
      pkgconfig
      erlang
      rebar3
    ] ++ lib.optionals stdenv.isDarwin [
      libiconv
      darwin.apple_sdk.frameworks.Security
    ]);
}
