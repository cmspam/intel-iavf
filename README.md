# intel-iavf

Out-of-tree builds of Intel's `ethernet-linux-iavf` Virtual Function driver,
tracking the latest stable upstream release and published for several distros.

## Why

Since Linux 6.10 the in-tree `iavf` driver was reworked onto the page-pool RX
path. It now sends a queue configuration (`VIRTCHNL_OP_CONFIG_VSI_QUEUES`) that
some PF drivers reject with `IAVF_ERR_PARAM`, leaving an SR-IOV virtual function
able to transmit but not receive. VMware ESXi's `i40en` PF is the common case.
Intel's standalone driver keeps the prior ABI, so this builds and packages it as
a drop-in replacement for the in-kernel `iavf`.

## What is published

A scheduled workflow tracks the latest stable Intel release and bumps a single
pinned version. Each target is then built and published:

| Target | Artifact | Release tag |
|---|---|---|
| Arch / CachyOS | `iavf-dkms` pacman repo | `arch` |
| Debian / Proxmox | `iavf-dkms_<ver>_all.deb` | `debian` |
| OpenWrt | `kmod-iavf-intel` apk / ipk, x86/64 | one per OpenWrt version |
| Nix | flake (built from source by the consumer) | none |

All builds carry a `depmod` override (`override iavf * updates/dkms`) so the
out-of-tree module is selected over the identically named in-kernel `iavf`.

## Use

### Arch / CachyOS

Add the pacman repo, then install `iavf-dkms`:

```
[iavf-dkms]
SigLevel = Optional TrustAll
Server = https://github.com/cmspam/intel-iavf/releases/download/arch
```

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
openwrt/package/iavf-intel/Makefile OpenWrt kmod package
flake.nix                           Nix module + overlay
scripts/latest-iavf.sh              resolve latest stable upstream release
.github/workflows/                  update + per-target build workflows
```

The driver version is pinned in `arch/PKGBUILD`, `openwrt/.../Makefile`, and
`flake.nix`, kept in sync by `update.yml`.
