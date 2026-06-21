include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=iavf-intel
PKG_VERSION:=4.13.35
PKG_RELEASE:=1

PKG_SOURCE:=iavf-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://github.com/intel/ethernet-linux-iavf/releases/download/v$(PKG_VERSION)
PKG_HASH:=d4fc9ff8dbc8e3ac39d51489d8a9d66067869a6821d53dfbd738a29fd2d77a10
PKG_BUILD_DIR:=$(KERNEL_BUILD_DIR)/iavf-$(PKG_VERSION)

PKG_LICENSE:=GPL-2.0
PKG_LICENSE_FILES:=COPYING

include $(INCLUDE_DIR)/package.mk

define KernelPackage/iavf-intel
  SUBMENU:=Network Devices
  TITLE:=Intel out-of-tree iavf Virtual Function driver
  URL:=https://github.com/intel/ethernet-linux-iavf
  DEPENDS:=@PCI_SUPPORT @TARGET_x86_64
  FILES:=$(PKG_BUILD_DIR)/src/iavf.ko
  AUTOLOAD:=$(call AutoProbe,iavf)
  CONFLICTS:=kmod-iavf
endef

define KernelPackage/iavf-intel/description
  Intel standalone (out-of-tree) iavf Virtual Function driver $(PKG_VERSION).
  Keeps the pre-page-pool RX queue-config ABI. On kernels >= 6.10 the in-tree
  iavf negotiates a queue config (CONFIG_VSI_QUEUES) that some hypervisor PF
  drivers reject with IAVF_ERR_PARAM, leaving the VF unable to receive; VMware
  ESXi i40en is the common case. Drop-in replacement for the in-tree kmod-iavf.
endef

# The Intel src/Makefile is a dual-mode kbuild file: when invoked by kbuild with
# M=, it provides obj-m/iavf-y. Build it as an external module against the
# OpenWrt target kernel. KSRC is pinned because the Intel makefile autodetects
# the kernel tree from uname -r, which in a build container is the build host.
define Build/Compile
	+$(KERNEL_MAKE) M="$(PKG_BUILD_DIR)/src" KSRC="$(LINUX_DIR)" modules
endef

$(eval $(call KernelPackage,iavf-intel))
