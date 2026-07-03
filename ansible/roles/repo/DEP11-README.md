# DEP-11 Metadata Support

## Overview

This repository role now supports automatic generation of DEP-11 (AppStream) metadata for Debian packages. DEP-11 provides machine-readable metadata about software components, enabling software centers and package managers to display rich information about applications.

### Managed Repositories

This role manages two repositories:

1. **Example Org Repository**
   - URL: https://repo.example.com/
   - Server: build-host.example.com
   - User: jenkins
   - Home: /mnt/aptly
   - Public: /var/www/html/repo.example.com

2. **MultiFlexi Repository**
   - URL: https://repo.multiflexi.eu/
   - Server: build-host.example.com
   - User: multirepo
   - Home: /var/lib/multirepo
   - Public: /var/lib/multirepo/public/multiflexi

## What is DEP-11?

DEP-11 is the Debian implementation of the AppStream specification. It provides:
- Application screenshots
- Application descriptions and metadata
- Category information
- Desktop files information
- Icon information
- Font metadata

## Architecture

### Components

1. **appstream-generator**: Generates DEP-11 metadata from package contents
2. **Aptly**: Debian repository manager (configured to support DEP-11)
3. **Ansible role**: Automates the entire process

### Icon serving — imgdeb/

After media files are copied, the role creates a **flat icon directory** at
`{{ repo_home }}/public/imgdeb/` by symlinking every `64x64` AppStream icon
as `<pkgname>.png`. Because Apache serves the whole `{{ repo_home }}/public/`
tree, icons are then accessible at `https://{{ repo_domain }}/imgdeb/<pkgname>.png`
— the URL used by the repository web UI (`README.html` / `index.html`).

This applies to **all** endpoints (myrepo and multiflexi alike).

### Directory Structure

```
{{ repo_home }}/
├── asgen/
│   ├── asgen-config.json       # AppStream generator configuration
│   ├── cache/                  # Temporary cache data
│   └── export/                 # Generated metadata (before publishing)
│
└── public/
    ├── imgdeb/                  # Flat icon dir: <pkgname>.png symlinks (all endpoints)
    └── {{ publish_endpoint }}/
        ├── dists/
        │   └── [distribution]/
        │       └── [component]/
        │           ├── dep11/      # DEP-11 metadata files
        │           │   ├── Components-[arch].yml.gz
        │           │   └── icons-[resolution].tar.gz
        │           └── binary-[arch]/
        └── media/               # Application screenshots and icons
```

## Configuration

### Variables Required

From `vars/myrepo-repo.yml` or `vars/multiflexi-repo.yml`:

```yaml
repo_user: jenkins              # User running the repository
repo_home: /mnt/aptly          # Home directory for aptly data
repo_public: /var/www/html/... # Public repository root
repo_domain: repo.example.com  # Domain name for the repository
repo_keyword: myrepo    # Repository identifier
publish_endpoint: myrepo # Aptly publish endpoint name
repos: [...]                    # Repository structure definition
repo_architectures: [...]       # Supported architectures
```

## Usage

### Automatic Generation

DEP-11 metadata is automatically generated when you run the publish playbook:

```bash
ansible-playbook --extra-vars "repo_user=jenkins" playbooks/local-repo-republish.yml
```

Or for MultiFlexi repository:

```bash
ansible-playbook --extra-vars "repo_user=multirepo" playbooks/multiflexi-repo-republish.yml
```

### Manual Generation

To regenerate DEP-11 metadata without republishing packages:

```bash
# Generate configuration
ansible-playbook -i inventory playbooks/site.yml \
  --tags dep11 \
  --extra-vars "repo_user=jenkins"

# Or run appstream-generator directly on the target machine
sudo -u jenkins appstream-generator run \
  --config /mnt/aptly/asgen/asgen-config.json bookworm

sudo -u jenkins appstream-generator publish \
  --config /mnt/aptly/asgen/asgen-config.json bookworm
```

## Workflow

1. **Repository Publishing** (via Aptly)
   - Packages are published to distributions
   - Package indices are created

2. **Component discovery** (dynamic)
   - `distro_components` fact is derived from the `repos` vars structure
   - No hardcoded distribution or component names anywhere in the role

3. **DEP-11 Generation** (automatic, all endpoints)
   - AppStream generator scans published packages
   - Extracts desktop files, icons, screenshots
   - Generates DEP-11 YAML metadata
   - Compresses and signs metadata

4. **Metadata Publishing** (all endpoints)
   - DEP-11 files copied to `dists/[distribution]/[component]/dep11/`
   - Components iterated dynamically from `distro_components`
   - Media files rsynced to `public/[endpoint]/media/`

5. **Icon flattening** (all endpoints)
   - Each 64×64 AppStream icon is symlinked into `public/imgdeb/<pkgname>.png`
   - Enables the repository web UI to serve icons at `/imgdeb/<pkgname>.png`

## Files Generated

For each distribution and architecture:

- `Components-[arch].yml.gz` - Main metadata file
- `Components-[arch].yml.xz` - Alternative compression
- `icons-48x48.tar.gz` - Small icons (48x48)
- `icons-64x64.tar.gz` - Medium icons (64x64)
- `icons-128x128.tar.gz` - Large icons (128x128)

## Troubleshooting

### No metadata generated

Check if packages contain desktop files or AppStream metadata:
```bash
aptly repo search [repo-name] '$PackageType (desktop)'
```

### Generation errors

View logs:
```bash
journalctl -u jenkins -f
# or check appstream-generator output
```

### Missing dependencies

Ensure packages are installed:
```bash
apt install appstream-generator appstream gir1.2-appstream-1.0
```

### Cache issues

Clean AppStream cache:
```bash
sudo -u jenkins appstream-generator cleanup \
  --config /mnt/aptly/asgen/asgen-config.json
```

## Integration with Package Managers

### APT (Debian/Ubuntu)

DEP-11 metadata is automatically used by:
- GNOME Software
- KDE Discover
- Ubuntu Software Center
- apt-cache search (enhanced)

No client configuration needed - APT will automatically fetch and use DEP-11 metadata when available.

### Verification

Check if metadata is being used:
```bash
# List available components
appstreamcli search firefox

# Show detailed info
appstreamcli what-provides firefox

# Validate metadata
appstreamcli validate /var/www/html/repo.../dists/bookworm/main/dep11/Components-amd64.yml.gz
```

## Performance Considerations

- **Generation time**: 5-30 minutes per distribution (depends on package count)
- **Disk space**: ~100-500 MB per distribution for metadata and icons
- **Network**: Media files (screenshots) may require significant bandwidth

## Configuration Customization

Edit `roles/services/repo/templates/asgen-config.json.j2` to customize:

- Screenshot processing
- Icon theme
- Validation strictness
- Media download behavior

## References

- [DEP-11 Specification](https://dep-team.pages.debian.net/deps/dep11/)
- [AppStream Documentation](https://www.freedesktop.org/wiki/Distributions/AppStream/)
- [appstream-generator](https://github.com/ximion/appstream-generator)
- [Aptly Documentation](https://www.aptly.info/)

## Maintenance

### Regular tasks

1. Monitor disk space in `asgen/cache/`
2. Clean old cache periodically (automated)
3. Verify metadata generation in CI/CD logs
4. Update icon themes if needed

### Updates

AppStream generator is actively developed. Update regularly:
```bash
apt update && apt upgrade appstream-generator
```

## Support

For issues specific to:
- **AppStream generation**: Check appstream-generator logs
- **Repository publishing**: Check Aptly logs
- **Ansible role**: Review playbook output with `-vvv`
