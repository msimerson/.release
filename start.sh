#!/bin/sh

usage() {
    echo "start.sh { major | minor | patch | prerelease }"
    exit
}

. .release/base.sh || exit 1

find_new_version() {
    if ! git branch --show-current | grep -q ^release;
    then
        case "$1" in
            "major" ) ;;
            "minor" ) ;;
            "patch" ) ;;
            "prerelease" ) ;;
            *)
            usage
            ;;
        esac

        NEW_VERSION=$(npm --no-git-tag-version version "$1")
        NEW_VERSION=${NEW_VERSION//v}
    else
        if [ -f package.json ]; then
            NEW_VERSION=$(node -e 'console.log(require("./package.json").version)')
        fi
    fi

    if [ -z "$NEW_VERSION" ]; then
        echo "Unable to determine version, cowardly bailing out!"
        exit
    fi
}

write_template() {
    cat <<EO_CHANGE > .release/new.txt

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
                echo " ----- should be ------"
                echo "$_ver_uri"
                echo
            fi
        fi
    done
    echo
}

constrain_publish() {
    local _main; _main=$(node -e 'console.log(require("./package.json").main)')
    if [ "$_main" = "undefined" ]; then
        echo "CONSIDER: package.json has no [main] section. You can likely reduce"
        echo "          the published package size by populating it."
        echo
        echo "   https://docs.npmjs.com/cli/v10/configuring-npm/package-json#files"
        echo
    fi

    # many modules have a .npmignore (one more file) to reduce/limit what
    # gets published.
    if [ -f .npmignore ]; then
        echo "CONSIDER: instead of maintaining .npmignore, add the much shorter list of"
        echo "          files that should be published to [files] in package.json. -^"
        echo
    fi
}

self_update()
{
    (
        cd .release || exit

        if [ "$(git branch --show-current)" != "main" ]; then
            git checkout main
        fi

        _pull=$(git pull origin main)
    )

    if [ "$_pull" != "Already up to date." ]; then
        git add .release
        . .release/base.sh
    fi
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

git add package.json
git add "$CHANGELOG"
