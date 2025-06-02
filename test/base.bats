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

@test "repo_is_clean returns 1 on dirty repo" {
  echo foo > temp.txt
  run bash -c '. ./base.sh; repo_is_clean'
  [ "$status" -eq 1 ]
  rm temp.txt
}
