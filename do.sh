#!/bin/sh

usage() {
    echo "do.sh {major | minor | patch}"
    exit
}

. .release/base.sh || exit

case "$1" in
    "major" )
    ;;
    "minor" )
    ;;
    "patch" )
    ;;
    *)
    usage
    ;;
esac

NEW_VERSION=$(npm --no-git-tag-version version "$1")
BARE_VERSION=${NEW_VERSION//v}

YMD=$(date "+%Y-%m-%d")
# echo "Preparing $NEW_VERSION - $YMD"

if branch_is_main; then
    git checkout -b "release-${NEW_VERSION}"
fi

update_changes() {
    cat << EO_CHANGE >> .release/new.txt


### [$BARE_VERSION] - $YMD

#### Added

- 

#### Fixed

- 

#### Changed

- 
EO_CHANGE

    LAST_TAG=$(git describe --tags --abbrev=0)
    if [ "$LAST_TAG" != "" ]; then
        # append log entries since the last tag (release)
        git log --pretty=format:"- %s" "$LAST_TAG..HEAD" >> .release/new.txt
    fi

    echo "" >> .release/new.txt

    # insert contents of new.txt into CHANGELOG.md after marker
    if grep -qE "^#* $BARE_VERSION|^#* \[$BARE_VERSION\]" "$CHANGELOG"; then
        echo "CHANGELOG entry for $BARE_VERSION exists"
    else
        if head "$CHANGELOG" | grep -q Unreleased;
            sed -i '' -e "/### Unreleased$/r .release/new.txt" "$CHANGELOG"
        then
            sed -i '' -e "/#### N.N.N.*$/r .release/new.txt" "$CHANGELOG"
        fi
        rm .release/new.txt
    fi

    if grep -q "^\[$BARE_VERSION\]:" "$CHANGELOG"; then
        echo "CHANGELOG URL for $BARE_VERSION exists"
    else
        # the VERSION (added above) is a markdown [URL]. Add the
        # release URL to the bottom of the file.
        REPO_URL=$(gh repo view --json url -q ".url")
        echo "[$BARE_VERSION]: $REPO_URL/releases/tag/$BARE_VERSION" >> "$CHANGELOG"
    fi

    if command -v open; then open "$CHANGELOG"; fi

    echo
    echo "AFTER editing $CHANGELOG, run: .release/push.sh"
}

find_changelog
update_changes

git add package.json
git add "$CHANGELOG"
git commit -m "bump version to $BARE_VERSION"
