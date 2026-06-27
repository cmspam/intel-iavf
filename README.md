# intel-iavf

Out-of-tree builds of Intel's `ethernet-linux-iavf` Virtual Function driver and
`ethernet-linux-i40e` 700-Series PF driver, tracking the latest stable upstream
releases and published for several distros.

## Why

Since Linux 6.10 the in-tree `iavf` driver was reworked onto the page-pool RX
path. It now sends a queue configuration (`VIRTCHNL_OP_CONFIG_VSI_QUEUES`) that
some PF drivers reject with `IAVF_ERR_PARAM`, leaving an SR-IOV virtual function
able to transmit but not receive. VMware ESXi's `i40en` PF is the common case.
Intel's standalone driver keeps the prior ABI, so this builds and packages it as
a drop-in replacement for the in-kernel `iavf`.

The matching `i40e` PF driver is packaged the same way (Arch/CachyOS DKMS) so a
host can run Intel's out-of-tree 700-Series driver in place of the in-tree
`i40e` when that behaves better.

## What is published

A scheduled workflow tracks the latest stable Intel release and bumps a single
pinned version. Each target is then built and published:

| Target | Artifact | Release tag |
|---|---|---|
| Arch / CachyOS | `iavf-dkms` + `i40e-dkms` pacman repo | `arch` |
| Debian / Proxmox | `iavf-dkms_<ver>_all.deb` | `debian` |
| OpenWrt | `kmod-iavf-intel` apk / ipk, x86/64 | one per OpenWrt version |
| Nix | flake (built from source by the consumer) | none |

`i40e-dkms` ships in the same `arch` pacman repo as `iavf-dkms`, so consumers
add one repo. Every build carries a `depmod` override (`override iavf * ...` /
`override i40e * ...`) so the out-of-tree module is selected over the identically
named in-kernel one.

## Use

### Arch / CachyOS

Add the pacman repo, then install `iavf-dkms` and/or `i40e-dkms`:

```
[iavf-dkms]
SigLevel = Optional TrustAll
Server = https://github.com/cmspam/intel-iavf/releases/download/arch
```

Both packages live in this one repo (`i40e-dkms` is the Intel 700-Series PF
driver; `iavf-dkms` the VF driver).

### Debian / Proxmox

```
apt install ./iavf-dkms_<ver>_all.deb
```

Needs `linux-headers` for the running kernel. DKMS builds the module on install.

### OpenWrt

Download the release matching your OpenWrt version, then:

```
apk add --allow-untrusted ./kmod-iavf-intel-*.apk   # 25.12 and newer
opkg install ./kmod-iavf-intel-*.ipk                # 24.10 and earlier
```

Replaces the in-tree `kmod-iavf`; remove that package first if present.

### Nix

```nix
{
  inputs.intel-iavf.url = "github:cmspam/intel-iavf";
  # In your NixOS config, with intel-iavf.overlays.default applied to pkgs:
  #   boot.extraModulePackages = [ config.boot.kernelPackages.iavf-intel ];
}
```

## Layout

```
arch/PKGBUILD                       Arch iavf-dkms package
arch/i40e/PKGBUILD                  Arch i40e-dkms package
openwrt/package/iavf-intel/Makefile OpenWrt kmod package
flake.nix                           Nix module + overlay
scripts/latest-iavf.sh              resolve latest stable upstream iavf release
scripts/latest-i40e.sh              resolve latest stable upstream i40e release
.github/workflows/                  update + per-target build workflows
```

Driver versions are pinned in `arch/PKGBUILD` (iavf, also `openwrt/.../Makefile`
and `flake.nix`) and `arch/i40e/PKGBUILD` (i40e), kept in sync by `update.yml`.
