#!/bin/sh

. .release/base.sh || exit

CURRENT_BRANCH=$(git branch --show-current)

get_main_branch

if [ "$CURRENT_BRANCH" != "$MAIN_BRANCH" ];
then
    git checkout "$MAIN_BRANCH"
    git branch -d "$CURRENT_BRANCH"
    git pull
fi
