#!node
const fs = require('node:fs')

const pkg = JSON.parse(fs.readFileSync('./package.json'))
if (/8\./.test(pkg.devDependencies.eslint)) {
  console.log(`DELETE eslint 8: ${pkg.devDependencies.eslint}`)
  delete pkg.devDependencies.eslint
}

if (pkg.devDependencies['eslint-plugin-haraka']) {
  delete pkg.devDependencies['eslint-plugin-haraka']
  pkg.devDependencies['@haraka/eslint-config'] = '^2.0.2'
}

if (
  pkg.devDependencies['@haraka/eslint-config'] &&
  pkg.devDependencies['@haraka/eslint-config'] !== '^2.0.2'
) {
  pkg.devDependencies['@haraka/eslint-config'] = '^2.0.2'
}

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

if (!pkg.scripts.versions) {
  pkg.scripts.versions = 'npx dependency-version-checker check'
}

if (!pkg.scripts['versions:fix']) {
  pkg.scripts['versions:fix'] = 'npx dependency-version-checker update'
}

fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2))
