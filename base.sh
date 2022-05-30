#!/bin/sh

get_main_branch()
{
    MAIN_BRANCH="main"

    if [ -z "$(git branch -l main)" ]; then
        MAIN_BRANCH="master"
    fi

    export MAIN_BRANCH
}

branch_is_main()
{
    get_main_branch

    if [ "$(git branch --show-current)" = "$MAIN_BRANCH" ]; then
        return 0
    fi

    return 1
}

repo_is_clean()
{
    if [ -z "$(git status --porcelain)" ]; then
        return 0
    fi

    return 1
}

assure_repo_is_clean()
{
    if repo_is_clean; then return 0; fi

    echo
    echo "ERROR: Uncommitted changes, cowardly refusing to continue..."
    echo
    sleep 2

    git status

    return 1
}

find_changelog()
{
    CHANGELOG=$(ls [Cc][Hh][Aa]*.md)
    export CHANGELOG
    #echo "I found your CHANGELOG at: $CHANGELOG"
}
