# .release

git release scripts for NPM modules

## DESCRIPTION

BASH release scripts for NPM modules hosted on GitHub. The scripts automate away much of the tedium of cutting releases while:

- leaving the author(s) in complete control
- maintaining a very high signal to noise ratio

Cutting a release is split into three steps: start, submit, and finish. Each step is documented below and is independent, permitting authors to use only the steps that fit their workflow.

## USAGE

In your github repo:

```sh
git submodule add git@github.com:msimerson/.release.git
```

In newly checked out repos where .release exists, checkout the submodule with:

```sh
git submodule update --init --recursive
```

For each release, run 3 commands:

```sh
.release/start.sh [ major | minor | patch | prerelease ]
# do local coding & commit changes
.release/submit.sh
# submit the changes, create PR, see if CI tests pass
.release/finish.sh
# cleanup
```

---

### Start a release

```sh
.release/start.sh [ major | minor | patch | prerelease ]
```

This will:

- create a branch named release-N.N.N
- bump the version number in package.json
- add a versioned entry to CHANGELOG with today's date
- open CHANGELOG in your markdown editor (if `open` exists)

---

### Submit your release

After making all your changes, editing your CHANGELOG, and committing all your changes:

```sh
.release/submit.sh
```

This will:

- when defined in package.json[scripts]
  - run "format" (think: autopilot mode)
    - example: "format": "npm run prettier:fix && npm run lint:fix && git add . && git commit -m format",
  - when format not defined, run `npm run format:check` && `npm run lint` (check only)
- push the changes to origin/$branch
- if `gh` is installed:
  - create a draft Pull Request
  - create a draft Release

The body of the PR and the Release will be the commit messages in your repo since the most recent tag.

---

### Finish

After your PR is merged, finish it:

```sh
.release/finish.sh
```

This will:

- if `gh` is installed:
  - publish the release
- switch to the main branch
- pull changes from origin
- delete the release branch
