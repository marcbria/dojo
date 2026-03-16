# URL configuration types

This document describes the supported URL layouts for OJS/OMP journals and
the specific steps required to set up each one.

## Types overview

| Type | Example URL | Notes |
|:---|:---|:---|
| `domain` | `https://journal.example.org/journalname` | Default. Journal slug in path. |
| `domain-noslug` | `https://journal.example.org` | Journal at domain root. Extra steps required. |
| `folder` | `https://example.org/journalname` | Multiple journals under one domain. |
| `folder-noslug` | `https://example.org/journalname` | Folder-based, no OJS slug in URL. |

---

## domain-noslug

Journal lives at the root of its domain — no OJS context slug in the URL.

**Characteristics:**
- RESTful URLs enabled.
- Journal URL is the root of the domain or subdomain.
- Admin pages are at `/index/admin`.

**Downsides:**
- Setup requires an extra manual step after the initial install.

**Example:**
```
Journal: https://myjournal.example.org
Admin:   https://myjournal.example.org/index/admin
```

### Steps

0. Set environment variables:
```bash
SERVER=myserver
JOURNAL=myjournal
```

1. Create the inventory dictionary at `inventory/sites/<hostName>/$JOURNAL.yml`:
```yaml
dojo:
  id: myjournal                         # Must be lowercase.
  tool: ojs
  version: "3_3_0-22"
  versionFamily: "3_3_0"
  domain: "myjournal.example.org"
  type: domain-noslug

proxy:
  domains: "`myjournal.example.org`"

database:
  tool: mariadb
  version: "11.3"
  host: "db"
  user: "ojs"
  pass: "vaultPwd"                      # Replaced by vault at runtime.
  name: "ojs"
  driver: "mysqli"

images:
  db:  "mariadb:11.3"
  app: "pkpofficial/ojs:3_3_0-22"

pkp:
  admin:
    mail: "admin@example.org"
    pass: "vaultPwd"                    # Replaced by vault at runtime.
  general:
    installed: "Off"
    base_url: "https://myjournal.example.org"
    base_url_index: "https://myjournal.example.org/index"
    base_url_journal: "https://myjournal.example.org"
    scheduled_tasks: "On"
    restful_urls: "On"
    enable_beacon: "Off"
  database:
    host:     "db"
    driver:   "mysqli"
    username: "ojs"
    password: "vaultPwd"                # Replaced by vault at runtime.
```

2. Create the site:
```bash
just dojo-create $JOURNAL $SERVER
```

3. Start the containers and run the OJS installer:
```bash
just dojo-manage $JOURNAL $SERVER up
just dojo-run install $JOURNAL $SERVER
```

4. In the OJS web installer, create a journal using `myjournal` as the URL path slug.

5. Once installation is complete, uncomment the rewrite rules in
   `volumes/config/apache.conf` and restart:
```bash
just dojo-manage $JOURNAL $SERVER restart
```

6. Complete the journal configuration in the OJS admin panel.

---

## domain

Journal is accessible at `domain/journalname`. This is the default OJS layout
and requires no special Apache configuration.

**Example:**
```
Journal: https://journals.example.org/myjournal
Admin:   https://journals.example.org/myjournal/index/admin
```

Steps 0–3 are identical to `domain-noslug`. Set `type: domain` in the dictionary
and skip steps 4–5.

---

## folder-noslug

Multiple journals hosted under a shared domain, each at its own path prefix,
without the OJS context slug in the URL.

**Example:**
```
Journal: https://journals.example.org/myjournal
Admin:   https://journals.example.org/myjournal/index/admin
```

Add `proxy.pathprefix` to the dictionary:
```yaml
dojo:
  type: folder-noslug

proxy:
  domains: "`journals.example.org`"
  pathprefix: "myjournal"

pkp:
  general:
    base_url: "https://journals.example.org/myjournal"
    base_url_index: "https://journals.example.org/myjournal/index"
    base_url_journal: "https://journals.example.org/myjournal"
```

Then follow the same steps as `domain-noslug`.
