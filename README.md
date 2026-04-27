# carlosvaz.com

Source for <https://carlosvaz.com>.

The site is built from `content-org/all-posts.org` with `ox-hugo`, rendered by
Hugo, and served from the VPS at `/var/www/carlosvaz.com`.

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

`public/`, `resources/`, and exported Markdown under `content/` are generated
artifacts. Keep source edits in `content-org/`, `layouts/`, `static/`,
`hugo.toml`, and the flake.
