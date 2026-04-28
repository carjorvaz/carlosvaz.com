# carlosvaz.com

Source for <https://carlosvaz.com>.

The site is built from `content-org/all-posts.org` with `ox-hugo`, rendered by
Hugo, and served from the VPS at `/var/www/carlosvaz.com`.

The canonical source is this repository. `public/`, `resources/`, and exported
Markdown under `content/` are generated artifacts and should not be edited by
hand.

## Workflow

Preview locally:

```sh
nix run .#serve
```

Build the production site:

```sh
nix build .#site
```

Deploy to the VPS:

```sh
nix run .#deploy
```

To deploy somewhere other than the production VPS, set
`CARLOSVAZ_DEPLOY_TARGET` to an rsync destination:

```sh
CARLOSVAZ_DEPLOY_TARGET=user@example.com:/srv/http/carlosvaz.com/ nix run .#deploy
```

Keep source edits in `content-org/`, `layouts/`, `assets/`, `static/`,
`hugo.toml`, and the flake.

## CI

GitHub Actions builds the site with Nix on pushes and pull requests. A manual
`workflow_dispatch` deploy is included for the VPS; configure these repository
secrets before using it:

- `DEPLOY_SSH_KEY`: private key allowed to write the web root.
- `DEPLOY_KNOWN_HOSTS`: pinned SSH host key line for the VPS.
- `DEPLOY_TARGET`: rsync target, for example
  `root@vaz.one:/var/www/carlosvaz.com/`.

## License

Unless otherwise noted, the site source and content are licensed under
AGPL-3.0-or-later. The vendored Fira Mono font used for social cards is licensed
under the SIL Open Font License; see `assets/fonts/OFL-FiraMono.txt`.
