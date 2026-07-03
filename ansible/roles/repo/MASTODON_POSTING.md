# Enhanced Mastodon Posting for Repository Updates

## Overview

The `post-to-mastodon.yml` subtask now includes enhanced functionality to:
1. **Compare snapshots** to identify new/updated packages
2. **Extract package names and versions** from snapshot differences
3. **Find package icons/logos** from DEP-11 metadata
4. **Post with up to 4 images** attached to the toot

## How It Works

### 1. Snapshot Package List Storage

When creating each aptly snapshot, the package list is saved as JSON:

```bash
# Stored in: {repo_home}/.snapshot-metadata/{snapshot_name}.json
[
  {"name": "package-name", "version": "1.2.3~bookworm"},
  ...
]
```

This happens automatically during the snapshot creation phase.

### 2. Package Comparison

The Mastodon posting task compares stored JSON files:

- Finds all `*_{{ today }}.json` files
- Finds all `*_{{ yesterday }}.json` files (if they exist)
- Merges and compares using `jq`
- Identifies packages that are new or have different versions

### 3. Package Information Format

Packages are stored and compared in JSON format:
```json
{
  "name": "multiflexi",
  "version": "2.5.3~bookworm"
}
```

The comparison detects:
- **New packages**: Present in today but not in yesterday
- **Updated packages**: Same package name but different version
- **Unchanged packages**: Same name and version (excluded from toot)

### 4. Icon Discovery from DEP-11 Metadata

The task searches for package icons in the AppStream/DEP-11 metadata:

- Location: `{{ repo_home }}/asgen/export/data/`
- Searches YAML files (compressed or uncompressed)
- Looks for `Icon: cached:` entries for each package
- Finds icon files in `{{ repo_home }}/asgen/export/media/`
- Limits to maximum of 4 icons (Mastodon limit)

### 5. Posting to Mastodon

Two posting modes:

**With images** (when icons are found):
```bash
toot post -v unlisted -m /path/to/icon1.png -m /path/to/icon2.png ...
```

**Without images** (fallback):
```bash
toot post -v unlisted
```

## Post Format

### With Package Updates

```
🎉 Repository updated: repo.example.com

📦 New/Updated packages:
• multiflexi 2.5.3
• php-myrepo-ease-core 1.48.2
• multiflexi-cli 2.2.1
• php-ease-twbootstrap4 1.16.0
...
(up to 50 packages shown)
... and 5 more

🔗 http://repo.example.com/

#Debian #Ubuntu #Repository #OpenSource
```

### Without Package Updates

```
🎉 Repository updated: repo.example.com

📦 12 distributions available

🔗 http://repo.example.com/

#Debian #Ubuntu #Repository #OpenSource
```

## Configuration

### Character Limit

The task is configured for the f.cz Mastodon instance which supports 2000 characters per post (vs standard 500).

- **Packages displayed**: Up to 50 packages
- **Packages analyzed**: Up to 60 packages from snapshot diff
- **Average package line**: ~40 characters ("• package-name version")
- **Estimated usage**: ~2000 chars with 50 packages + header + footer

To adjust for different Mastodon instances with different limits:

**Standard Mastodon (500 chars):**
```yaml
# Change in post-to-mastodon.yml line 128
{% for pkg in new_packages[:10] %}  # Show 10 packages max

# Change in post-to-mastodon.yml line 46 and 52
head -15  # Extract 15 packages max
```

**Custom instance:**
Calculate based on: `(char_limit - 200) / 40 = max_packages`

## Requirements

### jq (JSON processor)

The comparison logic requires `jq` to be installed:

```bash
apt-get install jq
```

### toot CLI Tool

The Mastodon posting requires the `toot` command to be installed and configured for the repository user.

Installation:
```bash
pip install toot
# or
apt-get install toot
```

Configuration (run as repo user):
```bash
toot login
```

### DEP-11 Metadata Generation

For package icons to be found, DEP-11 metadata must be generated. This is already configured in the `publish.yml` task:

```yaml
- name: Generate DEP-11 metadata
  ansible.builtin.include_tasks: "subtask/generate-dep11.yml"
```

The metadata includes:
- Package metadata YAML files
- Icon files (cached screenshots)
- Screenshots and other media

## Variables Used

| Variable | Description | Example |
|----------|-------------|---------|
| `repo_user` | User running the repository | `jenkins`, `multirepo` |
| `repo_home` | Repository home directory | `/var/lib/jenkins` |
| `repo_domain` | Public repository domain | `repo.example.com` |
| `today` | Current date for snapshot naming | `2026-01-25` |
| `distro_list` | List of distributions | `['bookworm', 'trixie', ...]` |

## Debugging

### Check if toot is available
```bash
which toot
```

### List today's snapshots
```bash
aptly snapshot list -raw | grep $(date +%Y-%m-%d)
```

### Compare snapshots manually
```bash
aptly snapshot diff snapshot-2026-01-24 snapshot-2026-01-25
```

### Find package icons
```bash
# List DEP-11 data
ls -la /var/lib/jenkins/asgen/export/data/

# Search for a specific package icon
grep -r "ID: multiflexi" /var/lib/jenkins/asgen/export/data/

# Check media files
ls -la /var/lib/jenkins/asgen/export/media/
```

## Limitations

1. **Maximum 4 images**: Mastodon allows up to 4 media attachments per post
2. **Only cached icons**: Only uses icons already cached in DEP-11 metadata
3. **First snapshot only**: Compares only the first snapshot of today vs yesterday
4. **Maximum 50 packages displayed**: Lists up to 50 packages in the toot (shows "... and X more" if more)
5. **Maximum 60 packages analyzed**: Extracts up to 60 changed packages for analysis
6. **2000 character limit**: Configured for f.cz Mastodon instance (2000 char limit vs standard 500)

## Troubleshooting

### No packages listed in toot

**Possible causes:**
- No snapshots created today
- No snapshot from yesterday to compare
- Snapshot comparison failed

**Solution:**
Check snapshot creation and ensure the snapshot task runs before posting.

### No icons attached

**Possible causes:**
- DEP-11 metadata not generated
- Packages don't have icons in their metadata
- Icon files not present in media directory

**Solution:**
Verify DEP-11 metadata generation is enabled and working.

### Toot fails to post

**Possible causes:**
- `toot` not configured for the repo user
- Network connectivity issues
- Mastodon instance down

**Solution:**
Check toot configuration and test manually:
```bash
sudo -u jenkins toot post "Test message"
```

## CI/CD Integration

The task is designed to work seamlessly with Jenkins and Semaphore CI/CD pipelines.

### Console Output

The task displays the toot content and result directly in the pipeline logs:

```
TASK [Display toot content for CI/CD logs]
========================================
MASTODON POST CONTENT:
========================================
🎉 Repository updated: repo.example.com

📦 New/Updated packages:
• multiflexi 2.5.3
• php-myrepo-ease-core 1.48.2
...

🔗 http://repo.example.com/

#Debian #Ubuntu #Repository #OpenSource
========================================

TASK [Display media attachments for CI/CD logs]
Media attachments: ["/var/lib/jenkins/asgen/export/media/64x64/multiflexi.png", ...]

TASK [Display toot result]
========================================
MASTODON POST RESULT:
========================================
https://f.cz/@myrepo/115956169652841462
========================================
```

This allows developers to:
- Verify what was posted without accessing Mastodon
- Debug issues with package detection
- See which icons were attached
- Get the direct URL to the post

## Example Workflow

1. Repository packages are built and added to aptly repositories
2. Snapshot task creates today's snapshots (`snapshot.yml`)
3. Publish task publishes snapshots (`publish.yml`)
4. DEP-11 metadata is generated (`generate-dep11.yml`)
5. Post-to-Mastodon task runs:
   - Compares today's snapshot with yesterday's
   - Extracts new/updated packages
   - Finds package icons from DEP-11 data
   - **Displays toot content in CI/CD logs**
   - Posts to Mastodon with package list and icons
   - **Displays result URL in CI/CD logs**
6. Users see the update on Mastodon with visual icons
7. Developers see the post content/URL in Jenkins/Semaphore logs

## Future Enhancements

Potential improvements:
- Support for multiple snapshot comparisons (not just first one)
- Package descriptions in the toot
- Links to package pages on example.com
- Configurable package count limits
- Support for video/screenshot attachments
- Threading for large updates (split into multiple toots)
