#!/bin/sh

get_yes_or_no()
{
    printf "%s (y/n)? " "$1"
    old_stty_cfg=$(stty -g)
    trap 'stty $old_stty_cfg; exit' INT TERM
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

    if [ -z "$(git branch -l $MAIN_BRANCH)" ]; then
        MAIN_BRANCH="master"
    fi

    if [ -z "$(git branch -l $MAIN_BRANCH)" ]; then
        # no local branch, probably new repo, try remote
        MAIN_BRANCH=$(git remote show origin | grep 'HEAD branch' | awk '{print $NF}')
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

add_commit_messages() {

    if [ -z "$(git tag)" ]; then
        _log_range="HEAD"
    else
        LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo '')
        if [ -z "$LAST_TAG" ]; then
            _log_range="HEAD"
        else
            _log_range="$LAST_TAG..HEAD"
        fi
    fi

    # Categorize by conventional commit prefix; collect remainder as uncategorized
    _added=""
    _fixed=""
    _changed=""
    _other=""

    while IFS= read -r _msg; do
        [ -z "$_msg" ] && continue
        case "$_msg" in
            feat:*|feat\(*\):*)
                _added="$_added\n- ${_msg#*: }"
                ;;
            fix:*|fix\(*\):*)
                _fixed="$_fixed\n- ${_msg#*: }"
                ;;
            chore:*|chore\(*\):*|refactor:*|perf:*|style:*|docs:*|test:*|build:*|ci:*)
                _changed="$_changed\n- ${_msg#*: }"
                ;;
            *)
                _other="$_other\n- $_msg"
                ;;
        esac
    done <<EOF
$(git log --pretty=format:"%s" "$_log_range")
EOF

    # Append categorized sections, falling back to a flat list if nothing matched
    if [ -z "$_added$_fixed$_changed" ]; then
        git log --pretty=format:"- %s" "$_log_range" >> .release/new.txt
        return
    fi

    if [ -n "$_added" ]; then
        printf '\n#### Added\n' >> .release/new.txt
        printf '%b\n' "$_added" >> .release/new.txt
    fi
    if [ -n "$_fixed" ]; then
        printf '\n#### Fixed\n' >> .release/new.txt
        printf '%b\n' "$_fixed" >> .release/new.txt
    fi
    if [ -n "$_changed" ]; then
        printf '\n#### Changed\n' >> .release/new.txt
        printf '%b\n' "$_changed" >> .release/new.txt
    fi
    if [ -n "$_other" ]; then
        printf '\n#### Other\n' >> .release/new.txt
        printf '%b\n' "$_other" >> .release/new.txt
    fi
}
