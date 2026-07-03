# Dynamic Component Selection Feature

## Overview

The repository index page now intelligently shows only the components that are available for each distribution, preventing users from selecting invalid component combinations.

## Problem Statement

Previously, the component selection interface showed all possible components (main, backports, borrowed, games, paid) regardless of which distribution was selected. This led to:

- Users potentially selecting unavailable components
- Confusing error messages when trying to use non-existent repository configurations
- Example: "borrow" distribution doesn't provide "borrowed" component, but it was shown as an option

## Solution

### 1. Backend Changes (`roles/services/repo/tasks/publish.yml`)

Added a new task to extract distribution-component mapping from the `repos` variable:

```yaml
- name: Build distribution-component mapping
  ansible.builtin.set_fact:
    distro_components: >-
      {%- set result = {} -%}
      {%- for endpoint in repos -%}
        {%- for ep_name, families in endpoint.items() -%}
          {%- if ep_name == publish_endpoint -%}
            {%- for family in families -%}
              {%- for family_name, suites in family.items() -%}
                {%- for suite_obj in suites -%}
                  {%- for suite_name, comps in suite_obj.items() -%}
                    {%- set components = ['main'] -%}
                    {%- if comps is iterable and comps is not string -%}
                      {%- set _ = components.extend(comps) -%}
                    {%- endif -%}
                    {%- set _ = result.update({suite_name: components}) -%}
                  {%- endfor -%}
                {%- endfor -%}
              {%- endfor -%}
            {%- endfor -%}
          {%- endif -%}\n        {%- endfor -%}
      {%- endfor -%}
      {{ result }}
```

This task:
- Iterates through the `repos` variable structure
- Extracts which components are available for each distribution
- Creates a dictionary mapping distribution names to their available components
- Passes this to the template as `distro_components`

### 2. Frontend Changes (`roles/services/repo/templates/README-bootstrap5.html.j2`)

#### A. Added Component Wrappers

Each optional component is now wrapped in a container with a unique ID:

```html
<div class="col-md-3" id="compBackportsWrapper" style="display: none;">
  <div class="form-check">
    <input ... id="compBackports" value="backports" ...>
    <label ...>backports</label>
  </div>
</div>
```

Components added:
- `compBackportsWrapper` - for "backports" component
- `compBorrowedWrapper` - for "borrowed" component
- `compGamesWrapper` - for "games" component
- `compPaidWrapper` - for "paid" component (new)

#### B. JavaScript Integration

**1. Injected Component Mapping:**
```javascript
const distroComponents = {{ distro_components | default({}) | tojson }};
```

**2. New Function: `updateComponentVisibility()`**
```javascript
function updateComponentVisibility(availableComponents) {
  // Hide all optional components first
  // Then show only those available for the selected distribution
  // Uncheck hidden components to prevent invalid selections
}
```

**3. Updated `updateConfigPreview()` Function:**
```javascript
// Get available components for this distribution
const availableComponents = distroComponents[distro] || ['main'];

// Show/hide component checkboxes based on availability
updateComponentVisibility(availableComponents);
```

**4. Enhanced Component Collection:**
```javascript
// Only collect components that are visible
if (compBackports && compBackports.checked && 
    compBackports.parentElement.parentElement.style.display !== 'none') {
  components.push('backports');
}
```

## Example Behavior

### Example Org Repository

**Distribution: bookworm**
- Available: main, backports, borrowed, games
- UI shows: ✓ main, □ backports, □ borrowed, □ games

**Distribution: borrow**
- Available: main, games
- UI shows: ✓ main, □ games
- Hidden: backports, borrowed

### MultiFlexi Repository

**Distribution: bookworm**
- Available: main, paid
- UI shows: ✓ main, □ paid
- Hidden: backports, borrowed, games

**Distribution: forky**
- Available: main, paid
- UI shows: ✓ main, □ paid
- Hidden: backports, borrowed, games

## Configuration Sources

The component availability is derived from repository configuration files:

- **Example Org**: `vars/myrepo-repo.yml`
- **MultiFlexi**: `vars/multiflexi-repo.yml`

Example from `myrepo-repo.yml`:
```yaml
repo_logo: "/home/YOUR_USER/Projects/YourOrg/your-project Org/v.s.cz/img/thelaststudent.png"
repos:
  - myrepo:
      - debian:
          - bookworm:
              - backports
              - borrowed
              - games
          - borrow:
              - games
```

### Repository Logo

Each repository can now have a custom logo displayed in the footer:

- **Example Org**: Uses "The Last Student" character image (PNG)
- **MultiFlexi**: Uses MultiFlexi project logo (SVG)

The logo is automatically copied to the repository public directory and displayed in the footer with inverted colors for contrast.

## User Experience Flow

1. User visits repository index page
2. User selects a distribution from dropdown (e.g., "borrow")
3. JavaScript looks up available components: `distroComponents['borrow']` → `['main', 'games']`
4. UI dynamically shows only "main" (always required, checked) and "games"
5. Other components (backports, borrowed, paid) are hidden
6. User can only select valid components
7. Generated APT configuration is guaranteed to be correct

## Benefits

1. **Prevents User Errors**: Users cannot select unavailable components
2. **Cleaner UI**: Only relevant options are shown
3. **Better UX**: No confusion about which components are available
4. **Maintainable**: Component availability is automatically derived from `repos` variable
5. **Flexible**: Adding new components requires only updating the `repos` variable
6. **Self-Documenting**: The UI itself shows what's available for each distribution

## Testing

### Manual Testing

1. Deploy updated playbook:
   ```bash
   ansible-playbook playbooks/local-repo-republish.yml
   # or
   ansible-playbook playbooks/multiflexi-repo-republish.yml
   ```

2. Open repository index page in browser

3. Test different distributions:
   - Select "bookworm" → verify backports, borrowed, games appear
   - Select "borrow" → verify only games appears (not borrowed)
   - Select "forky" → verify paid appears (if MultiFlexi repo)

4. Verify component selection:
   - Check a visible component
   - Change distribution
   - Verify previously checked component is unchecked if not available in new distribution

### Browser Console Testing

```javascript
// Check component mapping is loaded
console.log(distroComponents);

// Test component visibility function
updateComponentVisibility(['main', 'games']);
// Should show games, hide backports/borrowed/paid

updateComponentVisibility(['main', 'paid']);
// Should show paid, hide backports/borrowed/games
```

## Rollback

If issues occur, revert these files:
```bash
git checkout HEAD^ -- roles/services/repo/tasks/publish.yml
git checkout HEAD^ -- roles/services/repo/templates/README-bootstrap5.html.j2
```

Then re-run the publish playbook.

## Future Enhancements

1. **Component Descriptions**: Add tooltips explaining what each component contains
2. **Component Icons**: Different icons for different component types
3. **Component Counts**: Show package count per component
4. **Auto-Select Common**: Auto-check commonly used components for a distribution
5. **Remember Preferences**: Use localStorage to remember user's component preferences

## Related Documentation

- [DEP-11 Icon Integration](DEP11-ICON-INTEGRATION.md)
- [DEP-11 README](DEP11-README.md)
- [Repository Architecture](../../../WARP.md#repository-architecture-and-package-flow)
