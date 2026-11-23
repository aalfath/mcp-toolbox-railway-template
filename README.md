# MCP Toolbox for Databases on Railway

Railway template for [MCP Toolbox for Databases](https://github.com/googleapis/mcp-toolbox) (`googleapis/mcp-toolbox`, Apache-2.0), Google's open-source MCP server that gives AI agents ready-made, configurable tools over PostgreSQL, MySQL, SQL Server, SQLite, BigQuery, Spanner and many other databases.

## What the template deploys

| Service | What it does |
|---|---|
| **MCP Toolbox** (built from this repo) | MCP Toolbox for Databases **1.18.0** (official image, pinned by digest) as a remote MCP server (streamable HTTP at `/mcp`, SSE at `/mcp/sse`). A small Caddy gate in the same container is the only thing on the public port: every request needs `Authorization: Bearer <MCP_AUTH_TOKEN>`, anything else gets 401. `/healthz` stays open for Railway's health check. |
| **Postgres** (Railway's PostgreSQL) | The working example database, on its own volume, reached over Railway's private network. Toolbox starts with its 29 prebuilt PostgreSQL tools pointed at it. |

Toolbox itself keeps no state, so it has no volume; your data lives in PostgreSQL.

## Variables

| Variable | Default | What it is |
|---|---|---|
| `MCP_AUTH_TOKEN` | `${{secret(48)}}` | Generated bearer token. MCP clients send `Authorization: Bearer <token>`. |
| `POSTGRES_HOST`, `POSTGRES_PORT`, `POSTGRES_DATABASE`, `POSTGRES_USER`, `POSTGRES_PASSWORD` | references to the Postgres service | The database Toolbox serves. Point them at any other PostgreSQL to serve that one instead (use a least-privilege role for real data). |
| `PORT` | `8080` | Public port of the gate. |

Optional, not set by default:

- `TOOLBOX_PREBUILT`: prebuilt tool sets to load (comma-separated, default `postgres`; for example `mysql`, `mssql`, `postgres/data`). Each one reads its own connection variables, see [prebuilt configs](https://mcp-toolbox.dev/documentation/configuration/prebuilt-configs/).
- `TOOLS_YAML` or `TOOLS_YAML_BASE64`: your own `tools.yaml` (raw, or base64 if your YAML trips Railway's API filter). When set, it replaces the prebuilt tools. Use `${ENV_VAR}` placeholders in it for passwords.
- `TOOLBOX_EXTRA_ARGS`: extra flags for `toolbox` (for example `--enable-api`).

## Connect a client

```json
{
  "mcpServers": {
    "toolbox": {
      "type": "http",
      "url": "https://YOUR-DOMAIN/mcp",
      "headers": { "Authorization": "Bearer YOUR_MCP_AUTH_TOKEN" }
    }
  }
}
```

Claude Code: `claude mcp add --transport http toolbox https://YOUR-DOMAIN/mcp --header "Authorization: Bearer YOUR_MCP_AUTH_TOKEN"`.

Whoever holds the token can run any SQL the configured database role allows (the prebuilt set includes `execute_sql`). Keep the token secret, and use a read-only role or your own `tools.yaml` for production data.

## Resources

Runs in about 60 MB of RAM; Railway's Free plan (0.5 GB per service) is plenty. The Go runtime is capped with `GOMEMLIMIT=300MiB`. If Toolbox or the gate stops unexpectedly, the container exits non-zero so Railway restarts it.

## Updates

The service builds from this repo. When a new Toolbox release is tested, we bump the pinned image in `Dockerfile`, add a `CHANGELOG.md` entry, and merge to `main`; Railway then shows an "update available" notice on your project, and you choose when to apply it. Read `CHANGELOG.md` first: breaking changes are listed at the top of each entry.

## Licence

This wrapper: Apache-2.0, like MCP Toolbox for Databases itself.
