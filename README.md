# .release

git release scripts for NPM modules

## USAGE

In your github repo:

```sh
git submodule add git@github.com:msimerson/.release.git
```

In newly checked out repos where .release exists, checkout the submodule with:

```sh
git submodule update --init --recursive
```

### Start a release

```sh
.release/start.sh [ major | minor | patch | prerelease ]
```

This will:

- create a branch named release-N.N.N
- bump the version number in package.json
- add a versioned entry to CHANGELOG with today's date
- open CHANGELOG in your markdown editor

Notes:

- Your CHANGELOG file needs an entry like this: ### Unreleased
  - New changelog entries are inserted after that marker
- Opening the file in your editor requires `open`

---

### Submit your release

After making all your changes, editing your CHANGELOG, and committing all your changes:

```sh
.release/submit.sh
```

This will:

- when defined in package.json[scripts]
  - run `npm run lint`
  - run `npm run format`
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
- delete the release branch
- pull changes from origin
