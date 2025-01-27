#!/bin/sh

usage() {
    echo "start.sh { major | minor | patch | prerelease }"
    exit
}

. .release/base.sh || exit 1

find_new_version() {
    local _semver=${1:-""}

    if git branch --show-current | grep -q ^release;
    then
        if [ -f package.json ]; then
            NEW_VERSION=$(node -e 'console.log(require("./package.json").version)')
        fi
    else

        if [ -z "$_semver" ]; then
            set -- major minor patch prerelease
            printf 'Choose a semver release type: (https://semver.org)\n\n'
            printf '\t%s\n' $@; echo
            _semver=$(release_get_choice $@)
        fi

        case "$_semver" in
            "major" ) ;;
            "minor" ) ;;
            "patch" ) ;;
            "prerelease" ) ;;
            *)
            usage
            ;;
        esac

        NEW_VERSION=$(npm --no-git-tag-version version "$_semver")
        NEW_VERSION=${NEW_VERSION//v}
    fi

    if [ -z "$NEW_VERSION" ]; then
        echo "Unable to determine version, cowardly bailing out!"
        exit
    fi
}

write_template() {
    cat > .release/new.txt <<EO_CHANGE

### [$NEW_VERSION] - $YMD

#### Added

- 

#### Fixed

- 

#### Changed

- 
EO_CHANGE
}

add_commit_messages() {

    # no tags (yet)
    if [ -z "$(git tag)" ]; then
        git log --pretty=format:"- %s%n%b" >> .release/new.txt
        return
    fi

    LAST_TAG=$(git describe --tags --abbrev=0)
    if [ "$LAST_TAG" != "" ]; then
        # append log entries since the last tag (release)
        git log --pretty=format:"- %s%n%b" "$LAST_TAG..HEAD" >> .release/new.txt
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

changelog_add_header()
{
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
    if command -v open; then open "$CHANGELOG"; fi

    echo
    echo "AFTER editing $CHANGELOG, run: .release/submit.sh"
}

changelog_check_tag_urls()
{
    echo "checking tag URLs..."
    git fetch --tags
    local REPO_URL; REPO_URL="$(gh repo view --json url -q '.url')"

    for _tag in $(git tag); do
        local _ver="${_tag//v}"
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
        echo "HINT: files = [ 'CHANGELOG.md', 'config' ]"
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
    #    jq '.files += ["CONTRIBUTORS.md"]' package.json > tmp || exit 1
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

    if grep -q eslint-8 .codeclimate.yml; then
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

self_update()
{
    (
        cd .release || exit

        if [ "$(git branch --show-current)" != "main" ]; then
            git checkout main
        fi

        git pull origin main -q
    )

    git add .release
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

git add package.json
git add "$CHANGELOG"
