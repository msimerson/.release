#!/bin/sh

set -eu

usage() {
    echo "start.sh { major | minor | patch | prerelease }"
    exit
}

# shellcheck source=./base.sh
. .release/base.sh

find_new_version() {
    local _semver="${1:-""}"

    if [ -f package.json ]; then
        local _current_version
        _current_version=$(node -e 'console.log(require("./package.json").version)')
    fi

    if git branch --show-current | grep -q ^release;
    then
        NEW_VERSION="$_current_version"
    else
        if [ -z "$_semver" ]; then
            if printf '%s' "$_current_version" | grep -q -- '-'; then
                _semver="prerelease"
            fi
        fi

        if [ -z "$_semver" ]; then
            set -- major minor patch prerelease
            printf 'Choose a semver release type: (https://semver.org)\n\n'
            printf '\t%s\n' "$@"; echo
            _semver=$(release_get_choice "$@")
        fi

        case "$_semver" in
            "major" ) ;;
            "minor" ) ;;
            "patch" ) ;;
            "prerelease" ) ;;
            *) usage ;;
        esac

        NEW_VERSION=$(npm --no-git-tag-version version "$_semver")
        NEW_VERSION=${NEW_VERSION#v}
    fi

    if [ -z "$NEW_VERSION" ]; then
        echo "Unable to determine version, cowardly bailing out!"
        exit
    fi
}

write_template() {
    cat > .release/new.txt <<EO_CHANGE

### [$NEW_VERSION] - $YMD
EO_CHANGE
}

add_commit_messages() {

    if [ -z "$(git tag)" ]; then
        _log_range="HEAD"
    else
        LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo '')
        if [ -z "$LAST_TAG" ]; then
            _log_range="HEAD"
        else
            _log_range="$LAST_TAG..HEAD"
        fi
    fi

    # Categorize by conventional commit prefix; collect remainder as uncategorized
    _added=""
    _fixed=""
    _changed=""
    _other=""

    while IFS= read -r _msg; do
        [ -z "$_msg" ] && continue
        case "$_msg" in
            feat:*|feat\(*\):*)
                _added="$_added\n- ${_msg#*: }"
                ;;
            fix:*|fix\(*\):*)
                _fixed="$_fixed\n- ${_msg#*: }"
                ;;
            chore:*|chore\(*\):*|refactor:*|perf:*|style:*|docs:*|test:*|build:*|ci:*)
                _changed="$_changed\n- ${_msg#*: }"
                ;;
            *)
                _other="$_other\n- $_msg"
                ;;
        esac
    done <<EOF
$(git log --pretty=format:"%s" "$_log_range")
EOF

    # Append categorized sections, falling back to a flat list if nothing matched
    if [ -z "$_added$_fixed$_changed" ]; then
        git log --pretty=format:"- %s" "$_log_range" >> .release/new.txt
        return
    fi

    if [ -n "$_added" ]; then
        printf '\n#### Added\n' >> .release/new.txt
        printf '%b\n' "$_added" >> .release/new.txt
    fi
    if [ -n "$_fixed" ]; then
        printf '\n#### Fixed\n' >> .release/new.txt
        printf '%b\n' "$_fixed" >> .release/new.txt
    fi
    if [ -n "$_changed" ]; then
        printf '\n#### Changed\n' >> .release/new.txt
        printf '%b\n' "$_changed" >> .release/new.txt
    fi
    if [ -n "$_other" ]; then
        printf '\n#### Other\n' >> .release/new.txt
        printf '%b\n' "$_other" >> .release/new.txt
    fi
}

changelog_append_release_link() {

    if grep -q "^\[$NEW_VERSION\]:" "$CHANGELOG"; then
        echo "CHANGELOG URL for $NEW_VERSION exists"
    else
        # the VERSION (added above) is a markdown [URL]. Add the
        # release URL to the bottom of the file.
        REPO_URL=$(gh repo view --json url -q ".url")
        echo "[$NEW_VERSION]: $REPO_URL/releases/tag/v$NEW_VERSION" >> "$CHANGELOG"
    fi
}

changelog_add_header() {

    if ! grep -qi '# Changelog' "$CHANGELOG"; then
        echo "inserting: # Changelog"
        sed -i '' \
            -e '1s|^|# Changelog\n\nThe format is based on [Keep a Changelog](https://keepachangelog.com/).\n\n|' \
            "$CHANGELOG"
    fi

    if ! grep -q '# Unreleased' "$CHANGELOG"; then
        echo "inserting: ### Unreleased"
        sed -i '' \
            -e '1,/##/ s/##/### Unreleased\n\n##/' \
            "$CHANGELOG"
    fi
}

changelog_add_release_template() {

    if grep -qE "^#* $NEW_VERSION|^#* \[$NEW_VERSION\]" "$CHANGELOG"; then
        echo "CHANGELOG entry for $NEW_VERSION exists"
    else
		write_template
		add_commit_messages
		echo "" >> .release/new.txt

        # insert contents of new.txt into CHANGELOG.md after marker
        sed -i '' -e "/## Unreleased$/r .release/new.txt" "$CHANGELOG"
        rm .release/new.txt
    fi

    changelog_append_release_link
    if   command -v open; then open "$CHANGELOG";
    elif command -v xdg-open; then xdg-open "$CHANGELOG";
    fi

    echo
    echo "AFTER editing $CHANGELOG, run: sh .release/submit.sh"
}

changelog_check_tag_urls() {
    echo "checking tag URLs..."
    git fetch --tags
    local REPO_URL; REPO_URL="$(gh repo view --json url -q '.url')"

    for _tag in $(git tag); do
        local _ver="${_tag#v}"
        local _ver_uri="[$_ver]: $REPO_URL/releases/tag/$_tag"

        if ! grep -Fq "$_ver_uri" "$CHANGELOG"; then
            if ! grep -Fq "[$_ver]:" "$CHANGELOG"; then
                echo "$_ver_uri" >> "$CHANGELOG"
            else
                echo "INVALID URI in CHANGELOG"
                grep -F "[$_ver]:" "$CHANGELOG"
                echo "      ----- should be ------"
                echo "$_ver_uri"
                echo
            fi
        fi
    done
    echo
}

constrain_publish() {
    local _files; _files=$(node -e 'console.log(require("./package.json").files)')
    if [ "$_files" = "undefined" ]; then
        echo "CONSIDER: package.json has no [files] section. You can likely reduce"
        echo "          the published package size by populating it."
        echo
        echo "   https://docs.npmjs.com/cli/v10/configuring-npm/package-json#files"
        echo
        echo 'HINT: "files": [ "CHANGELOG.md", "config" ],'

        local _main; _main=$(node -e 'console.log(require("./package.json").main)')
        if [ "$_main" = "undefined" ]; then
            echo "WARNING: package.json property 'main' is undefined. The default"
            echo "         index.js is NOT automatically included in [files]."
        fi
    fi

    # many modules have a .npmignore (one more file) to reduce/limit what
    # gets published.
    if [ -f .npmignore ]; then
        echo "CONSIDER: instead of maintaining .npmignore, add the much shorter list of"
        echo "          files that should be published to [files] in package.json. -^"
        echo
    fi
}

contributors_update() {
    # never mind, NPM site doesn't render it
    #if ! jq .files package.json | grep -q CONTRIBUTORS; then
    #    jq '.files += ["CONTRIBUTORS.md"]' package.json > tmp
    #    mv tmp package.json
    #    git add package.json
    #    git commit -m 'add CONTRIBUTORS to [files] in package.json'
    #fi

    if [ ! -f CONTRIBUTORS.md ]; then
        node .release/js/contributors.cjs
        git add CONTRIBUTORS.md
        git commit -m 'doc(CONTRIBUTORS): added'
        return
    fi

    node .release/js/contributors.cjs

    if file_has_changes CONTRIBUTORS.md; then
        git add CONTRIBUTORS.md
        git commit -m 'doc(CONTRIBUTORS): updated'
    fi
}

upgrade_eslint9() {

    _eslint8=".eslintrc.yaml"
    if [ ! -f "$_eslint8" ]; then
        _eslint8=".eslintrc.json"
    fi

    if [ -f "$_eslint8" ]; then
        npx @eslint/migrate-config "$_eslint8"
        git rm "$_eslint8"
        git add eslint.config.mjs
        git commit -m 'dep(eslint): upgrade to v9'
    fi

    if grep -qs eslint-8 .codeclimate.yml; then
        sed -i '' \
            -e 's/eslint-8/eslint-9/' \
            -e 's/\.eslintrc.yaml/eslint.config.mjs/' \
            -e 's/\.eslintrc.json/eslint.config.mjs/' \
            .codeclimate.yml
    fi

    # eslint 9 deprecated code formatting features, prettier is the
    # de facto tool now, and we store the config in package.json
    if [ -f .prettierrc ];     then git rm .prettierrc; fi
    if [ -f .prettierrc.yml ]; then git rm .prettierrc.yml; fi

    node .release/js/standards.cjs
}

update_gh_workflows() {
    _installed=".github/workflows/$1.yml"
    _template="../.github/workflow-templates/$1.yml"
    if [ ! -f "$_template" ] && [ -f "../../.github/workflow-templates/$1.yml" ]; then
        _template="../../.github/workflow-templates/$1.yml"
    fi

    if [ ! -f "$_installed" ] && [ -f "$_template" ] && [ "$1" != "codeql" ]; then
        cp "$_template" "$_installed"
        return
    fi

    if [ -f "$_installed" ] && [ -f "$_template" ]; then
        if ! diff -u "$_installed" "$_template"; then
            printf "\nNOTICE: %s is not in sync with %s\n" "$_installed" "$_template"
            printf "suggestion:\tcp %s %s\n" "$_template" "$_installed"
        fi
    fi
}

self_update() {
    (
        cd .release

        if [ "$(git branch --show-current)" != "main" ]; then
            git checkout main
        fi

        git pull origin main -q
    )

    git add .release
    # shellcheck source=./base.sh
    . .release/base.sh
}

self_update

find_new_version "$@"

YMD=$(date "+%Y-%m-%d")
# echo "Preparing $NEW_VERSION - $YMD"

if branch_is_main; then
    if [ -z "$(git status --porcelain)" ]; then
        # working directory is clean, bring it up-to-date
        git pull
    fi
    git checkout -b "release-${NEW_VERSION}"
fi

find_changelog
changelog_add_header
changelog_add_release_template
changelog_check_tag_urls
constrain_publish
contributors_update
upgrade_eslint9
for _f in ci release publish; do
    update_gh_workflows "$_f"
done

git add package.json
git add "$CHANGELOG"
