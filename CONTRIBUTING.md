# Contributing

1. Fork the repo and create a branch from `main`.
2. Make your changes. When modifying an `action.yml`, update the inputs/outputs tables in `README.md` to match.
3. Test your changes by pointing a consuming workflow at your branch ref:
   ```yaml
   uses: mklos-kw/ocis-github-actions/ocis-setup@your-branch
   ```
4. Open a pull request. CI runs `actionlint` on all `action.yml` files automatically.

For bugs or feature requests, open an issue using the provided templates.
