#!node
const fs = require('node:fs')

const ESLINT_CONFIG_VERSION = '^2.0.4'

const pkg = JSON.parse(fs.readFileSync('./package.json'))

// the major of a semver range: ^8.57.0 -> 8, >=10.8.0 -> 10
function majorVersion(range) {
  const match = /^\D*(\d+)\./.exec(range ?? '')
  return match ? Number(match[1]) : null
}

if (majorVersion(pkg?.devDependencies?.eslint) === 8) {
  console.log(`DELETE eslint 8: ${pkg.devDependencies.eslint}`)
  delete pkg.devDependencies.eslint
}

if (pkg?.devDependencies?.['eslint-plugin-haraka']) {
  delete pkg.devDependencies['eslint-plugin-haraka']
  pkg.devDependencies['@haraka/eslint-config'] = ESLINT_CONFIG_VERSION
}

if (pkg.name?.includes('haraka')) {
  if (pkg?.devDependencies?.['@haraka/eslint-config'] !== ESLINT_CONFIG_VERSION) {
    pkg.devDependencies['@haraka/eslint-config'] = ESLINT_CONFIG_VERSION
  }
}

if (pkg.scripts === undefined) pkg.scripts = {}

// bump a major pinned in a script: `npx mocha@^10 …` -> `npx mocha@^11 …`.
function bumpScriptPin(scripts, name, tool, fromMajor, toMajor) {
  if (typeof scripts[name] !== 'string') return
  const pin = new RegExp(`(${tool}@\\^)${fromMajor}(?![0-9])[\\w.-]*`, 'g')
  scripts[name] = scripts[name].replace(pin, `$1${toMajor}`)
}

bumpScriptPin(pkg.scripts, 'test', 'mocha', 10, 11)

if (!pkg.scripts['test:coverage']) {
  pkg.scripts['test:coverage'] =
    'npx c8 --reporter=text --reporter=text-summary npm test'
}

for (const s of ['lint', 'lint:fix']) {
  bumpScriptPin(pkg.scripts, s, 'eslint', 8, 9)
}

if (!process.env.SKIP_PRETTIER) {
  if (!pkg.prettier) {
    pkg.prettier = {
      printWidth: 90,
      singleQuote: true,
      semi: false,
    }
  }

  if (!pkg.scripts.format) {
    pkg.scripts.format = 'npm run prettier:fix && npm run lint:fix'
  }

  if (!pkg.scripts.prettier) {
    pkg.scripts.prettier = 'npx prettier . --check'
  }

  if (!pkg.scripts['prettier:fix']) {
    pkg.scripts['prettier:fix'] = 'npx prettier . --write --log-level=warn'
  }
}

if (pkg.scripts?.versions !== 'npx npm-dep-mgr check') {
  pkg.scripts.versions = 'npx npm-dep-mgr check'
}

if (pkg.scripts['versions:fix'] !== 'npx npm-dep-mgr update') {
  pkg.scripts['versions:fix'] = 'npx npm-dep-mgr update'
}

fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2))
