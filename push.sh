#!/bin/sh

. .release/base.sh || exit

if branch_is_main; then
    echo "ERROR: run the push script in a feature branch! (not main)"
    exit
fi

assure_repo_is_clean #|| exit

REL_BRANCH=$(git branch --show-current)
PKG_VERSION=$(node -e 'console.log(require("./package.json").version)')
LAST_TAG=$(git describe --tags --abbrev=0)
REPO_URL=$(gh repo view --json url -q ".url")
GIT_NOTES=$(git log --pretty=format:"- %s" "$LAST_TAG..HEAD")
GIT_URL_NOTES=$(git log --pretty=format:"- [%h]($REPO_URL/commit/%h) %s" "$LAST_TAG..HEAD")

git push --set-upstream origin "$REL_BRANCH"

if command -v gh; then
    gh pr create -d --title "Release v$PKG_VERSION" --body="$GIT_NOTES"

    if [ "$LAST_TAG" != "" ]; then
        gh release create -d "$PKG_VERSION" --target "$REL_BRANCH" --title "$PKG_VERSION" --notes "$GIT_URL_NOTES"
    fi
fi
