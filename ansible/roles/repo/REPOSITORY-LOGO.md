# Repository Logo Feature

## Overview

Each repository can now display a custom logo in the footer of the index page. The logo is automatically copied from a source path and displayed with inverted colors for better contrast against the gradient background.

## Configuration

### Variable Definition

Add the `repo_logo` variable to your repository configuration file:

**For Example Org Repository** (`vars/myrepo-repo.yml`):
```yaml
repo_logo: "/home/YOUR_USER/Projects/YourOrg/your-project Org/v.s.cz/img/thelaststudent.png"
```

**For MultiFlexi Repository** (`vars/multiflexi-repo.yml`):
```yaml
repo_logo: "/home/YOUR_USER/Projects/YourOrg/your-project"
```

### Logo File Requirements

- **Supported Formats**: PNG, SVG, JPG, GIF
- **Recommended Size**: 
  - Maximum height: 120px (displayed size)
  - Width: Proportional to height
  - File size: < 500KB for optimal loading
- **Color**: Any color works (will be inverted for display)
- **Location**: Must be accessible on the Ansible control machine

## Implementation

### Backend (`roles/services/repo/tasks/publish.yml`)

The publish task includes:

1. **Logo Copy Task**:
```yaml
- name: Copy repository logo to public directory
  ansible.builtin.copy:
    src: "{{ repo_logo }}"
    dest: "{{ repo_public }}/repo-logo{{ repo_logo | splitext | last }}"
    owner: "{{ repo_user }}"
    group: "www-data"
    mode: "0644"
  become: true
  when: repo_logo is defined
```

This task:
- Copies the logo from the source path
- Preserves the file extension (.png, .svg, etc.)
- Sets appropriate ownership and permissions
- Only runs when `repo_logo` is defined

2. **Logo Sync Task**:
```yaml
- name: Build list of files to sync
  ansible.builtin.set_fact:
    sync_files: "{{ ['index.html', 'README.html', 'KEY.asc', 'KEY.gpg'] + (['repo-logo' + (repo_logo | splitext | last)] if repo_logo is defined else []) }}"

- name: Sync HTML files and logo to public domain
  ansible.builtin.copy:
    src: "{{ repo_public }}/{{ item }}"
    dest: "/var/www/html/{{ repo_domain }}/{{ item }}"
    ...
  loop: "{{ sync_files }}"
```

This ensures the logo is synced to the public domain directory.

### Frontend (`roles/services/repo/templates/README-bootstrap5.html.j2`)

The template displays the logo in the footer:

```html
{% if repo_logo is defined %}
<div class="d-flex justify-content-center mb-3">
  <img src="{{ base_url }}/repo-logo{{ repo_logo | splitext | last }}" 
       alt="{{ publish_endpoint | title }} Repository Logo" 
       style="max-height: 120px; filter: brightness(0) invert(1); opacity: 0.9;" />
</div>
{% endif %}
```

Features:
- Conditional display (only if logo is defined)
- Dynamic extension based on source file
- CSS filter for color inversion and opacity
- Maximum height constraint
- Centered alignment

## Logo Files

### Example Org Repository

**File**: `/home/YOUR_USER/Projects/YourOrg/your-project Org/v.s.cz/img/thelaststudent.png`
- **Format**: PNG
- **Size**: 155KB
- **Description**: "The Last Student" character from Debian artwork
- **Theme**: Represents the Debian packaging work

### MultiFlexi Repository

**File**: `/home/YOUR_USER/Projects/YourOrg/your-project`
- **Format**: SVG
- **Size**: 4.8KB
- **Description**: MultiFlexi project logo
- **Theme**: Official MultiFlexi branding

## Visual Styling

The logo is displayed with these CSS properties:

```css
max-height: 120px;              /* Constrains logo height */
filter: brightness(0) invert(1); /* Converts to white for dark background */
opacity: 0.9;                    /* Slight transparency */
```

The footer has a gradient background:
```css
background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
```

The inversion filter ensures the logo appears white/light colored against this dark gradient background.

## Deployment

### Initial Setup

1. Ensure logo file exists at the specified path
2. Add `repo_logo` variable to repository config
3. Run the publish playbook:
   ```bash
   ansible-playbook playbooks/local-repo-republish.yml
   # or
   ansible-playbook playbooks/multiflexi-repo-republish.yml
   ```

### Updating Logo

To change the logo:

1. Update the source file at the path, or
2. Change the `repo_logo` variable to point to a new file
3. Re-run the publish playbook

The old logo will be overwritten automatically.

### Removing Logo

To remove the logo:

1. Comment out or remove the `repo_logo` variable
2. Re-run the publish playbook
3. Manually delete the old logo file from `{{ repo_public }}/` (optional)

## File Paths

After deployment, the logo is available at:

- **Example Org**: `http://repo.example.com/repo-logo.png`
- **MultiFlexi**: `https://repo.multiflexi.eu/repo-logo.svg`

## Troubleshooting

### Logo Not Appearing

1. **Check if logo file exists**:
   ```bash
   ls -lh /home/YOUR_USER/Projects/YourOrg/your-project Org/v.s.cz/img/thelaststudent.png
   ls -lh /home/YOUR_USER/Projects/YourOrg/your-project
   ```

2. **Verify logo was copied**:
   ```bash
   ls -lh /var/www/html/repo.example.com/repo-logo.*
   ls -lh /var/lib/multirepo/public/multiflexi/repo-logo.*
   ```

3. **Check web server access**:
   ```bash
   curl -I http://repo.example.com/repo-logo.png
   curl -I https://repo.multiflexi.eu/repo-logo.svg
   ```

4. **Verify in browser**: Open browser DevTools (F12) → Network tab → Look for repo-logo request

### Logo Appears Distorted

- Check the original file dimensions and aspect ratio
- Ensure the file is not corrupted
- Try a different image format (SVG is recommended for logos)

### Logo Color Issues

The CSS filter `brightness(0) invert(1)` works best with:
- Dark logos (will become light)
- High contrast logos
- Simple color schemes

If your logo has complex colors:
- Consider using an SVG with explicit white/light colors
- Pre-process the image to be white on transparent background
- Adjust the CSS filter values in the template

### Permission Issues

If the logo copy fails:

```bash
# Check ownership of source file
ls -l /home/YOUR_USER/Projects/YourOrg/your-project Org/v.s.cz/img/thelaststudent.png

# Check target directory permissions
ls -ld /var/www/html/repo.example.com/
```

## Integration with Other Features

The logo feature integrates seamlessly with:

- **DEP-11 Icons**: Package icons appear in package list, repository logo appears in footer
- **Component Selection**: Logo is visible regardless of selected distribution/components
- **Responsive Design**: Logo scales appropriately on mobile devices

## Best Practices

1. **Use SVG when possible**: Scalable, small file size, crisp at any resolution
2. **Optimize images**: Compress PNG/JPG files before using
3. **Test locally first**: Verify the logo looks good with inverted colors
4. **Version control**: Keep logo source files in a versioned location
5. **Backup**: Store original logo files in multiple locations

## Future Enhancements

Potential improvements:

1. **Logo variants**: Light/dark versions for different backgrounds
2. **Multiple logos**: Header logo, footer logo, favicon
3. **Dynamic sizing**: Responsive logo sizes based on viewport
4. **Logo animation**: Subtle hover effects or loading animations
5. **Logo cache**: CDN integration for faster loading

## Related Documentation

- [Component Selection Feature](COMPONENT-SELECTION-FEATURE.md)
- [DEP-11 Icon Integration](DEP11-ICON-INTEGRATION.md)
- [Repository Architecture](../../../WARP.md#repository-architecture-and-package-flow)
