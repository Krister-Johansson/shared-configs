# Contributing to {{PACKAGE_NAME}}

Thanks for your interest in contributing!

## Reporting bugs and requesting features

- Open a [GitHub issue](https://github.com/{{REPO_SLUG}}/issues) for bugs and feature requests.
- **Security vulnerabilities**: never open a public issue — see [SECURITY.md](SECURITY.md).

## Development workflow

This project works **issue-first** and **test-driven**:

1. **Every change starts as an issue.** Before writing code, make sure an issue
   exists that describes the bug or feature. Open one if it doesn't.
2. **Write the test first (TDD).** Add a failing test that captures the expected
   behavior, confirm it fails, then implement until it passes, then refactor.
   New functionality and bug fixes without tests are not accepted.
3. Branch from `main`, keep the change focused on the issue.
4. **Every PR must reference its issue** (`Closes #<number>` in the description) —
   CI enforces this.

## Development setup

- Node.js >= {{NODE_MIN}}
- `npm install`

| Command | Purpose |
| --- | --- |
| `npm run build` | Compile to `dist/` |
| `npm run typecheck` | Type-check without emitting |
| `npm test` | Run the test suite |
| `npm run coverage` | Tests with coverage report |

Run the local CI equivalent before pushing:

```sh
npm run build && npm run typecheck && npm run coverage
```

(plus `npm run lint` if the repo has a lint script)

## Coding standards

- TypeScript strict mode; match the style of the surrounding code.
- Keep the public API surface deliberate — new exports need an issue that motivates them.

## Commit messages

Use [Conventional Commits](https://www.conventionalcommits.org/) — they drive
automated releases via release-please:

- `feat: ...` new functionality (minor bump)
- `fix: ...` bug fixes (patch bump)
- `docs: ...`, `chore: ...`, `test: ...`, `refactor: ...` no release
- `feat!: ...` or a `BREAKING CHANGE:` footer for breaking changes (major bump)

## License

By contributing, you agree that your contributions are licensed under the MIT License.
