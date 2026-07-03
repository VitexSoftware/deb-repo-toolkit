# DEP-11 Icon Integration in Repository Index

## Overview

The repository index page (`README-bootstrap5.html.j2`) now automatically displays DEP-11 AppStream icons before package names when available. This provides a visual representation of applications in the package browser.

## How It Works

### Icon Display Logic

1. **Primary Icon Source**: The template attempts to load icons from the DEP-11 media directory:
   ```
   {{ base_url }}/media/{{ pkgname }}/icons/64x64/{{ pkgname }}_{{ pkgname }}.png
   ```

2. **Fallback Mechanism**: If the icon image fails to load (404 or other error), the template automatically falls back to a Bootstrap icon (download icon).

3. **Icon Styling**: Icons are displayed at 32x32 pixels with rounded corners and proper spacing.

### Implementation Details

#### HTML Structure

Each package item now includes:
```html
<div class="package-item" data-package-name="{{ pkgname }}">
  <a href="..." class="package-link">
    <!-- Primary: DEP-11 icon -->
    <img src="{{ base_url }}/media/{{ pkgname }}/icons/64x64/{{ pkgname }}_{{ pkgname }}.png" 
         class="package-icon" 
         alt="{{ pkgname }} icon"
         onerror="this.style.display='none'; this.nextElementSibling.style.display='inline';">
    
    <!-- Fallback: Bootstrap icon -->
    <i class="bi bi-download package-icon fallback"></i> {{ pkg }}
  </a>
</div>
```

#### CSS Styling

```css
.package-icon {
  width: 32px;
  height: 32px;
  margin-right: 0.75rem;
  border-radius: 4px;
  object-fit: contain;
  flex-shrink: 0;
}

.package-icon.fallback {
  display: none;  /* Hidden by default, shown on image error */
}
```

#### JavaScript Search Integration

The search/highlighting functionality has been updated to preserve icon elements when highlighting matching packages:

- Icons (both image and fallback) are stored in dataset attributes on page load
- During search highlighting, icons are restored along with highlighted text
- Both icon types are preserved to maintain the fallback behavior

## DEP-11 Icon Structure

Icons are stored in the repository under:
```
{{ repo_public }}/media/{{ package_name }}/icons/
├── 48x48/
│   └── {{ package_name }}_{{ package_name }}.png
├── 64x64/   ← Used by index page
│   └── {{ package_name }}_{{ package_name }}.png
└── 128x128/
    └── {{ package_name }}_{{ package_name }}.png
```

The index page uses 64x64 icons as they provide good quality at the displayed size (32x32) for high-DPI displays.

## Icon Generation Workflow

1. **Package Build**: Packages include `.desktop` files and icons in standard locations
2. **DEP-11 Generation**: `appstream-generator` extracts icons during metadata generation
3. **Publishing**: Icons are copied to `{{ repo_public }}/media/` directory
4. **Web Display**: Index page automatically loads icons via `<img>` tags

## Requirements

### For Icons to Appear

1. **Packages must contain**:
   - Desktop files (`.desktop`) in `/usr/share/applications/`
   - Icon files in standard icon paths (`/usr/share/icons/`, `/usr/share/pixmaps/`)
   - Valid AppStream metadata (optional but recommended)

2. **Repository must have**:
   - DEP-11 metadata generation enabled (see `DEP11-README.md`)
   - `appstream-generator` installed and configured
   - Media directory symlinked to web root

3. **Web server must**:
   - Serve the `media/` directory publicly
   - Have proper CORS headers (if applicable)
   - Support HTTPS for the repository domain

## Testing Icon Display

### Manual Testing

1. **Check if icons exist**:
   ```bash
   ls -la {{ repo_public }}/media/multiflexi-cli/icons/64x64/
   ```

2. **Test icon accessibility**:
   ```bash
   curl -I {{ base_url }}/media/multiflexi-cli/icons/64x64/multiflexi-cli_multiflexi-cli.png
   ```

3. **Verify in browser**:
   - Open the repository index page
   - Right-click on a package icon → "Inspect"
   - Check if `<img>` element loaded successfully or fell back to `<i>` element

### Browser DevTools

In the browser console:
```javascript
// Check which packages have icons loaded
document.querySelectorAll('.package-icon:not(.fallback)').forEach(img => {
  console.log(img.alt, img.complete ? '✓' : '✗');
});

// Count successful vs fallback icons
console.log('Images:', document.querySelectorAll('.package-icon:not(.fallback)[style*="display: none"]').length);
console.log('Fallbacks:', document.querySelectorAll('.package-icon.fallback:not([style*="display: none"])').length);
```

## Troubleshooting

### Icons Not Appearing

1. **Check DEP-11 generation**:
   ```bash
   ls {{ repo_home }}/asgen/export/media/
   ```

2. **Verify media symlink**:
   ```bash
   ls -la {{ repo_public }}/media
   ```

3. **Check web server access**:
   ```bash
   curl -I {{ base_url }}/media/
   ```

### Icon Paths

The icon path follows this pattern:
```
/media/<package-name>/icons/<size>/<package-name>_<component-id>.png
```

For most packages, `<package-name>` equals `<component-id>`. If icons don't load, check the actual generated metadata:
```bash
zcat {{ repo_public }}/dists/bookworm/main/dep11/Components-amd64.yml.gz | grep -A20 "^Package: multiflexi-cli"
```

### Search Highlighting Issues

If icons disappear during search:
1. Check browser console for JavaScript errors
2. Verify that `link.dataset.originalImgIcon` is populated
3. Test with simple search queries first

## Component Selection Feature

As of the latest update, the repository index page now includes intelligent component selection:

### How It Works

1. **Automatic Detection**: The template receives a `distro_components` mapping from Ansible that defines which components are available for each distribution
2. **Dynamic UI**: When a user selects a distribution, only the components available for that distribution are shown
3. **User-Friendly**: Prevents users from selecting invalid component combinations (e.g., "borrowed" component for "borrow" distribution)

### Implementation

The `publish.yml` playbook extracts component information from the `repos` variable and passes it to the template as JSON:

```yaml
distro_components:
  bookworm: ['main', 'backports', 'borrowed', 'games']
  borrow: ['main', 'games']
  forky: ['main', 'paid']
```

JavaScript in the template uses this data to show/hide component checkboxes dynamically.

## Future Enhancements

Potential improvements:

1. **Lazy loading**: Use `loading="lazy"` for better performance with many packages
2. **Size optimization**: Generate WebP versions of icons for smaller file sizes
3. **Placeholder icons**: Show category-specific default icons when package icon is missing
4. **Icon caching**: Add cache headers for better performance
5. **High-DPI support**: Use `srcset` for 2x/3x displays
6. **Component descriptions**: Add tooltips explaining what each component contains

## References

- [DEP-11 Specification](https://dep-team.pages.debian.net/deps/dep11/)
- [AppStream Icon Guidelines](https://www.freedesktop.org/software/appstream/docs/chap-Metadata.html#tag-icon)
- [DEP-11 README](DEP11-README.md)
- [Repository Role Documentation](README.md)
