# Automated Package Updates

This repository uses GitHub Actions to automatically keep the `zfs-linux-zen` AUR package synchronized with upstream releases.

## Overview

The `zfs-linux-zen` package depends on two separate upstream sources that update independently:

1. **OpenZFS** - The source code for ZFS filesystem modules
2. **linux-zen** - The Arch Linux zen kernel that ZFS modules must be compiled against

This automation ensures the package stays in sync with both upstreams, preventing the common issue of kernel/module version mismatches.

## How It Works

### Automated Updates (Every 6 Hours)

The [`auto-update.yml`](.github/workflows/auto-update.yml) workflow runs automatically every 6 hours and:

1. **Checks upstream versions**:
   - Queries the [Arch Linux package API](https://archlinux.org/packages/extra/x86_64/linux-zen/json/) for the latest `linux-zen` kernel version
   - Queries the [OpenZFS GitHub API](https://api.github.com/repos/openzfs/zfs/releases/latest) for the latest ZFS release

2. **Compares with current versions** in `PKGBUILD`

3. **If updates are available**:
   - Downloads the new ZFS tarball and calculates its SHA256 checksum
   - Updates `PKGBUILD` with new versions and checksum
   - Generates updated `.SRCINFO`
   - Commits changes with message: `Automated update for kernel X.X.X + zfs Y.Y.Y`
   - Pushes to the repository

4. **If no updates needed**: Completes silently

### Manual Updates

The [`manual-update.yml`](.github/workflows/manual-update.yml) workflow can be triggered manually for:

- **Testing** the automation before enabling automatic mode
- **Emergency updates** when you need immediate synchronization
- **Specific version targeting** when you want to pin particular versions

#### Usage

1. Go to **Actions** → **Manual Update**
2. Click **Run workflow**
3. Optional inputs:
   - **ZFS version**: Specify a particular ZFS version (e.g., `2.3.3`)
   - **Kernel version**: Specify a particular kernel version (e.g., `6.15.2.zen1-1`)
   - **Dry run**: Preview changes without committing

## Components

### Reusable Action

[`.github/actions/update-zfs-package/`](.github/actions/update-zfs-package/) - A reusable composite action that can be used in multiple ZFS package repositories:

- **Generic Design**: Supports both `zfs-linux-zen` and `zfs-utils` packages
- **Auto-Detection**: Automatically detects package type from PKGBUILD
- **Portable**: Can be copied to other repositories
- **Configurable**: Accepts package-type parameter for explicit control

See [REUSABLE_ACTION.md](REUSABLE_ACTION.md) for detailed usage in multiple repositories.

### Legacy Update Script

[`scripts/update-package.sh`](scripts/update-package.sh) - Original standalone script (deprecated in favor of reusable action):

- `get_latest_kernel_version()` - Fetches latest linux-zen version from Arch repos
- `get_latest_zfs_version()` - Fetches latest OpenZFS release from GitHub
- `get_zfs_sha256()` - Downloads tarball and calculates checksum
- `update_pkgbuild()` - Updates PKGBUILD file with new versions
- `generate_srcinfo()` - Regenerates .SRCINFO metadata

The script is idempotent and safe to run multiple times.

### GitHub Actions Workflows

- **auto-update.yml**: Scheduled automation (runs every 6 hours)
- **manual-update.yml**: On-demand updates with custom parameters

Both workflows:
- Run on Ubuntu latest
- Install required dependencies (jq, curl)
- Configure git for automated commits
- Create workflow summaries for visibility

## Monitoring

### Check Status

1. **GitHub Actions tab**: View recent workflow runs
2. **Commits**: Look for automated commit messages
3. **Workflow summaries**: Each run creates a summary showing:
   - Whether updates were needed
   - Current versions
   - Any errors encountered

### Notifications

- **Success**: Silent (no notification)
- **Failure**: Workflow marked as failed, visible in Actions tab
- **Updates**: New commit appears in repository history

## Schedule

The automation runs on this schedule:

```
0 */6 * * *  (Every 6 hours: 00:00, 06:00, 12:00, 18:00 UTC)
```

This provides:
- **4 checks per day** for rapid update detection
- **Low resource usage** (each run takes ~30-60 seconds)
- **Balance** between freshness and API rate limits

## Customization

### Change Update Frequency

Edit `.github/workflows/auto-update.yml`:

```yaml
schedule:
  # Every 3 hours
  - cron: '0 */3 * * *'

  # Every 12 hours
  - cron: '0 */12 * * *'

  # Daily at midnight UTC
  - cron: '0 0 * * *'
```

### Disable Automation

To temporarily disable automatic updates:

1. Go to **Settings** → **Actions** → **General**
2. Disable workflow: `Auto Update Package`

Or delete/rename `.github/workflows/auto-update.yml`

### Add Notifications

You can extend the workflows to send notifications:

**Slack/Discord**: Add webhook notification step
**Email**: Use GitHub's notification settings
**Issues**: Create an issue on update failures

Example (add to workflow):
```yaml
- name: Notify on update
  if: steps.check_changes.outputs.has_changes == 'true'
  run: |
    curl -X POST https://hooks.slack.com/services/YOUR/WEBHOOK/URL \
      -H 'Content-Type: application/json' \
      -d '{"text": "ZFS package updated to kernel ${{ env.KERNEL_VERSION }}"}'
```

## Troubleshooting

### Updates Not Happening

1. **Check workflow is enabled**: Actions tab → Auto Update Package
2. **Check workflow runs**: Look for errors in recent runs
3. **Check API rate limits**: GitHub API allows 60 requests/hour for unauthenticated requests
4. **Manual trigger**: Run manual-update workflow to test

### Build Failures After Update

If the updated package fails to build:

1. **Check kernel availability**: Ensure linux-zen is available in repos
2. **Check ZFS compatibility**: Some ZFS versions may not support newest kernels yet
3. **Check AUR comments**: Other users may report similar issues
4. **Revert commit**: `git revert HEAD` and push

### Script Errors

Common issues:

- **jq not found**: Install jq on your system
- **makepkg not found**: Normal in GitHub Actions (we handle this gracefully)
- **curl failures**: Network issues or API downtime
- **Permission denied**: Ensure script is executable: `chmod +x scripts/update-package.sh`

## Manual Operation

To run the update script locally:

```bash
# Make executable
chmod +x scripts/update-package.sh

# Run update check
./scripts/update-package.sh

# Check what changed
git diff PKGBUILD
```

## Benefits

This automation provides:

1. **Rapid updates**: Package stays in sync within 6 hours of upstream releases
2. **Reduced breakage**: Eliminates long periods of version mismatch
3. **No manual intervention**: Fully automated commit and push
4. **Transparency**: All updates visible in git history
5. **Reliability**: Runs on GitHub's infrastructure
6. **Zero cost**: Free for public repositories

## Migration from Previous System

This replaces the semi-automated external buildbot approach with:

- **Self-contained**: All logic in this repository
- **Transparent**: Anyone can see/modify the automation
- **Faster**: Checks 4x per day instead of ~monthly
- **Maintainable**: Standard GitHub Actions, no external dependencies

The commit message format remains similar for continuity:
```
Automated update for kernel X.X.X + zfs Y.Y.Y
```

## Security Considerations

- **Automated commits**: Bot commits are signed with GitHub Actions bot identity
- **No credentials needed**: Uses GitHub's built-in GITHUB_TOKEN
- **Read-only APIs**: Only reads from public Arch/GitHub APIs
- **Checksum verification**: Downloads and verifies ZFS tarball checksums
- **Limited permissions**: Workflow only has `contents: write` permission

## Contributing

To improve the automation:

1. Fork the repository
2. Modify scripts or workflows
3. Test with manual-update workflow
4. Submit pull request

Suggested improvements:
- Add notification integrations
- Improve error handling
- Add build testing before commit
- Create AUR package submission automation
