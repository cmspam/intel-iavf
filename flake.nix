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
        let
          kdir = "${kernel.dev}/lib/modules/${kernel.modDirVersion}";
          # kernelModuleMakeFlags sets KBUILD_OUTPUT to the read-only build tree
          # and may set KSRC; drop both so our merged, writable KSRC wins.
          ccFlags = builtins.filter
            (f: !(lib.hasPrefix "KBUILD_OUTPUT=" f) && !(lib.hasPrefix "KSRC=" f))
            kernelModuleMakeFlags;
        in
        stdenv.mkDerivation {
          pname = "iavf";
          inherit version;
          src = fetchurl {
            url = "https://github.com/intel/ethernet-linux-iavf/releases/download/v${version}/iavf-${version}.tar.gz";
            inherit sha256;
          };
          # Keep the full tree: src/Makefile reaches up to ../kcompat-generator.sh
          # and ../scripts, so sourceRoot must not be narrowed to src/.
          sourceRoot = "iavf-${version}";
          hardeningDisable = [ "format" "pic" ];
          nativeBuildInputs = [ kmod which ] ++ kernel.moduleBuildDependencies;
          makeFlags = ccFlags;
          # Intel's common.mk / kcompat-generator want a single unified kernel
          # tree (headers + generated + Module.symvers). nixpkgs splits these:
          # source/ has the headers, build/ has generated + .config + symvers.
          # Build a writable merged tree and point KSRC/KBUILD_OUTPUT at it.
          # Also pin $src (Nix exports it as the tarball path, clobbering the
          # src make variable common.mk uses to find kcompat-generator.sh).
          preBuild = ''
            cd src
            export src="$PWD"
            ksrc="$NIX_BUILD_TOP/ksrc"
            mkdir -p "$ksrc"
            cp -as ${kdir}/source/. "$ksrc/"
            chmod -R u+w "$ksrc"
            cp -asf ${kdir}/build/. "$ksrc/"
            chmod -R u+w "$ksrc"
            # kbuild may rewrite the top Makefile; the overlaid one is a symlink
            # into the read-only store. Replace it with a real, writable copy.
            rm -f "$ksrc/Makefile"
            cp -L ${kdir}/source/Makefile "$ksrc/Makefile"
            chmod u+w "$ksrc/Makefile"
            export KSRC="$ksrc"
          '';
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
