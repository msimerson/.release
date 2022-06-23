# ChangeLog

### Unreleased

### 2.1.0 - 2022-06-23

- feat: add npm/prepend-scope.cjs
- feat(submit): prepend release tags with v, GHA requires it
- doc: change submodule URL from http to ssh


### 2.0.0 - 2022-05-31

- feat: permit main branch to be 'main', was 'master'
- feat: auto-insert commit messages since last tag into CHANGELOG
- feat: create PR automatically
    - rel create: target branch main
- feat: create Release automatically
- breaking: rename scripts
    - before: do, push, clean. after: start, submit, finish
- doc(CHANGELOG.md): added
- doc(CH): only add bits when missing
- doc(README): fix, code fences should be sh


### 1.0.0 - 2022-05-29

- initial release

