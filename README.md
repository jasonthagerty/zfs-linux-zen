# ZFS Linux-Zen - Automated Arch Linux Package

This repository provides automatically updated ZFS kernel modules for the Arch Linux `linux-zen` kernel.

## Features

- **Automatic Updates**: Checks for new OpenZFS and linux-zen releases every 6 hours
- **Kernel Tracking**: Automatically rebuilds when linux-zen kernel updates
- **Automated Building**: Builds and publishes packages automatically via GitHub Actions
- **GitHub Pages Hosting**: Packages hosted as a custom Arch repository

## Installation

### 1. Add the Repository

Add the following to `/etc/pacman.conf`:

```ini
[archzfs]
Server = https://jasonthagerty.github.io/zfs-utils/repo
Server = https://jasonthagerty.github.io/zfs-linux-zen/repo
SigLevel = Optional TrustAll
```

**Note**: Both repository URLs are required because `zfs-linux-zen` depends on `zfs-utils`.

### 2. Update Package Database

```bash
sudo pacman -Sy
```

### 3. Install ZFS

```bash
sudo pacman -S zfs-utils zfs-linux-zen
```

### 4. Load ZFS Module

```bash
sudo modprobe zfs
```

### 5. Enable ZFS Services (Optional)

```bash
sudo systemctl enable zfs-import-cache.service
sudo systemctl enable zfs-import.target
sudo systemctl enable zfs-mount.service
sudo systemctl enable zfs.target
```

## Packages Provided

- `zfs-linux-zen` - ZFS kernel modules for linux-zen
- `zfs-linux-zen-headers` - Development headers for ZFS modules

## Important Notes

### Kernel Dependency

This package is built specifically for the `linux-zen` kernel. The package version includes both:
- ZFS version (e.g., `2.4.0`)
- Kernel version (e.g., `6.18.3.zen1.1`)

**The kernel module must match your installed kernel version exactly.**

### Automatic Rebuilds

The automation checks for updates to:
1. OpenZFS releases (from GitHub)
2. Arch Linux `linux-zen` package version

When either updates, a new package is automatically built and published.

### Update Frequency

- **Check interval**: Every 6 hours
- **Build time**: ~10-15 minutes after update detected
- **Availability**: Packages available within 20 minutes of upstream release

## How It Works

### Automatic Updates

The repository uses GitHub Actions to:

1. **Check for Updates** (every 6 hours):
   - Queries GitHub API for latest OpenZFS release
   - Queries Arch repos for latest linux-zen version
   - Compares with current PKGBUILD versions
   - Updates PKGBUILD if either has a new version

2. **Build Package** (on PKGBUILD changes):
   - Installs linux-zen-headers
   - Installs zfs-utils from custom repository
   - Builds ZFS kernel modules
   - Creates repository database
   - Publishes to GitHub Pages

### Workflow Files

- `.github/workflows/auto-update.yml` - Automatic update checker (runs every 6 hours)
- `.github/workflows/manual-update.yml` - Manual update trigger
- `.github/workflows/build-and-publish.yml` - Package builder and publisher
- `.github/actions/update-zfs-package/` - Shared update action

## Repository Structure

```
zfs-linux-zen/
├── PKGBUILD                    # Package build script
├── zfs.install                 # Post-install hooks
└── .github/
    ├── workflows/
    │   ├── auto-update.yml
    │   ├── manual-update.yml
    │   └── build-and-publish.yml
    └── actions/
        └── update-zfs-package/
            ├── action.yml
            └── update.sh
```

## GitHub Pages Setup

To enable package hosting, you need to configure GitHub Pages:

1. Go to repository **Settings** → **Pages**
2. Under **Source**, select **GitHub Actions**
3. Save the settings

The first build will create the repository structure automatically.

## Manual Updates

You can manually trigger an update check:

1. Go to **Actions** tab
2. Select **Auto Update Package** workflow
3. Click **Run workflow**

Or force a package rebuild:

1. Go to **Actions** tab
2. Select **Build and Publish Package** workflow
3. Click **Run workflow**

## Troubleshooting

### Module Won't Load

```bash
# Check if module matches kernel version
modinfo zfs | grep vermagic
uname -r
```

If versions don't match, wait for automatic rebuild or manually trigger update.

### Build Failures

Check the Actions tab for build logs. Common issues:
- `zfs-utils` not available (build that repository first)
- Kernel headers version mismatch
- Upstream build issues

## Development

### Testing the Update Script Locally

```bash
cd .github/actions/update-zfs-package
./update.sh
```

### Building Locally

```bash
makepkg -s
```

**Note**: You need `linux-zen-headers` and `zfs-utils` installed to build locally.

## Upstream

This repository is a fork of [archzfs/archzfs](https://github.com/archzfs/archzfs) with enhanced automation for faster updates.

## License

CDDL (Common Development and Distribution License) - same as ZFS

## Related Repositories

- [zfs-utils](https://github.com/jasonthagerty/zfs-utils) - ZFS userspace utilities (required dependency)
