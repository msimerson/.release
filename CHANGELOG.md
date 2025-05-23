# ChangeLog

### Unreleased

### 2.3.2 - 2025-05-19

- finish: only publish draft & bump maj version tag when PR merged

### 2.3.1 - 2025-04-29

- finish: check if release is a draft before setting draft=false
- finish: if there's a major version tag (v1, v2), update it

### 2.3.0 - 2025-01-26

- added js/standards.cjs
  - populates package.json[scripts] and applies common updates
- submit: halt for deprecated eslint rules
- add contributors.js (requires gh, node, & jq)

### 2.2.3 - 2024-04-06

- add start.self_update()
- added base.get_yes_or_no()
- start: include commit body in changelog entry
- add start.changelog_check_tag_urls()
- submit: run format & lint targets, if present
- submit: check for deprecated eslint rules

### 2.2.2 - 2024-04-05

- find_changelog
  - if file not named CHANGELOG, suggest rename
  - if # changelog missing, add it
  - if ### Unreleased is missing, add it
- start: add constrain_publish

### 2.2.1 - 2024-03-06

- feat(submit): run lint & formatting

### 2.2.0 - 2024-02-29

- feat: support pre-release versions
- feat(finish): delete remote branch
- doc(README): add submodule checkout instructions

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
- doc(README): code fences should be sh

### 1.0.0 - 2022-05-29

- initial release
