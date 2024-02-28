#!/bin/sh

. .release/base.sh || exit 1

if branch_is_main; then
    echo "ERROR: run the push script in a feature branch! (not main)"
    exit 1
fi

assure_repo_is_clean || exit 1

if grep -q '"lint"' package.json; then
    npm run lint || exit 1
fi

if grep -q '"format"' package.json; then
    npm run format
    repo_is_clean || git add . && git commit -m 'lint & format'
fi

REL_BRANCH=$(git branch --show-current)
PKG_VERSION=$(node -e 'console.log(require("./package.json").version)')
LAST_TAG=$(git describe --tags --abbrev=0)
REPO_URL=$(gh repo view --json url -q ".url")
GIT_NOTES=$(git log --pretty=format:"- %s" "$LAST_TAG..HEAD")
GIT_URL_NOTES=$(git log --pretty=format:"- [%h]($REPO_URL/commit/%h) %s" "$LAST_TAG..HEAD")

git push --set-upstream origin "$REL_BRANCH" || exit 1

if command -v gh; then
    gh pr create -d --title "Release v$PKG_VERSION" --body="$GIT_NOTES"

    if [ "$LAST_TAG" != "" ]; then
		# GitHub Actions requires the v prefix in the tag
        gh release create "v$PKG_VERSION" --draft --target "$MAIN_BRANCH" --title "$PKG_VERSION" --notes "$GIT_URL_NOTES"
    fi
fi
