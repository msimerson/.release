#!/bin/sh

echo "shellcheck *.sh"
shellcheck -x ./*.sh

bats test/*.bats
