const child = require('node:child_process')
const fs = require('fs')

const repoInfoRaw = child.spawnSync('gh', [
  'repo',
  'view',
  '--json',
  'nameWithOwner',
  '-q',
  '.nameWithOwner',
])
if (repoInfoRaw.stderr.length) {
  console.error(repoInfoRaw.stderr.toString())
  process.exit(1)
}

const repoInfo = repoInfoRaw.stdout.toString().trim()

const contributorsRaw = child.spawnSync('gh', [
  'api',
  '-H',
  'Accept: application/vnd.github+json',
  '-H',
  'X-GitHub-Api-Version: 2022-11-28',
  `/repos/${repoInfo}/contributors`,
])
if (contributorsRaw.stderr.length) {
  console.error(contributorsRaw.stderr.toString())
  process.exit(1)
}

const exclude = [
  'greenkeeper',
  'greenkeeper[bot]',
  'synk',
  'dependabot',
  'dependabot[bot]',
]

const contributors = JSON.parse(contributorsRaw.stdout.toString()).filter(
  (c) => !exclude.includes(c.login),
)

const columns = contributors.length < 7 ? contributors.length : 7
const blankRow = '| '.repeat(columns) + '|'
const seperatorRow = '| :---: '.repeat(columns) + '|'

const lines = []
let row = ``
let count = 0
for (contrib of contributors) {
  row += `| <img height="80" src="${contrib.avatar_url}"><br><a href="${contrib.html_url}">${contrib.login}</a> (<a href="https://github.com/haraka/haraka-plugin-access/commits?author=${contrib.login}">${contrib.contributions}</a>)`
  count++
  if (count % columns === 0) {
    row += `|`
    lines.push(row)
    if (lines.length === 1) lines.push(seperatorRow)
    row = ``
  }
}
if (lines.length < 1) {
  lines.push(row + `|`, seperatorRow)
  row = ''
}
if (row !== '') lines.push(row)

fs.writeFileSync(
  'CONTRIBUTORS.md',
  `
# Contributors

This handcrafted artisinal software is brought to you by:

${lines.join('\n')}

<sub>this file is maintained by [.release](https://github.com/msimerson/.release)</sub>
`,
)
