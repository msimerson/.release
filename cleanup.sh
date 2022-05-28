#!/bin/sh

CURRENT_BRANCH=$(git branch --show-current)

if [ "$CURRENT_BRANCH" != "master" ];
then
    git checkout master
    git branch -d "$CURRENT_BRANCH"
    git pull
fi
