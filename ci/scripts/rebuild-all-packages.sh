#!/bin/bash

# Rebuilds every project under BASE_DIR that has Debian packaging and adds
# the resulting .debs to your Aptly repositories. Override the Configuration
# block below (or export the same-named env vars) for your own setup.

set -e

echo "🔨 Starting comprehensive package rebuild..."
echo "=================================================="

# Configuration
BASE_DIR="${BASE_DIR:-/home/YOUR_USER/Projects/YourOrg}"
REPO_KEYWORD="${REPO_KEYWORD:-myrepo}"
REPO_USER="${REPO_USER:-jenkins}"
ANSIBLE_DIR="${ANSIBLE_DIR:-/home/YOUR_USER/Projects/YourOrg/deb-repo-toolkit/ansible}"
DISTRIBUTIONS=("forky" "trixie" "bookworm" "bullseye" "jammy" "focal")
OUTPUT_DIR="/tmp/${REPO_KEYWORD}-packages-$(date +%Y%m%d-%H%M%S)"
LOG_FILE="/tmp/package-rebuild-$(date +%Y%m%d-%H%M%S).log"

# Create output directory
mkdir -p "$OUTPUT_DIR"

echo "📁 Output directory: $OUTPUT_DIR"
echo "📄 Log file: $LOG_FILE"
echo ""

# Find all projects with debian packaging
PROJECTS=($(find "$BASE_DIR" -maxdepth 2 -name "debian" -type d | grep -v vendor | sed 's|/debian||g' | sort))

echo "Found ${#PROJECTS[@]} projects with Debian packaging:"
printf '%s\n' "${PROJECTS[@]}" | sed "s|.*$(basename "$BASE_DIR")/|  - |g"
echo ""

# Function to build a single project
build_project() {
    local project_dir="$1"
    local project_name=$(basename "$project_dir")
    
    echo "🔨 Building $project_name..."
    
    if [ ! -d "$project_dir" ]; then
        echo "❌ Project directory not found: $project_dir"
        return 1
    fi
    
    cd "$project_dir"
    
    # Check if there's a Jenkinsfile (indicates Jenkins-based build)
    if [ -f "Jenkinsfile" ] || [ -f "debian/Jenkinsfile" ]; then
        echo "  Jenkins-based project detected"
        # For Jenkins projects, we might need to trigger the Jenkins build
        # For now, let's try a direct build approach
    fi
    
    # Try to build using standard Debian tools
    if [ -f "debian/control" ]; then
        echo "  Building with dpkg-buildpackage..."
        
        # Install dependencies if needed
        if command -v mk-build-deps >/dev/null 2>&1; then
            sudo mk-build-deps --install --remove debian/control || true
        fi
        
        # Clean previous builds
        debian/rules clean 2>/dev/null || true
        
        # Build for each distribution
        for distro in "${DISTRIBUTIONS[@]}"; do
            echo "    Building for $distro..."
            
            # Build the package
            if dpkg-buildpackage -b -uc -us 2>>"$LOG_FILE"; then
                # Move built packages to output directory
                find .. -name "*.deb" -newer debian/control -exec mv {} "$OUTPUT_DIR/" \; 2>/dev/null || true
                echo "    ✅ Build successful for $distro"
            else
                echo "    ❌ Build failed for $distro (check log: $LOG_FILE)"
            fi
        done
    else
        echo "  ⚠️  No debian/control found, skipping..."
    fi
    
    echo ""
}

# Function to add packages to repository
add_packages_to_repo() {
    echo "📦 Adding built packages to Aptly repositories..."
    
    if [ ! -d "$OUTPUT_DIR" ] || [ -z "$(ls -A "$OUTPUT_DIR"/*.deb 2>/dev/null)" ]; then
        echo "❌ No packages found to add"
        return 1
    fi
    
    cd "$OUTPUT_DIR"
    
    for package in *.deb; do
        if [ -f "$package" ]; then
            echo "  Processing $package..."
            
            # Extract package info
            BASENAME=$(basename "$package")
            DEB=$(echo "$BASENAME" | awk -F_ '{print $1}')
            
            # Determine distribution from package name or default to forky
            DISTRO="forky"
            if [[ $package =~ ~([^_]+) ]]; then
                DISTRO="${BASH_REMATCH[1]}"
            fi
            
            echo "    Adding $DEB to ${DISTRO}-main-${REPO_KEYWORD}"

            # Add to repository (as the repo user)
            if sudo -u "$REPO_USER" -H bash -c "
                export HOME=/var/lib/$REPO_USER
                export GNUPGHOME=/var/lib/$REPO_USER/.gnupg
                cd /var/lib/$REPO_USER
                aptly repo remove ${DISTRO}-main-${REPO_KEYWORD} $DEB 2>/dev/null || true
                aptly repo add ${DISTRO}-main-${REPO_KEYWORD} '$OUTPUT_DIR/$package'
            " 2>>"$LOG_FILE"; then
                echo "    ✅ Successfully added $DEB"
            else
                echo "    ❌ Failed to add $DEB"
            fi
        fi
    done
}

# Function to trigger repository rebuild
trigger_repo_rebuild() {
    echo "🔄 Triggering repository rebuild..."
    
    cd "$ANSIBLE_DIR"

    # Create snapshots
    echo "  Creating snapshots..."
    if ansible-playbook --extra-vars "repo_user=$REPO_USER" -e @vars/example-repo.yml playbooks/example-repo-snapshot.yml >>"$LOG_FILE" 2>&1; then
        echo "  ✅ Snapshots created successfully"
    else
        echo "  ❌ Snapshot creation failed"
    fi

    # Publish repository
    echo "  Publishing repository..."
    if ansible-playbook --extra-vars "repo_user=$REPO_USER" -e @vars/example-repo.yml playbooks/example-repo-publish.yml >>"$LOG_FILE" 2>&1; then
        echo "  ✅ Repository published successfully"
    else
        echo "  ❌ Repository publishing failed"
    fi
}

# Main execution
echo "🚀 Starting package rebuild process..."
echo "This will build packages for ${#PROJECTS[@]} projects..."
read -p "Continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

# Build packages (build only a few initially to test)
echo "🔨 Building packages..."
count=0
for project in "${PROJECTS[@]}"; do
    build_project "$project"
    count=$((count + 1))
    
    # Limit to first 5 projects for initial testing
    if [ $count -ge 5 ]; then
        echo "⏸️  Stopping after 5 projects for initial testing..."
        echo "   Remove this limit to build all projects"
        break
    fi
done

# Add packages to repository
add_packages_to_repo

# Trigger repository rebuild
trigger_repo_rebuild

echo ""
echo "✅ Package rebuild process completed!"
echo "📊 Summary:"
echo "   - Built packages: $(ls -1 "$OUTPUT_DIR"/*.deb 2>/dev/null | wc -l)"
echo "   - Output directory: $OUTPUT_DIR"
echo "   - Log file: $LOG_FILE"
echo ""
echo "🌐 Check repository at your repo_domain from vars/example-repo.yml"
echo ""
echo "To build all projects, edit this script and remove the 5-project limit."
