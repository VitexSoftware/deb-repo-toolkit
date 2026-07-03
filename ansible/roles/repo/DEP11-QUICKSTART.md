# DEP-11 Quick Start Guide

## What Changed?

DEP-11 (AppStream) metadata generation is now fully integrated into the repository publishing workflow. When you publish packages, DEP-11 metadata is automatically generated.

## For Immediate Use

### Example Org Repository

**Server**: build-host.example.com  
**URL**: https://repo.example.com/

```bash
# Republish repository with DEP-11 generation
ansible-playbook --extra-vars "repo_user=jenkins repo_action=republish" \
  playbooks/local-repo-republish.yml
```

### MultiFlexi Repository

**Server**: build-host.example.com  
**URL**: https://repo.multiflexi.eu/

```bash
# Republish repository with DEP-11 generation
ansible-playbook --extra-vars "repo_user=multirepo repo_action=republish" \
  playbooks/multiflexi-repo-republish.yml
```

## What Gets Generated?

After running the playbook, you'll find:

```
/var/www/html/repo.example.com/
├── dists/
│   ├── bookworm/
│   │   └── main/
│   │       └── dep11/
│   │           ├── Components-amd64.yml.gz
│   │           ├── Components-i386.yml.gz
│   │           └── icons-*.tar.gz
│   ├── trixie/...
│   └── forky/...
└── dep11/
    ├── media/          # Screenshots, app icons
    └── html/           # Browsable index
```

## Verify It Works

```bash
# Check metadata was generated
ls -lh /var/www/html/repo.example.com/dists/bookworm/main/dep11/

# Validate metadata (on target machine with repo)
appstreamcli validate \
  /var/www/html/repo.example.com/dists/bookworm/main/dep11/Components-amd64.yml.gz
```

## Jenkins Integration

The Jenkins pipeline at `/home/YOUR_USER/Projects/YourOrg/your-project Org/DebianRepository/rebuild.Jenkinsfile` now:

1. Runs `ansible-playbook ... local-repo-republish.yml`
2. Ansible automatically generates DEP-11 metadata
3. No manual intervention needed

## Configuration Files

Generated and managed by Ansible:

- `/etc/aptly.conf` - Aptly configuration
- `/mnt/aptly/asgen/asgen-config.json` - AppStream generator config
- `/var/lib/jenkins/asgen-config.json` - Legacy location (can be removed)

## Troubleshooting Quick Tips

### No metadata generated?

```bash
# Check if appstream-generator is installed
which appstream-generator

# Check for packages with desktop files
sudo -u jenkins aptly repo search bookworm-main-myrepo '$PackageType (desktop)'
```

### Generation failed?

```bash
# Re-run with verbose output
ansible-playbook -vvv --extra-vars "repo_user=jenkins repo_action=republish" \
  playbooks/local-repo-republish.yml
```

### Clean and regenerate?

```bash
# Clean AppStream cache
sudo -u jenkins appstream-generator cleanup \
  --config /mnt/aptly/asgen/asgen-config.json

# Then republish
ansible-playbook --extra-vars "repo_user=jenkins repo_action=republish" \
  playbooks/local-repo-republish.yml
```

## What Packages Benefit?

Packages that include:
- Desktop application files (`.desktop`)
- AppStream metadata XML files
- Application icons
- Font information

Examples: GUI applications, fonts, icon themes, games

## Impact on Users

Users running:
- GNOME Software
- KDE Discover
- Ubuntu Software Center

Will see:
- ✅ Rich application descriptions
- ✅ Screenshots
- ✅ Category browsing
- ✅ Better search results

No user configuration needed - APT handles it automatically!

## Next Steps

1. Test the playbook on your setup
2. Monitor first generation (may take 10-30 mins)
3. Check generated metadata
4. Monitor disk space usage

## Performance Notes

- **First run**: 10-30 minutes (downloads icons, processes packages)
- **Subsequent runs**: 5-10 minutes (cached data)
- **Disk space**: ~200-500 MB per distribution

## Support

Full documentation: [DEP11-README.md](DEP11-README.md)

Issues? Check:
1. Ansible playbook output
2. Jenkins job logs
3. `/var/log/syslog` for appstream-generator errors
