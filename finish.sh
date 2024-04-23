#!/bin/sh

. .release/base.sh || exit

CURRENT_BRANCH=$(git branch --show-current)

get_main_branch

# publish the the draft release
if command -v gh; then
    PKG_VERSION=$(node -e 'console.log(require("./package.json").version)')
    gh release edit "v$PKG_VERSION" --draft=false
fi

if [ "$CURRENT_BRANCH" != "$MAIN_BRANCH" ];
then
    # if the PR is merged, delete the remote branch
    _state=$(gh pr view "$CURRENT_BRANCH" | grep -i state | awk '{ print $2 }')
    if [ "$_state" = "MERGED" ]; then
        git push origin ":$CURRENT_BRANCH"
    fi

    git checkout "$MAIN_BRANCH"
    git pull
    git branch -d "$CURRENT_BRANCH"
fi
