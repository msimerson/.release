#!/bin/sh

. .release/base.sh || exit

CURRENT_BRANCH=$(git branch --show-current)
PKG_VERSION=$(node -e 'console.log(require("./package.json").version)')

get_main_branch

delete_remote_branch()
{
    git push origin ":$CURRENT_BRANCH"
    BRANCH_DEL="-D"
}

edit_release_body()
{
    # update the release body to the contents of the PR body
    PR_BODY="$(gh pr view --json body --jq .body)"
    if [ -n "$PR_BODY" ]; then
        gh release edit "v$PKG_VERSION" --notes "$PR_BODY"
    fi
}

update_major_version_tag()
{
    if [ -z "$PKG_VERSION" ]; then return; fi

    MAJOR=${PKG_VERSION%%.*}
    SHORT=$(git tag -l | grep "^v${MAJOR}$")
    if [ -z "$SHORT" ]; then return; fi

    git tag -d "v$MAJOR"
    git tag "v$MAJOR"
    git push --force origin v1
}

# publish the the draft release
if command -v gh; then
    IS_DRAFT=$(gh release view "v$PKG_VERSION" --json isDraft --jq '.isDraft')
    if [ "$IS_DRAFT" = "true" ]; then
        gh release edit "v$PKG_VERSION" --draft=false
        update_major_version_tag
    fi
fi

if [ "$CURRENT_BRANCH" != "$MAIN_BRANCH" ];
then
    # if the PR is merged, delete the remote branch
    _state=$(gh pr view "$CURRENT_BRANCH" | grep -i state | awk '{ print $2 }')
    if [ "$_state" = "MERGED" ]; then
        delete_remote_branch
        edit_release_body
    fi

    git checkout "$MAIN_BRANCH"
    git pull
    git branch "${BRANCH_DEL:='-d'}" "$CURRENT_BRANCH"
fi
