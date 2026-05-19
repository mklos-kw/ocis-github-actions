# oCIS GitHub Actions

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![Latest Release](https://img.shields.io/github/v/release/mklos-kw/ocis-github-actions)](https://github.com/mklos-kw/ocis-github-actions/releases)

GitHub Actions for running [ownCloud Infinite Scale (oCIS)](https://github.com/owncloud/ocis) acceptance tests in CI.

| Action | Description |
|---|---|
| [`ocis-setup`](#ocis-setup) | Start a full oCIS instance with optional services |
| [`ocis-start-direct`](#ocis-start-direct) | Start oCIS without ociswrapper; exposes Docker bridge IP |
| [`ocis-test`](#ocis-test) | Run Behat acceptance tests against a running oCIS instance |

Pin to a release tag to avoid unexpected breakage:

```yaml
uses: mklos-kw/ocis-github-actions/ocis-setup@v1
```

---

## `ocis-setup`

Installs oCIS, builds ociswrapper, installs Composer dependencies, starts optional services (Mailpit, ClamAV, Tika), and waits for oCIS to be healthy. Designed for Behat acceptance test jobs.

### Inputs

| Name | Required | Default | Description |
|---|---|---|---|
| `ocis-binary` | No | `""` | Path to a pre-built oCIS binary. When set, `ocis-version` is ignored. |
| `ocis-version` | No | `latest` | oCIS release version to download (e.g. `8.0.1`). Ignored when `ocis-binary` is set. |
| `admin-password` | No | `admin` | Admin user password. |
| `log-level` | No | `error` | oCIS log level. |
| `demo-users` | No | `false` | Create demo users (einstein, marie, feynman, …). |
| `wrapper` | No | `true` | Start ociswrapper on `:5200` for dynamic reconfiguration. |
| `tika` | No | `false` | Start Apache Tika on `:9998` for full-text search. |
| `email` | No | `false` | Start Mailpit SMTP (`:1025`) and API (`:8025`). |
| `antivirus` | No | `false` | Start ClamAV on `:3310` and enable postprocessing. |
| `extra-server-env` | No | `{}` | JSON object of additional env vars passed to the oCIS server. |

### Outputs

| Name | Description |
|---|---|
| `ocis-url` | oCIS instance URL (`https://localhost:9200`) |

### Usage

```yaml
jobs:
  acceptance:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup oCIS
        uses: mklos-kw/ocis-github-actions/ocis-setup@v1
        with:
          ocis-binary: ocis/bin/ocis
          demo-users: 'true'
          email: 'true'
          extra-server-env: >-
            {"OCIS_ADD_RUN_SERVICES":"ocm,notifications",
             "OCIS_ENABLE_OCM":"true"}

      - name: Run tests
        uses: mklos-kw/ocis-github-actions/ocis-test@v1
        with:
          suite: apiSharing
```

---

## `ocis-start-direct`

Starts oCIS as a plain `ocis server` process (no ociswrapper). Uses the Docker bridge gateway IP as `OCIS_URL` so Docker containers can reach the host-side oCIS process. Suited for litmus, cs3api, and WOPI validator jobs.

### Inputs

| Name | Required | Default | Description |
|---|---|---|---|
| `ocis-binary` | **Yes** | — | Path to a pre-built oCIS binary. |
| `demo-users` | No | `false` | Create demo users. |
| `exclude-services` | No | `idp` | Value for `OCIS_EXCLUDE_RUN_SERVICES`. |
| `extra-server-env` | No | `{}` | JSON object of additional env vars passed to the oCIS server. |

### Outputs

| Name | Description |
|---|---|
| `bridge-ip` | Docker bridge gateway IP (reachable from both host and containers) |
| `ocis-url` | oCIS URL using bridge IP (`https://<bridge-ip>:9200`) |

### Environment variables set

`OCIS_BRIDGE_IP` is written to `$GITHUB_ENV` so subsequent steps can reference the bridge IP without using the output syntax.

### Usage

```yaml
jobs:
  cs3api:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Start oCIS
        id: ocis
        uses: mklos-kw/ocis-github-actions/ocis-start-direct@v1
        with:
          ocis-binary: ocis/bin/ocis
          extra-server-env: >-
            {"GATEWAY_GRPC_ADDR":"0.0.0.0:9142",
             "OCIS_SHARING_PUBLIC_SHARE_MUST_HAVE_PASSWORD":"false"}

      - name: Run cs3api-validator
        run: |
          docker run --rm --entrypoint /usr/bin/cs3api-validator \
            owncloud/cs3api-validator:0.2.1 /var/lib/cs3api-validator \
            --endpoint=${{ env.OCIS_BRIDGE_IP }}:9142

      - name: Stop oCIS
        if: always()
        run: |
          if [[ -f /tmp/ocis-direct.pid ]]; then
            kill "$(cat /tmp/ocis-direct.pid)" 2>/dev/null || true
          fi
```

---

## `ocis-test`

Runs Behat acceptance tests against a running oCIS instance via `make test-acceptance-api` in the consuming repository.

### Inputs

| Name | Required | Default | Description |
|---|---|---|---|
| `suite` | **Yes** | — | Behat suite(s) to run, comma-separated (e.g. `apiGraph` or `apiAntivirus,apiSettings`). |
| `ocis-url` | No | `https://localhost:9200` | oCIS instance URL. |
| `expected-failures-file` | No | `""` | Path to expected failures markdown, relative to repo root. |
| `acceptance-test-type` | No | `api` | Test type (`api` or `core-api`). Controls `ACCEPTANCE_TEST_TYPE` and Behat filter tags. |
| `with-remote-php` | No | `false` | Include remote.php expected failures (`WITH_REMOTE_PHP`). |

### Usage

```yaml
      - name: Run apiGraph tests
        uses: mklos-kw/ocis-github-actions/ocis-test@v1
        with:
          suite: apiGraph
          expected-failures-file: tests/acceptance/expected-failures-API-on-OCIS-storage.md
```

---

## Required files in the consuming repository

These files must exist in the consuming repository — they are instance-specific configuration that the actions reference at runtime:

| File | Used by | Purpose |
|---|---|---|
| `tests/config/ci/ocis-config.json` | `ocis-setup`, `ocis-start-direct` | Web UI configuration (`WEB_UI_CONFIG_FILE`) |
| `tests/config/ci/NotoSans.ttf` | `ocis-setup` | Thumbnail font (`THUMBNAILS_TXT_FONTMAP_FILE`) |
| `tests/config/translations/` | `ocis-setup` | Translation files (`OCIS_TRANSLATION_PATH`) |
| `tests/config/ci/app-registry.yaml` | `ocis-start-direct` | MIME type registry, copied to `~/.ocis/config/` |

---

## License

[Apache 2.0](LICENSE)
