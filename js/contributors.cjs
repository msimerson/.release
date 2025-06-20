const child = require('node:child_process')
const fs = require('node:fs')

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

// example: msimerson/.release
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
  'snyk-bot',
  'dependabot',
  'dependabot[bot]',
  'lgtm-com',
  'lgtm-com[bot]',
  'lgtm-migrator',
]

// list of contributors, minus the bots
const contributors = JSON.parse(contributorsRaw.stdout.toString()).filter(
  (c) => !exclude.includes(c.login),
)

// generate the GFM markdown table
const columnsWide = contributors.length < 7 ? contributors.length : 7
const blankRow = '| '.repeat(columnsWide) + '|'
const seperatorRow = '| :---: '.repeat(columnsWide) + '|'

const lines = []
let row = ``
let count = 0
for (contrib of contributors) {
  row += `| <img height="80" src="${contrib.avatar_url}"><br><a href="${contrib.html_url}">${contrib.login}</a> (<a href="https://github.com/${repoInfo}/commits?author=${contrib.login}">${contrib.contributions}</a>)`
  count++
  if (count % columnsWide === 0) {
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
  `# Contributors

This handcrafted artisanal software is brought to you by:

${lines.join('\n')}

<sub>this file is generated by [.release](https://github.com/msimerson/.release).
Contribute to this project to get your GitHub profile included here.</sub>
`,
)
