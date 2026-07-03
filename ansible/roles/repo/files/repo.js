/* Repo page — reads config injected by server via #repoConfig JSON block */
(function () {
  'use strict';

  var cfg = JSON.parse(document.getElementById('repoConfig').textContent);
  var distroComponents = cfg.distroComponents || {};
  var baseUrl          = cfg.baseUrl          || '';
  var repoKeyword      = cfg.repoKeyword      || '';

  var allPackages = [];
  var searchQuery = '';

  function escapeHtml(s) {
    return String(s)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  }

  function escapeRegExp(s) {
    return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  }

  /* ===== Search ===== */

  function collectPackages() {
    allPackages = [];
    document.querySelectorAll('.package-item').forEach(function (item) {
      var pkgname = item.dataset.packageName || '';
      if (pkgname) {
        allPackages.push({ element: item, name: pkgname, searchName: pkgname.toLowerCase() });
      }
    });
  }

  function filterPackages() {
    if (!searchQuery) {
      allPackages.forEach(function (pkg) {
        pkg.element.classList.remove('hidden');
        resetHighlight(pkg.element);
      });
    } else {
      allPackages.forEach(function (pkg) {
        if (pkg.searchName.includes(searchQuery)) {
          pkg.element.classList.remove('hidden');
          applyHighlight(pkg.element, searchQuery);
        } else {
          pkg.element.classList.add('hidden');
        }
      });
    }
    updateReleaseBadges();
    updateStats();
  }

  /* Per-release tab badges (e.g. "Trixie 520") show the filtered match count
     while searching, instead of always showing the release's full total. */
  function updateReleaseBadges() {
    document.querySelectorAll('[data-badge-for]').forEach(function (badge) {
      var pane = document.getElementById(badge.dataset.badgeFor);
      if (!pane) return;
      var visible = pane.querySelectorAll('.package-item:not(.hidden)').length;
      badge.textContent = visible;
    });
  }

  function resetHighlight(packageElement) {
    var nameEl = packageElement.querySelector('.package-name');
    if (!nameEl || !nameEl.dataset.originalText) return;
    nameEl.textContent = nameEl.dataset.originalText;
  }

  function applyHighlight(packageElement, query) {
    var nameEl = packageElement.querySelector('.package-name');
    if (!nameEl) return;

    if (!nameEl.dataset.originalText) {
      nameEl.dataset.originalText = nameEl.textContent.trim();
    }

    var origText  = nameEl.dataset.originalText;
    var lowerOrig = origText.toLowerCase();

    nameEl.textContent = '';
    var start = 0, idx;
    while ((idx = lowerOrig.indexOf(query, start)) !== -1) {
      if (idx > start) {
        nameEl.appendChild(document.createTextNode(origText.slice(start, idx)));
      }
      var mark = document.createElement('span');
      mark.className = 'search-highlight';
      mark.textContent = origText.slice(idx, idx + query.length);
      nameEl.appendChild(mark);
      start = idx + query.length;
    }
    if (start < origText.length) {
      nameEl.appendChild(document.createTextNode(origText.slice(start)));
    }
  }

  function updateStats() {
    var stats = document.getElementById('searchStats');
    if (!stats) return;

    /* Tabs are nested (OS pane > distro-release pane) and each nested group
       keeps its own default pane "active" even while its OS-level wrapper is
       hidden (e.g. Ubuntu's first release stays "active" while the Debian
       tab is the one actually shown) — so ".tab-pane.active" alone, or even
       "the last one in DOM order", can point at a pane nobody can see.
       offsetParent is null for anything hidden by a non-active ancestor, so
       it reliably singles out the pane actually on screen. */
    var panel = null;
    document.querySelectorAll('.tab-pane.active .package-grid').forEach(function (grid) {
      if (grid.offsetParent !== null) panel = grid;
    });
    var active = panel ? Array.from(panel.querySelectorAll('.package-item')) : [];
    var shown  = active.filter(function (i) { return !i.classList.contains('hidden'); });

    if (searchQuery && shown.length === 0 && active.length > 0) {
      stats.className = 'search-stats vs-search-warn';
      stats.textContent = '';
      var ico = document.createElement('i');
      ico.className = 'bi bi-exclamation-triangle';
      stats.appendChild(ico);
      stats.appendChild(document.createTextNode(
        ' No packages found matching "' + searchQuery + '" | Try different search terms'
      ));
    } else {
      stats.className = 'search-stats vs-search-ok';
      stats.textContent = '';
      var ico2 = document.createElement('i');
      ico2.className = 'bi bi-info-circle';
      stats.appendChild(ico2);
      stats.appendChild(document.createTextNode(
        ' Total packages: ' + active.length + ' | Currently showing: ' + shown.length
      ));
    }
  }

  /* ===== APT config generator ===== */

  function updateConfigPreview() {
    var distro        = document.getElementById('distroSelect').value;
    var format        = document.getElementById('formatSelect').value;
    var configPreview = document.getElementById('configPreview');
    var noDistro      = document.getElementById('noDistroSelected');
    var compSection   = document.getElementById('componentSection');

    if (!distro) {
      configPreview.classList.add('d-none');
      compSection.classList.add('d-none');
      noDistro.classList.remove('d-none');
      return;
    }

    var available = distroComponents[distro] || ['main'];
    updateComponentVisibility(available);

    configPreview.classList.remove('d-none');
    compSection.classList.remove('d-none');
    noDistro.classList.add('d-none');

    var keyringPath = '/usr/share/keyrings/' + repoKeyword + '-archive-keyring.gpg';
    var components  = [];
    var compMain      = document.getElementById('compMain');
    var compBackports = document.getElementById('compBackports');
    var compBorrowed  = document.getElementById('compBorrowed');
    var compGames     = document.getElementById('compGames');
    var compPaid      = document.getElementById('compPaid');

    if (compMain && !compMain.checked) compMain.checked = true;
    if (compMain      && compMain.checked)     components.push('main');
    if (compBackports && compBackports.checked && !document.getElementById('compBackportsWrapper').classList.contains('d-none')) components.push('backports');
    if (compBorrowed  && compBorrowed.checked  && !document.getElementById('compBorrowedWrapper').classList.contains('d-none'))  components.push('borrowed');
    if (compGames     && compGames.checked     && !document.getElementById('compGamesWrapper').classList.contains('d-none'))     components.push('games');
    if (compPaid      && compPaid.checked      && !document.getElementById('compPaidWrapper').classList.contains('d-none'))      components.push('paid');

    var componentsStr   = components.join(' ');
    var configFilePath  = document.getElementById('configFilePath');
    var aptSources      = document.getElementById('aptSourcesConfig');
    var quickInstall    = document.getElementById('quickInstallCmd');
    var configTypeTitle = document.getElementById('configTypeTitle');

    if (format === 'deb822') {
      configFilePath.textContent  = '/etc/apt/sources.list.d/' + repoKeyword + '.sources';
      configTypeTitle.textContent = 'Create .sources file (DEB822 format)';
      var deb822 = 'Types: deb\nURIs: ' + baseUrl + '/\nSuites: ' + distro + '\nComponents: ' + componentsStr + '\nSigned-By: ' + keyringPath;
      aptSources.querySelector('code').textContent = deb822;
      quickInstall.querySelector('code').textContent =
        '# Quick setup for ' + distro + ' with ' + components.length + ' component(s)\n' +
        'sudo curl -fsSL ' + baseUrl + '/KEY.gpg -o ' + keyringPath + ' && \\\n' +
        'echo "' + deb822 + '" | sudo tee /etc/apt/sources.list.d/' + repoKeyword + '.sources';
    } else {
      configFilePath.textContent  = '/etc/apt/sources.list.d/' + repoKeyword + '.list';
      configTypeTitle.textContent = 'Create .list file (Legacy format)';
      var legacy = 'deb [signed-by=' + keyringPath + '] ' + baseUrl + '/ ' + distro + ' ' + componentsStr;
      aptSources.querySelector('code').textContent = legacy;
      quickInstall.querySelector('code').textContent =
        '# Quick setup for ' + distro + ' with ' + components.length + ' component(s)\n' +
        'sudo curl -fsSL ' + baseUrl + '/KEY.gpg -o ' + keyringPath + ' && \\\n' +
        'echo "' + legacy + '" | sudo tee /etc/apt/sources.list.d/' + repoKeyword + '.list';
    }
  }

  function updateComponentVisibility(available) {
    var wrappers = {
      backports: document.getElementById('compBackportsWrapper'),
      borrowed:  document.getElementById('compBorrowedWrapper'),
      games:     document.getElementById('compGamesWrapper'),
      paid:      document.getElementById('compPaidWrapper')
    };
    var checkboxes = {
      backports: document.getElementById('compBackports'),
      borrowed:  document.getElementById('compBorrowed'),
      games:     document.getElementById('compGames'),
      paid:      document.getElementById('compPaid')
    };

    Object.keys(wrappers).forEach(function (comp) {
      var w = wrappers[comp];
      if (!w) return;
      if (available.indexOf(comp) !== -1) {
        w.classList.remove('d-none');
      } else {
        w.classList.add('d-none');
        if (checkboxes[comp]) checkboxes[comp].checked = false;
      }
    });
  }

  function copyToClipboard(elementId) {
    var el   = document.getElementById(elementId);
    var code = el.querySelector('code');
    var text = code ? code.textContent : el.textContent;

    navigator.clipboard.writeText(text).then(function () {
      /* Find the associated copy button — it's either the element itself or nearby */
      var btn = (el.tagName === 'BUTTON') ? el : el.nextElementSibling;
      if (!btn || btn.tagName !== 'BUTTON') {
        btn = el.parentElement && el.parentElement.querySelector('button');
      }
      if (btn && btn.tagName === 'BUTTON') {
        var orig = btn.innerHTML;
        btn.innerHTML = '<i class="bi bi-check-circle"></i> Copied!';
        btn.classList.remove('btn-outline-primary', 'btn-outline-success');
        btn.classList.add('btn-success');
        setTimeout(function () {
          btn.innerHTML = orig;
          btn.classList.remove('btn-success');
          btn.classList.add('btn-outline-primary');
        }, 2000);
      }
    }).catch(function () {
      alert('Failed to copy. Please select and copy manually.');
    });
  }

  function copyTextToClipboard(text, btn) {
    navigator.clipboard.writeText(text).then(function () {
      var orig = btn.innerHTML;
      btn.innerHTML = '<i class="bi bi-check-circle"></i>';
      btn.classList.add('vs-copy-pkg-btn-done');
      setTimeout(function () {
        btn.innerHTML = orig;
        btn.classList.remove('vs-copy-pkg-btn-done');
      }, 2000);
    }).catch(function () {
      alert('Failed to copy. Please select and copy manually.');
    });
  }

  function clearSearch() {
    var input = document.getElementById('packageSearch');
    if (input) { input.value = ''; searchQuery = ''; filterPackages(); input.focus(); }
  }

  /* ===== Wire up all event listeners (no inline handlers in HTML) ===== */

  document.addEventListener('DOMContentLoaded', function () {
    collectPackages();

    /* Fallback icon for packages without an AppStream stock icon
       (covers both the grid thumbnail and the popup's larger icon) */
    document.querySelectorAll('img.package-icon, img.package-popup-icon').forEach(function (img) {
      img.addEventListener('error', function () {
        img.src = '/placeholder.svg';
        img.classList.add('package-icon-placeholder');
      });
      /* Image may have already failed before this listener was attached */
      if (img.complete && img.naturalWidth === 0) {
        img.src = '/placeholder.svg';
        img.classList.add('package-icon-placeholder');
      }
    });

    /* Search input */
    var searchInput = document.getElementById('packageSearch');
    if (searchInput) {
      searchInput.addEventListener('input', function (e) {
        searchQuery = e.target.value.toLowerCase().trim();
        filterPackages();
      });
    }

    /* Keyboard shortcuts */
    document.addEventListener('keydown', function (e) {
      if ((e.ctrlKey || e.metaKey) && e.key === 'f') {
        e.preventDefault();
        if (searchInput) searchInput.focus();
      }
      if (e.key === 'Escape' && searchInput && document.activeElement === searchInput) {
        clearSearch();
      }
    });

    /* Clear button */
    var clearBtn = document.getElementById('clearSearchBtn');
    if (clearBtn) clearBtn.addEventListener('click', clearSearch);

    /* Config preview — selects and checkboxes */
    ['distroSelect', 'formatSelect', 'compMain', 'compBackports', 'compBorrowed', 'compGames', 'compPaid']
      .forEach(function (id) {
        var el = document.getElementById(id);
        if (el) el.addEventListener('change', updateConfigPreview);
      });

    /* Copy buttons and clickable pre blocks via data-copy-target */
    document.querySelectorAll('[data-copy-target]').forEach(function (el) {
      el.addEventListener('click', function () {
        copyToClipboard(el.dataset.copyTarget);
      });
    });

    /* Package popup "copy install command" buttons */
    document.querySelectorAll('[data-copy-text]').forEach(function (el) {
      el.addEventListener('click', function (e) {
        e.preventDefault();
        copyTextToClipboard(el.dataset.copyText, el);
      });
    });

    updateStats();

    document.querySelectorAll('[data-bs-toggle="pill"]').forEach(function (btn) {
      btn.addEventListener('shown.bs.tab', updateStats);
    });
  });

}());
