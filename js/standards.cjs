#!node
const fs = require('node:fs')

const ESLINT_CONFIG_VERSION = '^2.0.4'

const pkg = JSON.parse(fs.readFileSync('./package.json'))

if (/8\./.test(pkg?.devDependencies?.eslint)) {
  console.log(`DELETE eslint 8: ${pkg.devDependencies.eslint}`)
  delete pkg.devDependencies.eslint
}

if (pkg?.devDependencies['eslint-plugin-haraka']) {
  delete pkg.devDependencies['eslint-plugin-haraka']
  pkg.devDependencies['@haraka/eslint-config'] = ESLINT_CONFIG_VERSION
}

if (pkg?.devDependencies['@haraka/eslint-config'] !== ESLINT_CONFIG_VERSION) {
  pkg.devDependencies['@haraka/eslint-config'] = ESLINT_CONFIG_VERSION
}

if (pkg.scripts === undefined) pkg.scripts = {}

if (/mocha/.test(pkg.scripts.test)) {
  if (/\^10/.test(pkg.scripts.test)) {
    pkg.scripts.test = pkg.scripts.test.replace('10', '11')
  }
}

for (const s of ['lint', 'lint:fix']) {
  if (/eslint/.test(pkg.scripts[s])) {
    if (/\^8/.test(pkg.scripts[s])) {
      pkg.scripts[s] = pkg.scripts[s].replace('8', '9')
    }
  }
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
