@NonCPS
private static String extractDistro(String fileName) {
    def m = fileName =~ /~([a-zA-Z0-9]+)_/
    return m.find() ? m[0][1] : 'borrow'
}

// hudson.model.Run$Artifact is not Serializable, so it can never be held in a
// CPS-visible variable (the pipeline engine persists locals across every step
// boundary). Extract only plain Strings here, inside a NonCPS method.
@NonCPS
List<String> listArtifactFileNames() {
    return currentBuild.rawBuild.getArtifacts().collect { it.fileName }
}

// hudson.scm.ChangeLogSet$Entry is likewise not Serializable.
@NonCPS
List<String> collectChangeMessages() {
    def msgs = []
    for (def changeLogSet in currentBuild.changeSets) {
        for (def entry in changeLogSet.items) {
            def firstLine = entry.msg ? entry.msg.tokenize('\n')[0] : ''
            if (firstLine) {
                msgs << firstLine
            }
        }
    }
    return msgs.unique()
}

def call(String repoSuffix = 'myrepo', String repoBaseUrl = 'https://repo.example.com') {
    def artifactDir = "${env.WORKSPACE}/downloaded-artifacts"
    sh "rm -rf ${artifactDir} && mkdir -p ${artifactDir}"

    // Use Jenkins' own build object instead of curling its REST API: avoids
    // needing an authenticated JENKINS_USER (anonymous API reads are 403).
    def fileNames = listArtifactFileNames()

    if (!fileNames || fileNames.isEmpty()) {
        error "No artifact in the current build!"
    }

    copyArtifacts(
        projectName: env.JOB_NAME,
        selector: specific(env.BUILD_NUMBER),
        filter: '**/*.deb',
        target: 'downloaded-artifacts',
        flatten: true
    )

    // Example package -> component routing — replace with your own package
    // names, or swap this for a lookup against your build metadata.
    def gamesPkgs = ['example-game-one', 'example-game-two']
    def backportsPkgs = ['example-backport-one', 'example-backport-two']

    // Write toot header immediately; entries are appended via sh to avoid
    // CPS closure issues with mutable Groovy collections inside .each.
    sh """
        printf '%s\n%s\n\n' '📦 ${env.JOB_NAME} #${env.BUILD_NUMBER}' '${repoBaseUrl}' > /tmp/debtoot.txt
        true > /tmp/debtoot_pkgs.txt
        true > /tmp/debtoot_data.txt
    """

    // for loop is CPS-safe; .each on lists/maps is not reliable in Jenkins Pipeline
    for (def fileName in fileNames) {
        if (!fileName.endsWith('.deb')) continue

        def pkgName  = fileName.tokenize('_')[0]
        def pkgVer   = fileName.tokenize('_').size() > 1 ? fileName.tokenize('_')[1] : ''
        def baseVer  = pkgVer.contains('~') ? pkgVer.split('~')[0] : pkgVer
        def component = gamesPkgs.contains(pkgName) ? 'games'
                      : backportsPkgs.contains(pkgName) ? 'backports'
                      : 'main'
        def distro = extractDistro(fileName)
        def repoName = "${distro}-${component}-${repoSuffix}"

        // Source package name drives the pool path; fall back to binary name if unset
        def srcPkg = sh(
            script: "dpkg-deb --field '${artifactDir}/${fileName}' Source 2>/dev/null | awk '{print \$1}'",
            returnStdout: true
        ).trim() ?: pkgName

        // GitHub repository link carried inside the .deb control fields.
        // Prefer Vcs-Browser, then Vcs-Git (strip trailing .git), then Homepage.
        // Only accept github.com URLs; otherwise leave empty (link is skipped).
        def ghUrl = sh(script: """
            f='${artifactDir}/${fileName}'
            v=\$(dpkg-deb --field "\$f" Vcs-Browser 2>/dev/null)
            [ -z "\$v" ] && v=\$(dpkg-deb --field "\$f" Vcs-Git 2>/dev/null | sed 's/\\.git\$//')
            [ -z "\$v" ] && v=\$(dpkg-deb --field "\$f" Homepage 2>/dev/null)
            case "\$v" in *github.com*) printf '%s' "\$v";; *) printf '';; esac
        """, returnStdout: true).trim()

        echo "→ Removing any existing ${pkgName} from ${repoName}"
        sh "aptly repo remove ${repoName} ${pkgName} || true"
        echo "→ Adding ${fileName} to ${repoName}"
        sh "aptly repo add -force-replace ${repoName} ${artifactDir}/${fileName}"

        if (distro != 'ilegal') {
            sh """
                echo '${pkgName}|${baseVer}|${distro}|${component}|${srcPkg}|${ghUrl}' >> /tmp/debtoot_data.txt
                grep -qxF '${pkgName}' /tmp/debtoot_pkgs.txt || echo '${pkgName}' >> /tmp/debtoot_pkgs.txt
            """
        }
    }

    // Changelog from this build's own SCM changesets — native pipeline object,
    // no REST call / auth needed.
    def changeMsgs = collectChangeMessages()

    if (changeMsgs) {
        def block = '🔄 Changes:\n' + changeMsgs.take(10).collect { "• ${it}" }.join('\n') + '\n\n'
        writeFile file: '/tmp/debtoot.txt', text: readFile('/tmp/debtoot.txt') + block
    }

    withEnv(["REPO_BASE_URL=${repoBaseUrl}"]) {
    sh '''
        awk -F'|' -v repoBaseUrl="$REPO_BASE_URL" '
        {
            pkg=$1; ver=$2; dist=$3; comp=$4; src=$5; gh=$6
            if (!(pkg in seen)) { seen[pkg]=ver; comp_pkg[pkg]=comp; src_pkg[pkg]=src; gh_pkg[pkg]=gh; order[n++]=pkg }
            key=pkg SUBSEP dist
            if (!(key in seen_dist)) { seen_dist[key]=1; dists[pkg]=(dists[pkg] ? dists[pkg] ", " : "") dist }
        }
        END {
            for (i=0; i<n; i++) {
                pkg=order[i]
                comp=comp_pkg[pkg]
                src=src_pkg[pkg]
                gh=gh_pkg[pkg]
                printf "📦 %s %s\\n  %s\\n", pkg, seen[pkg], dists[pkg]
                # GitHub repository link for every package (when known)
                if (gh != "") printf "  %s\\n", gh
                # Repository pool listing only on the first package, to save space
                if (i == 0) {
                    first=(substr(src,1,3)=="lib") ? substr(src,1,4) : substr(src,1,1)
                    printf "  %s/pool/%s/%s/%s/\\n", repoBaseUrl, comp, first, src
                }
            }
        }' /tmp/debtoot_data.txt >> /tmp/debtoot.txt
        rm -f /tmp/debtoot_data.txt
    '''
    }
}
