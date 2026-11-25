{
  description = "llm-proxy — context guard and tool-protocol normalizer in front of llama-swap";

  # Pinned to the revision /etc/nixos runs, so a standalone build here and the
  # host build resolve to the same package set. A consumer overrides it with
  # `inputs.llm-proxy.inputs.nixpkgs.follows = "nixpkgs"` (the host does).
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/2786a2a72088ecf32aea5b3ec52099e6a7cff78f";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAllSystems (system: rec {
        default = nixpkgs.legacyPackages.${system}.callPackage ./package.nix { };
        llm-proxy = default;
      });

      # The package's own checkPhase runs the suite, so building it is a check.
      # The separate check runs the same suite straight from the checkout: it
      # catches a test that the packaging happens to hide (a file left out of
      # `src`, a discovery pattern that stops matching).
      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          inherit (self.packages.${system}) default;
          unit = pkgs.runCommand "llm-proxy-unit" { nativeBuildInputs = [ pkgs.python3 ]; } ''
            cp -r ${./.} src
            chmod -R u+w src
            cd src
            python -m unittest discover -s . -p 'test_*.py' -v
            touch $out
          '';
        }
      );

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-rfc-style);
    };
}
