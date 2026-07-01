# oCIS GitHub Actions

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![Latest Release](https://img.shields.io/github/v/release/mklos-kw/ocis-github-actions)](https://github.com/mklos-kw/ocis-github-actions/releases)

GitHub Actions for running [ownCloud Infinite Scale (oCIS)](https://github.com/owncloud/ocis) acceptance tests in CI.

| Action | Description |
|---|---|
| [`ocis-setup`](#ocis-setup) | Start a full oCIS instance with optional services (Keycloak, WOPI, antivirus, email, Tika) |
| [`ocis-test`](#ocis-test) | Run Behat, litmus, WOPI validator, or cs3api tests against a running oCIS instance |

Pin to a release tag to avoid unexpected breakage:

```yaml
uses: mklos-kw/ocis-github-actions/ocis-setup@v1
```

---

## `ocis-setup`

Installs oCIS, optionally builds ociswrapper, installs Composer/libcurl test-runner dependencies, and starts all required services before waiting for oCIS to be healthy.

**Optional services started when their input is `true` / non-empty:**

| Input | Service | Port(s) |
|---|---|---|
| `keycloak: true` | Postgres + Keycloak external IDP | `:8443` |
| `email: true` | Mailpit SMTP + API | `:1025`, `:8025` |
| `antivirus: true` | ClamAV | `:3310` |
| `tika: true` | Apache Tika full-text extraction | `:9998` |
| `collaboration-apps: fakeoffice` | FakeOffice WOPI app | `:8080` |
| `collaboration-apps: collabora` | Collabora CODE + oCIS collaboration service | `:9980`, `:9300` |
| `collaboration-apps: onlyoffice` | OnlyOffice + oCIS collaboration service | `:443`, `:9310` |
| `collaboration-apps: cs3-wopi` | FakeOffice + cs3org/wopiserver + oCIS app-provider | `:8080`, `:9300` |

### Inputs

| Name | Default | Description |
|---|---|---|
| `ocis-version` | `latest` | oCIS release version (e.g. `8.0.1`). Ignored when `ocis-binary` or `ocis-binary-artifact` is set. |
| `ocis-binary` | `""` | Path to a pre-built oCIS binary. |
| `ocis-binary-artifact` | `""` | Artifact name to download the oCIS binary from (downloads to `ocis/bin/ocis`). |
| `ociswrapper-artifact` | `""` | Artifact name to download ociswrapper from. |
| `admin-password` | `admin` | Admin user password. |
| `log-level` | `error` | oCIS log level. |
| `demo-users` | `false` | Create demo users (einstein, marie, feynman, …). |
| `wrapper` | `true` | Start ociswrapper on `:5200` for dynamic reconfiguration. Set to `false` to run `ocis server` directly. |
| `keycloak` | `false` | Start Postgres + Keycloak and configure oCIS to use it as external IDP. |
| `keycloak-realm-file` | `tests/config/ci/ocis-ci-realm.dist.json` | Repo-relative path to the Keycloak realm dist JSON. Only used when `keycloak: true`. |
| `email` | `false` | Start Mailpit SMTP (`:1025`) and API (`:8025`). |
| `antivirus` | `false` | Start ClamAV on `:3310`. |
| `tika` | `false` | Start Apache Tika on `:9998` for full-text search. |
| `collaboration-apps` | `""` | Comma-separated WOPI apps to start: `collabora`, `onlyoffice`, `fakeoffice`, `cs3-wopi`. |
| `collabora-image` | `collabora/code:24.04.5.1.1` | Collabora CODE Docker image. |
| `onlyoffice-image` | `onlyoffice/documentserver:9.0.0` | OnlyOffice Document Server Docker image. |
| `extra-server-env` | `{}` | JSON object of additional env vars passed to the oCIS server process. |
| `ocis-url` | `https://localhost:9200` | oCIS base URL used for init and startup. Use `https://127.0.0.1:9200` for e2e tests. |
| `ocis-config-dir` | `~/.ocis/config` | oCIS config directory path. |
| `pid-file` | `/tmp/ocis-wrapper.pid` | File path to write the oCIS process PID. |
| `log-file` | `/tmp/ocis-server.log` | File path for oCIS server log output. |
| `skip-test-runner-setup` | `false` | Skip PHP/libcurl/Composer setup (set `true` for secondary instances that share the test runner). |
| `docker-accessible` | `false` | Bind oCIS to the Docker bridge IP; exports `OCIS_BRIDGE_IP` and `OCIS_DOCKER_URL`. |
| `debug-port-offset` | `0` | Shift all service ports by this amount — use `1000` for a secondary instance alongside a primary. |
| `web-ui-config` | `""` | Repo-relative path to a web UI config JSON; `ocis-server:9200` is rewritten to match `ocis-url`. |

### Outputs

| Name | Description |
|---|---|
| `ocis-url` | oCIS instance URL |
| `wopi-url` | WOPI source base URL (e.g. `http://localhost:9300`); set when `collaboration-apps` is non-empty |
| `keycloak-domain` | Keycloak domain (`localhost:8443`); set when `keycloak: true` |

### Environment variables set

| Variable | Set when | Value |
|---|---|---|
| `OCIS_CERT` | always | Path to oCIS self-signed TLS cert (trusted system-wide) |
| `KEYCLOAK_CERT` | `keycloak: true` | Path to Keycloak self-signed TLS cert (trusted system-wide) |
| `OCIS_BRIDGE_IP` | `docker-accessible: true` | Docker bridge gateway IP |
| `OCIS_DOCKER_URL` | `docker-accessible: true` | oCIS URL using bridge IP |
| `WOPI_PORT` | `collaboration-apps` non-empty | WOPI port (`9300` for cs3-wopi, `9320` otherwise) |

### Usage

**Behat acceptance tests:**

```yaml
jobs:
  acceptance:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup oCIS
        uses: mklos-kw/ocis-github-actions/ocis-setup@v1
        with:
          ocis-binary-artifact: ocis-binary
          demo-users: 'true'
          email: 'true'

      - name: Run tests
        uses: mklos-kw/ocis-github-actions/ocis-test@v1
        with:
          suite: apiGraph
```

**e2e tests with Keycloak:**

```yaml
      - name: Setup oCIS
        uses: mklos-kw/ocis-github-actions/ocis-setup@v1
        with:
          ocis-binary-artifact: ocis-binary
          ociswrapper-artifact: ociswrapper-binary
          ocis-url: "https://127.0.0.1:9200"
          keycloak: 'true'
          web-ui-config: tests/config/ci/ocis-config.json
```

**WOPI validator (builtin collaboration service):**

```yaml
      - name: Setup oCIS
        uses: mklos-kw/ocis-github-actions/ocis-setup@v1
        with:
          ocis-binary-artifact: ocis-binary
          wrapper: 'false'
          skip-test-runner-setup: 'true'
          collaboration-apps: fakeoffice

      - name: Run WOPI validator
        uses: mklos-kw/ocis-github-actions/ocis-test@v1
        with:
          suite: wopi-builtin
```

**WOPI validator (cs3org/wopiserver):**

```yaml
      - name: Setup oCIS
        uses: mklos-kw/ocis-github-actions/ocis-setup@v1
        with:
          ocis-binary-artifact: ocis-binary
          wrapper: 'false'
          skip-test-runner-setup: 'true'
          collaboration-apps: cs3-wopi
          extra-server-env: |
            {
              "APP_PROVIDER_DRIVER": "wopi",
              "APP_PROVIDER_WOPI_APP_NAME": "FakeOffice",
              "APP_PROVIDER_WOPI_APP_URL": "http://localhost:8080",
              "APP_PROVIDER_WOPI_INSECURE": "true",
              "APP_PROVIDER_WOPI_WOPI_SERVER_EXTERNAL_URL": "http://localhost:9300",
              "APP_PROVIDER_WOPI_FOLDER_URL_BASE_URL": "https://localhost:9200"
            }

      - name: Run WOPI validator
        uses: mklos-kw/ocis-github-actions/ocis-test@v1
        with:
          suite: wopi-cs3
```

---

## `ocis-test`

Runs tests against a running oCIS instance. The `suite` input controls which test type runs:

| `suite` value | What runs |
|---|---|
| `litmus` | litmus WebDAV compliance tests |
| `cs3api` | cs3api-validator |
| `wopi-builtin` | WOPI validator against the built-in oCIS collaboration service |
| `wopi-cs3` | WOPI validator against cs3org/wopiserver |
| anything else | Behat acceptance tests (`make test-acceptance-api`) |

### Inputs

| Name | Required | Default | Description |
|---|---|---|---|
| `suite` | **Yes** | — | Test suite(s) to run (see table above). Multiple Behat suites are comma-separated, e.g. `apiGraph,apiSettings`. |
| `ocis-url` | No | `https://localhost:9200` | oCIS instance URL. |
| `expected-failures-file` | No | `""` | Path to a pre-merged expected failures file. If omitted, the standard files are merged automatically. |
| `acceptance-test-type` | No | `api` | `api` or `core-api` — controls `ACCEPTANCE_TEST_TYPE` and Behat filter tags. |
| `with-remote-php` | No | `false` | Include `remote.php` expected failures. |

### Usage

```yaml
      - name: Run apiSharing tests
        uses: mklos-kw/ocis-github-actions/ocis-test@v1
        with:
          suite: apiSharing

      - name: Run litmus
        uses: mklos-kw/ocis-github-actions/ocis-test@v1
        with:
          suite: litmus

      - name: Run cs3api validator
        uses: mklos-kw/ocis-github-actions/ocis-test@v1
        with:
          suite: cs3api
```

---

## Required files in the consuming repository

These files must exist in the consuming repository — they are instance-specific configuration referenced at runtime:

| File | Used by | Purpose |
|---|---|---|
| `tests/config/ci/ocis-config.json` | `ocis-setup` (`web-ui-config`) | Web UI configuration |
| `tests/config/ci/NotoSans.ttf` | `ocis-setup` | Thumbnail font (`THUMBNAILS_TXT_FONTMAP_FILE`) |
| `tests/config/translations/` | `ocis-setup` | Translation files (`OCIS_TRANSLATION_PATH`) |
| `tests/config/ci/ocis-ci-realm.dist.json` | `ocis-setup` (`keycloak: true`) | Keycloak realm template |
| `tests/config/ci/wopiserver.conf` | `ocis-setup` (`collaboration-apps: cs3-wopi`) | cs3org/wopiserver configuration |
| `tests/config/ci/fakeoffice-server.py` | `ocis-setup` (`collaboration-apps: *fakeoffice*,cs3-wopi`) | FakeOffice WOPI app |

---

## License

[Apache 2.0](LICENSE)
