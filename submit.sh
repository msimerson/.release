#!/bin/sh

. .release/base.sh || exit 1

if branch_is_main; then
    echo "ERROR: run the push script in a feature branch! (not main)"
    exit 1
fi

assure_repo_is_clean || exit 1

# https://eslint.org/blog/2023/10/deprecating-formatting-rules/
for _dep in array-bracket-newline array-bracket-spacing array-element-newline arrow-parens arrow-spacing block-spacing brace-style comma-dangle comma-spacing comma-style computed-property-spacing dot-location eol-last func-call-spacing function-call-argument-newline function-paren-newline generator-star-spacing implicit-arrow-linebreak indent jsx-quotes key-spacing keyword-spacing linebreak-style lines-between-class-members lines-around-comment max-len max-statements-per-line multiline-ternary new-parens newline-per-chained-call no-confusing-arrow no-extra-parens no-extra-semi no-floating-decimal no-mixed-operators no-mixed-spaces-and-tabs no-multi-spaces no-multiple-empty-lines no-tabs no-trailing-spaces no-whitespace-before-property nonblock-statement-body-position object-curly-newline object-curly-spacing object-property-newline one-var-declaration-per-line operator-linebreak padded-blocks padding-line-between-statements quote-props quotes rest-spread-spacing semi semi-spacing semi-style space-before-blocks space-before-function-paren space-in-parens space-infix-ops space-unary-ops spaced-comment switch-colon-spacing template-curly-spacing template-tag-spacing wrap-iife wrap-regex yield-star-spacing; do
    if grep -qs "$_dep" .eslintrc.*; then
        echo "ERROR: deprecated rule '$_dep' found in .eslintrc file"
        exit 1
    fi
done

_format=$(node -e 'console.log(require("./package.json").scripts?.format)')
if [ "$_format" != "undefined" ]; then
    if ! npm run format; then
        exit 1
    fi
fi

_lint=$(node -e 'console.log(require("./package.json").scripts?.lint)')
if [ "$_format" = "undefined" ] && [ "$_lint" != "undefined" ]; then
    if ! npm run lint; then
        if get_yes_or_no "Shall I try to fix?"; then
            if npm run lint:fix; then
                git add .
                git commit -m 'lint: autofix'
            else
                exit 1
            fi
        fi
    fi
fi

REL_BRANCH=$(git branch --show-current)
PKG_VERSION=$(node -e 'console.log(require("./package.json").version)')
LAST_TAG=$(git describe --tags --abbrev=0)
REPO_URL=$(gh repo view --json url -q ".url")
GIT_NOTES=$(git log --pretty=format:"- %s%n%b" "$LAST_TAG..HEAD")
GIT_URL_NOTES=$(git log --pretty=format:"- [%h]($REPO_URL/commit/%h) %s" "$LAST_TAG..HEAD")

git push --set-upstream origin "$REL_BRANCH" || exit 1

if command -v gh; then
    gh pr create -d --title "Release v$PKG_VERSION" --body="$GIT_NOTES"

    if [ "$LAST_TAG" != "" ]; then
		# GitHub Actions requires the v prefix in the tag
        gh release create "v$PKG_VERSION" --draft --target "$MAIN_BRANCH" --title "$PKG_VERSION" --notes "$GIT_URL_NOTES"
    fi
fi
