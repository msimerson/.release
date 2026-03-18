#!/usr/bin/env bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
  ./base.sh
}

@test "get_yes_or_no returns 0 for y" {
  run bash -c '. ./base.sh; echo y | get_yes_or_no "Continue"'
  [ "$status" -eq 0 ]
}

@test "get_yes_or_no returns 1 for n" {
  run bash -c '. ./base.sh; echo n | get_yes_or_no "Continue"'
  [ "$status" -eq 1 ]
}

@test "release_get_choice returns valid option" {
  run bash -c '. ./base.sh; echo foo | release_get_choice foo bar'
  assert_output --partial 'foo'
}

@test "get_main_branch sets MAIN_BRANCH to main or master" {
  run bash -c '. ./base.sh; get_main_branch; echo $MAIN_BRANCH'
  [[ "$output" == "main" || "$output" == "master" ]]
}

@test "branch_is_main returns 0 on main branch" {
  git checkout -B main 2>/dev/null || git checkout -B master
  run bash -c '. ./base.sh; branch_is_main'
  [ "$status" -eq 0 ]
}

@test "find_changelog finds CHANGELOG.md" {
  run bash -c '. ./base.sh; find_changelog; echo $CHANGELOG'
  assert_output --partial 'CHANGELOG.md'
}

@test "get_yes_or_no returns 0 for Y (uppercase)" {
  run bash -c '. ./base.sh; echo Y | get_yes_or_no "Continue"'
  [ "$status" -eq 0 ]
}

@test "release_get_choice rejects invalid then accepts valid" {
  run bash -c '. ./base.sh; printf "bad\nfoo\n" | release_get_choice foo bar'
  assert_output --partial 'foo'
  [ "$status" -eq 0 ]
}

@test "repo_is_clean returns 1 on dirty repo" {
  echo foo > temp.txt
  run bash -c '. ./base.sh; repo_is_clean'
  [ "$status" -eq 1 ]
  rm temp.txt
}

@test "repo_is_clean returns 0 on clean repo" {
  git stash --include-untracked >/dev/null 2>&1
  run bash -c '. ./base.sh; repo_is_clean'
  git stash pop >/dev/null 2>&1 || true
  [ "$status" -eq 0 ]
}

@test "assure_repo_is_clean returns 0 on clean repo" {
  _stashed=0
  if ! git diff --quiet || ! git diff --cached --quiet; then
    git stash --include-untracked >/dev/null 2>&1 && _stashed=1
  fi
  run bash -c '. ./base.sh; assure_repo_is_clean'
  [ "$_stashed" -eq 1 ] && git stash pop >/dev/null 2>&1 || true
  [ "$status" -eq 0 ]
}

@test "assure_repo_is_clean returns 1 on dirty repo" {
  echo foo > temp.txt
  run bash -c '. ./base.sh; assure_repo_is_clean'
  [ "$status" -eq 1 ]
  rm temp.txt
}

@test "file_has_changes returns 1 for unchanged file" {
  run bash -c '. ./base.sh; file_has_changes README.md'
  [ "$status" -eq 1 ]
}

@test "file_has_changes returns 0 for modified file" {
  echo "# test" >> README.md
  run bash -c '. ./base.sh; file_has_changes README.md'
  git checkout README.md 2>/dev/null
  [ "$status" -eq 0 ]
}

@test "add_commit_messages categorizes conventional commits" {
  tmpdir=$(mktemp -d)
  git init "$tmpdir" >/dev/null 2>&1
  git -C "$tmpdir" config user.email "test@test.com"
  git -C "$tmpdir" config user.name "Test"
  git -C "$tmpdir" commit --allow-empty -m "feat: add something" >/dev/null 2>&1
  git -C "$tmpdir" commit --allow-empty -m "fix: fix a bug" >/dev/null 2>&1
  git -C "$tmpdir" commit --allow-empty -m "chore: tidy up" >/dev/null 2>&1
  mkdir -p "$tmpdir/.release"
  : > "$tmpdir/.release/new.txt"
  run bash -c "
    cd '$tmpdir'
    . '$BATS_TEST_DIRNAME/../base.sh'
    NEW_VERSION=9.9.9 YMD=2026-01-01
    add_commit_messages
    cat .release/new.txt
  "
  rm -rf "$tmpdir"
  assert_output --partial 'Added'
  assert_output --partial 'Fixed'
  assert_output --partial 'Changed'
}

@test "add_commit_messages falls back to flat list for non-conventional commits" {
  tmpdir=$(mktemp -d)
  git init "$tmpdir" >/dev/null 2>&1
  git -C "$tmpdir" config user.email "test@test.com"
  git -C "$tmpdir" config user.name "Test"
  git -C "$tmpdir" commit --allow-empty -m "some random commit message" >/dev/null 2>&1
  mkdir -p "$tmpdir/.release"
  : > "$tmpdir/.release/new.txt"
  run bash -c "
    cd '$tmpdir'
    . '$BATS_TEST_DIRNAME/../base.sh'
    NEW_VERSION=9.9.9 YMD=2026-01-01
    add_commit_messages
    cat .release/new.txt
  "
  rm -rf "$tmpdir"
  assert_output --partial 'some random commit message'
}
