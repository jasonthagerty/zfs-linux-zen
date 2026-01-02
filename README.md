# zfs-linux-zen

Automated AUR package for ZFS kernel modules compiled against the linux-zen kernel.

## Overview

This repository maintains the `zfs-linux-zen` package for Arch Linux, providing pre-compiled ZFS kernel modules specifically built for the [linux-zen](https://archlinux.org/packages/extra/x86_64/linux-zen/) kernel variant.

## Key Features

- **Fully Automated Updates**: Checks for new kernel and ZFS releases every 6 hours
- **Always In Sync**: Automatically updates when either upstream changes
- **Zero Maintenance**: Commits and pushes updates without manual intervention
- **Transparent**: All automation visible in this repository

## Installation

Install from the AUR:

```bash
# Using yay
yay -S zfs-linux-zen

# Using paru
paru -S zfs-linux-zen

# Manual build
git clone https://aur.archlinux.org/zfs-linux-zen.git
cd zfs-linux-zen
makepkg -si
```

## Package Contents

This package provides:

- **zfs-linux-zen**: Kernel modules for ZFS filesystem
- **zfs-linux-zen-headers**: Development headers for ZFS

Dependencies:
- `linux-zen` - The zen kernel
- `zfs-utils` - ZFS userspace utilities
- `kmod` - Kernel module tools

## Automation

This repository uses GitHub Actions to automatically monitor and update the package:

- **Upstream Monitoring**: Checks OpenZFS and linux-zen releases
- **Automatic Updates**: Updates PKGBUILD when new versions are available
- **Scheduled Runs**: Every 6 hours (4 times daily)
- **Manual Triggers**: Can be run on-demand for testing or emergency updates

See [AUTOMATION.md](AUTOMATION.md) for detailed documentation.

## Why This Package?

The linux-zen kernel is optimized for desktop performance with additional patches. ZFS modules must be compiled specifically for each kernel version. This package:

1. Tracks the exact linux-zen version
2. Compiles ZFS modules against that specific kernel
3. Updates automatically when either upstream changes
4. Prevents version mismatch issues

## Package Versions

Current versions are tracked in [PKGBUILD](PKGBUILD):

- **ZFS Version**: See `_zfsver` variable
- **Kernel Version**: See `_kernelver` variable

## Troubleshooting

### Module Not Loading

Ensure your installed kernel matches the package:

```bash
# Check kernel version
uname -r

# Check package version
pacman -Qi zfs-linux-zen | grep Version
```

If versions don't match, update your system:

```bash
sudo pacman -Syu
```

### Build Failures

The package requires:
- `linux-zen-headers` matching your kernel version
- `base-devel` package group
- `zfs-utils` at the same version as ZFS source

### Out of Sync

If the package is out of sync with your kernel:

1. Check for pending updates: `pacman -Syu`
2. Check the [Actions tab](../../actions) for recent automation runs
3. Trigger a manual update (maintainers only)

## Contributing

Contributions welcome! To improve the automation or package:

1. Fork this repository
2. Make your changes
3. Test with the manual update workflow
4. Submit a pull request

## Links

- **AUR Package**: https://aur.archlinux.org/packages/zfs-linux-zen
- **OpenZFS**: https://openzfs.org/
- **Arch Linux Zen Kernel**: https://archlinux.org/packages/extra/x86_64/linux-zen/
- **Automation Scripts**: [archzfs/archzfs](https://github.com/archzfs/archzfs)

## Maintainer

- Jan Houben <jan@nexttrex.de>

## License

CDDL (Common Development and Distribution License) - same as ZFS

## Credits

- **OpenZFS Team**: For the ZFS filesystem
- **Arch Linux**: For linux-zen kernel
- **archzfs**: For original build infrastructure
- **Community**: For testing and feedback
