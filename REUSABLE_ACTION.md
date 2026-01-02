# Reusable ZFS Package Update Action

This repository contains a reusable GitHub Action for automatically updating ZFS-related AUR packages. The action can be used in multiple repositories to keep different ZFS packages synchronized with upstream releases.

## Supported Package Types

The action automatically detects and supports:

1. **zfs-linux-zen**: Kernel modules for ZFS compiled against linux-zen kernel
   - Tracks: OpenZFS version + linux-zen kernel version
   - Updates when either upstream changes

2. **zfs-utils**: Userspace utilities for ZFS
   - Tracks: OpenZFS version only
   - Updates when OpenZFS releases new version

## Usage in Your Repository

### Option 1: Copy the Action (Recommended for Independent Repos)

Copy the entire `.github/actions/update-zfs-package/` directory to your repository:

```bash
# In your zfs-utils or other ZFS package repository
mkdir -p .github/actions
cp -r /path/to/zfs-linux-zen/.github/actions/update-zfs-package .github/actions/
```

Then use it in your workflows:

```yaml
- name: Update package
  uses: ./.github/actions/update-zfs-package
  with:
    package-type: auto  # or specify: zfs-utils, zfs-linux-zen
```

### Option 2: Reference from Another Repository

If this action is in a public repository, you can reference it directly:

```yaml
- name: Update package
  uses: owner/zfs-linux-zen/.github/actions/update-zfs-package@main
  with:
    package-type: auto
```

## Action Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `package-type` | Package type to update (`auto`, `zfs-linux-zen`, `zfs-utils`) | No | `auto` |
| `pkgbuild-path` | Path to PKGBUILD file | No | `./PKGBUILD` |

### Package Type Details

- **`auto`**: Automatically detects package type by inspecting PKGBUILD
  - Detects `pkgbase="zfs-linux-zen"` → uses zfs-linux-zen mode
  - Detects `pkgname.*zfs-utils` → uses zfs-utils mode

- **`zfs-linux-zen`**: Explicitly use zfs-linux-zen update logic
  - Checks both OpenZFS and linux-zen kernel versions
  - Updates PKGBUILD variables: `_zfsver`, `_kernelver`, `_kernelver_full`, `sha256sums`

- **`zfs-utils`**: Explicitly use zfs-utils update logic
  - Checks only OpenZFS version
  - Updates PKGBUILD variables: `pkgver` (or `_zfsver`), `sha256sums`

## Action Outputs

| Output | Description |
|--------|-------------|
| `updated` | Whether package was updated (`true`/`false`) |
| `up_to_date` | Whether package is already current (`true`/`false`) |
| `zfs_version` | ZFS version after update |
| `kernel_version` | Kernel version after update (zfs-linux-zen only) |
| `update_reason` | Human-readable summary of changes |

## Complete Workflow Examples

### For zfs-linux-zen Repository

```yaml
name: Auto Update

on:
  schedule:
    - cron: '0 */6 * * *'  # Every 6 hours
  workflow_dispatch:

permissions:
  contents: write

jobs:
  update:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Configure git
        run: |
          git config user.name "ZFS Auto Update Bot"
          git config user.email "github-actions[bot]@users.noreply.github.com"

      - name: Update package
        id: update
        uses: ./.github/actions/update-zfs-package
        with:
          package-type: zfs-linux-zen

      - name: Commit changes
        if: steps.update.outputs.updated == 'true'
        run: |
          git add PKGBUILD .SRCINFO
          git commit -m "Automated update for kernel ${{ steps.update.outputs.kernel_version }} + zfs ${{ steps.update.outputs.zfs_version }}"
          git push
```

### For zfs-utils Repository

```yaml
name: Auto Update

on:
  schedule:
    - cron: '0 */6 * * *'  # Every 6 hours
  workflow_dispatch:

permissions:
  contents: write

jobs:
  update:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Configure git
        run: |
          git config user.name "ZFS Auto Update Bot"
          git config user.email "github-actions[bot]@users.noreply.github.com"

      - name: Update package
        id: update
        uses: ./.github/actions/update-zfs-package
        with:
          package-type: zfs-utils

      - name: Commit changes
        if: steps.update.outputs.updated == 'true'
        run: |
          git add PKGBUILD .SRCINFO
          git commit -m "Automated update for zfs ${{ steps.update.outputs.zfs_version }}"
          git push
```

### Generic Auto-Detect Example

Works for any ZFS package:

```yaml
name: Auto Update

on:
  schedule:
    - cron: '0 */6 * * *'
  workflow_dispatch:

permissions:
  contents: write

jobs:
  update:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Configure git
        run: |
          git config user.name "ZFS Auto Update Bot"
          git config user.email "github-actions[bot]@users.noreply.github.com"

      - name: Update package
        id: update
        uses: ./.github/actions/update-zfs-package
        # No package-type specified - will auto-detect

      - name: Commit changes
        if: steps.update.outputs.updated == 'true'
        run: |
          git add PKGBUILD .SRCINFO 2>/dev/null || git add PKGBUILD

          # Smart commit message
          if [ -n "${{ steps.update.outputs.kernel_version }}" ]; then
            MSG="Automated update for kernel ${{ steps.update.outputs.kernel_version }} + zfs ${{ steps.update.outputs.zfs_version }}"
          else
            MSG="Automated update for zfs ${{ steps.update.outputs.zfs_version }}"
          fi

          git commit -m "$MSG"
          git push
```

## How It Works

### Update Detection Flow

```
1. Read current versions from PKGBUILD
2. Query upstream sources:
   - OpenZFS: GitHub API (latest release)
   - linux-zen: Arch Linux package API
3. Compare current vs latest versions
4. If different:
   a. Download new ZFS tarball
   b. Calculate SHA256 checksum
   c. Update PKGBUILD variables
   d. Generate .SRCINFO (if makepkg available)
   e. Set output variables for workflow
5. If same: Exit with up_to_date=true
```

### PKGBUILD Variables Updated

**For zfs-linux-zen:**
```bash
_zfsver="X.Y.Z"              # OpenZFS version
_kernelver="A.B.C.zenD-E"    # linux-zen version
_kernelver_full="A.B.C.zenD-E"
sha256sums=("...")           # ZFS tarball checksum
pkgrel=1                     # Reset to 1
```

**For zfs-utils:**
```bash
pkgver="X.Y.Z"              # OpenZFS version
# OR
_zfsver="X.Y.Z"             # If using variable
sha256sums=("...")          # ZFS tarball checksum
pkgrel=1                    # Reset to 1
```

## Dependencies

The action automatically installs:
- `jq` - JSON parsing
- `curl` - HTTP requests

No other dependencies required.

## Customization

### Modify Update Schedule

Edit the cron schedule in your workflow:

```yaml
on:
  schedule:
    - cron: '0 */3 * * *'   # Every 3 hours
    - cron: '0 0 * * *'     # Daily at midnight
    - cron: '0 */12 * * *'  # Every 12 hours
```

### Add Custom Logic

You can add custom steps before or after the update:

```yaml
- name: Update package
  id: update
  uses: ./.github/actions/update-zfs-package

- name: Run tests
  if: steps.update.outputs.updated == 'true'
  run: |
    # Your test commands here
    makepkg --syncdeps --noconfirm

- name: Notify on update
  if: steps.update.outputs.updated == 'true'
  run: |
    echo "Updated: ${{ steps.update.outputs.update_reason }}"
    # Send notification to Slack, Discord, etc.
```

### Override Behavior

You can modify the update script (`update.sh`) to add custom logic:

```bash
# Example: Add pre-update hooks
update_zen_package() {
    # Your custom pre-update logic
    run_custom_checks

    # Original update logic
    ...
}
```

## Deploying to Multiple Repositories

### Step 1: Copy Action to Each Repo

```bash
# For zfs-utils repository
cd /path/to/zfs-utils
mkdir -p .github/actions
cp -r /path/to/zfs-linux-zen/.github/actions/update-zfs-package .github/actions/

# For other ZFS packages
cd /path/to/zfs-dkms
mkdir -p .github/actions
cp -r /path/to/zfs-linux-zen/.github/actions/update-zfs-package .github/actions/
```

### Step 2: Create Workflow in Each Repo

Use one of the example workflows above, or copy the existing workflows:

```bash
# Copy workflows
cp .github/workflows/auto-update.yml /path/to/zfs-utils/.github/workflows/
cp .github/workflows/manual-update.yml /path/to/zfs-utils/.github/workflows/
```

### Step 3: Commit and Enable

```bash
cd /path/to/zfs-utils
git add .github/
git commit -m "Add automated update system"
git push
```

### Step 4: Verify

1. Go to repository **Actions** tab
2. Find "Auto Update Package" workflow
3. Click **Run workflow** to test
4. Check workflow summary for results

## Maintenance

### Updating the Action

When you improve the action in one repository:

1. Test changes thoroughly
2. Copy updated action to other repositories:
   ```bash
   cp -r .github/actions/update-zfs-package /path/to/other-repo/.github/actions/
   ```
3. Commit and push to each repository

### Syncing Between Repos

Consider creating a script to sync the action:

```bash
#!/bin/bash
# sync-action.sh - Sync update action across repos

SOURCE_REPO="$HOME/zfs-linux-zen"
TARGET_REPOS=(
    "$HOME/zfs-utils"
    "$HOME/zfs-dkms"
)

for repo in "${TARGET_REPOS[@]}"; do
    echo "Syncing to $repo..."
    cp -r "$SOURCE_REPO/.github/actions/update-zfs-package" "$repo/.github/actions/"
    cd "$repo"
    git add .github/actions/update-zfs-package
    git commit -m "Update reusable action from zfs-linux-zen"
    git push
done
```

## Troubleshooting

### Action Not Detecting Updates

- Check that upstream APIs are accessible
- Verify PKGBUILD format matches expected patterns
- Run manual workflow with dry-run to see what's detected

### Wrong Package Type Detected

Explicitly set `package-type` input:

```yaml
- uses: ./.github/actions/update-zfs-package
  with:
    package-type: zfs-utils  # Force specific type
```

### Checksum Mismatches

- Verify ZFS tarball URL is correct
- Check that sha256sum is installed
- Confirm network access to GitHub releases

### .SRCINFO Not Generated

This is normal if `makepkg` isn't available (e.g., on Ubuntu). The workflow will warn but continue. You can:

1. Install pacman/makepkg in workflow (complex)
2. Generate .SRCINFO manually after update
3. Ignore if not needed for your use case

## Benefits of Reusable Action

1. **DRY Principle**: Write once, use everywhere
2. **Consistent Updates**: Same logic across all ZFS packages
3. **Easy Maintenance**: Fix bugs in one place
4. **Flexible**: Auto-detects or explicit configuration
5. **Portable**: Copy to any repository easily

## Contributing

Improvements to the action benefit all ZFS package repositories:

1. Make changes to action code
2. Test in one repository
3. Deploy to other repositories
4. Share improvements with community

## License

Same as parent repository (CDDL).
