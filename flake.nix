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

      # callPackage function: built inside a kernel package set so that
      # kernelModuleMakeFlags (CC/ARCH/HOSTCC for the kernel build) is injected.
      iavfModule = { stdenv, lib, fetchurl, kmod, which, kernel, kernelModuleMakeFlags }:
        stdenv.mkDerivation {
          pname = "iavf";
          inherit version;
          src = fetchurl {
            url = "https://github.com/intel/ethernet-linux-iavf/releases/download/v${version}/iavf-${version}.tar.gz";
            inherit sha256;
          };
          # Keep the full tree: src/Makefile reaches up to ../kcompat-generator.sh
          # and ../kcompat-gen, so sourceRoot must not be narrowed to src/.
          sourceRoot = "iavf-${version}";
          preBuild = "cd src";
          hardeningDisable = [ "format" "pic" ];
          nativeBuildInputs = [ kmod which ] ++ kernel.moduleBuildDependencies;
          # Intel's Makefile builds standalone (its default target runs
          # -C $(KSRC) M=$(CURDIR) modules itself). KSRC is pinned because its
          # own autodetect keys off uname -r, which in the Nix sandbox is the
          # builder, not the target kernel.
          makeFlags = kernelModuleMakeFlags ++ [
            "KSRC=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
          ];
          installPhase = ''
            runHook preInstall
            install -Dm644 iavf.ko \
              "$out/lib/modules/${kernel.modDirVersion}/updates/dkms/iavf.ko"
            runHook postInstall
          '';
          meta = with nixpkgs.lib; {
            description = "Intel out-of-tree iavf VF driver";
            homepage = "https://github.com/intel/ethernet-linux-iavf";
            license = licenses.gpl2Only;
            platforms = [ "x86_64-linux" ];
          };
        };

      iavfFor = pkgs: kernel:
        (pkgs.linuxPackagesFor kernel).callPackage iavfModule { };
    in
    {
      # Overlay: adds `iavf-intel` to every kernel package set, so a NixOS
      # config can use:
      #   boot.extraModulePackages = [ config.boot.kernelPackages.iavf-intel ];
      overlays.default = final: prev: {
        linuxKernel = prev.linuxKernel // {
          packagesFor = kernel:
            (prev.linuxKernel.packagesFor kernel).extend
              (lpfinal: lpprev: {
                iavf-intel = lpfinal.callPackage iavfModule { };
              });
        };
      };

      # `nix build` against the default kernel (CI build check + local test).
      packages = forAll (system:
        let pkgs = nixpkgs.legacyPackages.${system};
        in {
          iavf = iavfFor pkgs pkgs.linuxPackages.kernel;
          default = iavfFor pkgs pkgs.linuxPackages.kernel;
        });
    };
}
