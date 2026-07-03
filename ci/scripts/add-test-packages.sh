#!/bin/bash

# Manually adds a handful of .deb files to the repository for testing —
# this is what a CI pipeline's "add to repository" step does automatically.
# Edit REPO_USER/REPO_KEYWORD/DISTRO and the PACKAGES list for your setup.

set -e

REPO_USER="${REPO_USER:-jenkins}"
REPO_KEYWORD="${REPO_KEYWORD:-myrepo}"
DISTRO="${DISTRO:-forky}"

echo "🔧 Adding test packages to the ${REPO_KEYWORD} repository..."

# Set up environment as the repo user would
export HOME="/var/lib/$REPO_USER"
export GNUPGHOME="/var/lib/$REPO_USER/.gnupg"
cd "/var/lib/$REPO_USER"

# List of test packages to add — replace with your own .deb paths
PACKAGES=(
    "/home/YOUR_USER/Projects/YourOrg/my-app_1.0.0_all.deb"
    "/home/YOUR_USER/Projects/YourOrg/my-app-plugin_1.0.0_all.deb"
)

echo "Available repositories:"
aptly repo list

for PACKAGE in "${PACKAGES[@]}"; do
    if [ -f "$PACKAGE" ]; then
        BASENAME=$(basename "$PACKAGE")
        DEB=$(echo "$BASENAME" | awk -F_ '{print $1}')

        echo "📦 Adding $DEB from $PACKAGE"

        if aptly repo add "${DISTRO}-main-${REPO_KEYWORD}" "$PACKAGE" 2>/dev/null; then
            echo "✅ Successfully added $DEB to ${DISTRO}-main-${REPO_KEYWORD}"
        else
            echo "❌ Failed to add $DEB to ${DISTRO}-main-${REPO_KEYWORD}"
        fi
    else
        echo "⚠️  Package not found: $PACKAGE"
    fi
done

echo ""
echo "📊 Repository status after adding packages:"
aptly repo list

echo ""
echo "🔄 To complete the process, run (from this toolkit's ansible/ dir):"
echo "1. Create snapshots: ansible-playbook --extra-vars \"repo_user=$REPO_USER\" -e @vars/example-repo.yml playbooks/example-repo-snapshot.yml"
echo "2. Publish:          ansible-playbook --extra-vars \"repo_user=$REPO_USER\" -e @vars/example-repo.yml playbooks/example-repo-publish.yml"
echo "3. Or trigger your CI rebuild job (see ../ci/Jenkinsfile.rebuild)"
