let pkgs = import ../pkgs.nix { };
in (import ../shell.nix { inherit pkgs; }).overrideAttrs (old: {
  buildInputs = old.buildInputs ++ (with pkgs; [
    (nginx.override { modules = [ nginxModules.echo ]; })
    libevent
    curl
  ]);
})
