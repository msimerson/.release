#!/bin/sh

usage() {
    echo "start.sh { major | minor | patch | prerelease }"
    exit
}

. .release/base.sh || exit

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
    cat << EO_CHANGE >> .release/new.txt


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
        git log --pretty=format:"- %s" "$LAST_TAG..HEAD" >> .release/new.txt
    fi
}

add_release_link() {

    if grep -q "^\[$NEW_VERSION\]:" "$CHANGELOG"; then
        echo "CHANGELOG URL for $NEW_VERSION exists"
    else
        # the VERSION (added above) is a markdown [URL]. Add the
        # release URL to the bottom of the file.
        REPO_URL=$(gh repo view --json url -q ".url")
        echo "[$NEW_VERSION]: $REPO_URL/releases/tag/$NEW_VERSION" >> "$CHANGELOG"
    fi
}

update_changes() {
    # insert contents of new.txt into CHANGELOG.md after marker
    if grep -qE "^#* $NEW_VERSION|^#* \[$NEW_VERSION\]" "$CHANGELOG"; then
        echo "CHANGELOG entry for $NEW_VERSION exists"
    else
		write_template
		add_commit_messages
		echo "" >> .release/new.txt

        if head "$CHANGELOG" | grep -q Unreleased;
            sed -i '' -e "/### Unreleased$/r .release/new.txt" "$CHANGELOG"
        then
            sed -i '' -e "/#### N.N.N.*$/r .release/new.txt" "$CHANGELOG"
        fi
        rm .release/new.txt
    fi

    add_release_link
    if command -v open; then open "$CHANGELOG"; fi

    echo
    echo "AFTER editing $CHANGELOG, run: .release/submit.sh"
}

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
update_changes

git add package.json
git add "$CHANGELOG"

# update .release submodule, but leave it to author to review/check in
cd .release && git pull && cd ..