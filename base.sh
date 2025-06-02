#!/bin/sh

get_yes_or_no()
{
    printf "%s (y/n)? " "$1"
    old_stty_cfg=$(stty -g)
    stty raw -echo
    answer=$( while ! head -c 1 | grep -i '[nNyY]' ;do true ;done )
    stty "$old_stty_cfg"
    case "$answer" in
        [Yy]) return 0 ;; # yes
        *) return 1 ;; # no
    esac
}

release_get_choice()
{
    trap "exit" INT
    while true; do
        printf 'Select option: ' >&2
        read -r n
        for _i in "$@"; do
            if [ "$_i" = "$n" ]; then break 2; fi
        done
    done
    printf "%s\n" "$n"
}

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
    # shellcheck disable=SC2012
    CHANGELOG=$(ls [Cc][Hh][Aa]*.md 2>/dev/null | head -n 1)
    #echo "I found your CHANGELOG at: $CHANGELOG"
    if [ "$CHANGELOG" != "CHANGELOG.md" ]; then
        echo "REF: https://keepachangelog.com/"
        echo "please consider: git mv $CHANGELOG CHANGELOG.md"
    fi
    export CHANGELOG
}

file_has_changes()
{
    if git diff --quiet -- "$1"; then
        return 1  # no changes
    fi
    return 0      # has changes
}
