{

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    systems.url = "github:nix-systems/x86_64-linux";
    flake-utils = {
      url = "github:numtide/flake-utils";
      inputs.systems.follows = "systems";
    };
  };

  outputs =
    { self
    , nixpkgs
    , flake-utils
    , ...
    }:
    flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = nixpkgs.legacyPackages.${system};
      pname = "vss";
      version = "0.0.1";
      src = ./.;

      nativeBuildInputs = with pkgs; [
        gnat
        gprbuild
      ];
    in
    {
      devShells.default = pkgs.mkShell {
        inherit nativeBuildInputs;

      };

      packages.default = pkgs.stdenv.mkDerivation
        {
          inherit nativeBuildInputs pname version src;

          buildPhase = ''
            make build-libs-static
          '';

          # TODO add install directory with Makefile gprinstall has -d flag for directory for install
          installPhase = ''
            
            INSTALL_PROJECT_DIR=$out/bin INSTALL_INCLUDE_DIR=$out/bin/include/vss/ INSTALL_EXEC_DIR=$out/bin INSTALL_LIBRARY_DIR=$out/bin INSTALL_ALI_DIR=$out/bin/vss/ make install-libs-static
            
          '';
        };
    });
}
