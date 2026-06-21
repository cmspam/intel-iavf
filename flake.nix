{
  description = "Intel out-of-tree iavf Virtual Function driver (out-of-tree kernel module)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      # version and sha256 are maintained by .github/workflows/update.yml.
      version = "4.13.35";
      sha256 = "d4fc9ff8dbc8e3ac39d51489d8a9d66067869a6821d53dfbd738a29fd2d77a10";

      systems = [ "x86_64-linux" ];
      forAll = nixpkgs.lib.genAttrs systems;

      # Build the module against an arbitrary kernel derivation.
      iavfFor = pkgs: kernel:
        pkgs.stdenv.mkDerivation {
          pname = "iavf";
          inherit version;
          src = pkgs.fetchurl {
            url = "https://github.com/intel/ethernet-linux-iavf/releases/download/v${version}/iavf-${version}.tar.gz";
            inherit sha256;
          };
          sourceRoot = "iavf-${version}/src";
          hardeningDisable = [ "pic" ];
          nativeBuildInputs = kernel.moduleBuildDependencies;
          # KSRC is pinned: the Intel makefile autodetects the kernel tree from
          # uname -r, which in the Nix sandbox is the builder, not the target.
          makeFlags = kernel.makeFlags ++ [
            "-C"
            "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
            "M=$(PWD)"
            "KSRC=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
            "modules"
          ];
          installPhase = ''
            install -Dm644 iavf.ko \
              "$out/lib/modules/${kernel.modDirVersion}/updates/dkms/iavf.ko"
          '';
          meta = with nixpkgs.lib; {
            description = "Intel out-of-tree iavf VF driver";
            homepage = "https://github.com/intel/ethernet-linux-iavf";
            license = licenses.gpl2Only;
            platforms = [ "x86_64-linux" ];
          };
        };
    in
    {
      # Overlay: adds `iavf-intel` to every kernel package set, so a NixOS
      # config can use `boot.extraModulePackages = [ config.boot.kernelPackages.iavf-intel ];`
      overlays.default = final: prev: {
        linuxKernel = prev.linuxKernel // {
          packagesFor = kernel:
            (prev.linuxKernel.packagesFor kernel).extend
              (lpfinal: lpprev: { iavf-intel = iavfFor final kernel; });
        };
      };

      # `nix build` against the default kernel (CI build check + quick local test).
      packages = forAll (system:
        let pkgs = nixpkgs.legacyPackages.${system};
        in {
          iavf = iavfFor pkgs pkgs.linuxPackages.kernel;
          default = iavfFor pkgs pkgs.linuxPackages.kernel;
        });
    };
}
