# .release

git release scripts


## USAGE

In your github repo:

```sh
git submodule add https://github.com/msimerson/.release
```

### Start a release

```sh
.release/do.sh [ major | minor | patch ]
```

This will:

- create a branch named release-vN.N.N
- bump the version number in package.json
- add an entry to CHANGE*.md with the version number and today's date
- open the file in your chosen markdown editor

Notes:

- Your CHANGELOG file needs an entry like this: ### Unreleased
    - New changelog entries are inserted after that marker
- Opening the file in your editor requires `open`

----

### Push your release

After making all your changes, editing your CHANGELOG and committing all your changes:

```sh
.release/push.sh
```

This will:

    - push the changes to origin
    - create a Pull Request (if `gh` is installed)
    - create a draft Release

----

### Cleanup

After your PR is merged, cleanup the feature branch with:

```sh
.release/cleanup.sh
```

This will:

- switch to the main branch
- delete the feature branch
- pull changes from origin
