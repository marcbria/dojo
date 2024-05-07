# Inventory of configurations

This is a list of actions to perform to setup different configurations.

## Single tenant, Journal in domain without url Slug

**Characteristics**
- RESTful urls
- Journal's url is the root of your domain or subdomain.
- No additional slugs with the journal context are added to the url.
- Admin pages are placed in "/index/admin".

**Downsides**
- Installation is not trivial

**Example:**
Journal's url: https://ada-revista04.precarietat.net
Admin's url:   https://ada-revista04.precarietat.net/index/admin

### Actions

1. **Create your dictionary**

Set your dictionary with the data of your journal.
Pay special attention to `domain` and `base_url*` variables.

```
dojo:
  id: journalname                       # This MUST be lowercase.
  tool: ojs
  version: "3_3_0-17"
  versionFamily: "3_3_0"
  domain: "journalname.foo.org"
  type: domain
  
proxy:
  domains: "`{{ dojo.domain }}`"

database:
  tool: mariadb
  version: "11.3"
  host: "db"              # Server DB host.
  user: "ojs"             # DB user.
  pass: "vaultPwd"        # REPLACED by real pwd set in ansible vault.
  name: "ojs"             # DB name.
  driver: "mysqli"

images:
  db:  "{{ database.tool }}:{{ database.version }}"
  app: "pkpofficial/{{ dojo.tool }}:{{ dojo.version }}"

pkp:
  admin:
    mail: "yourmail@example.org"
    pass: "vaultPwd"        # REPLACED by real pwd set in ansible vault.
  general:
    installed: "Off"
    base_url: "https://{{ dojo.domain }}"

    # Un comment for single-tenant journals "in domain as root"    
    base_url_index: "https://{{ dojo.domain }}/index"
    base_url_journal: "https://{{ dojo.domain }}"
    scheduled_tasks: "On"
    restful_urls: "On"
    enable_beacon: "Off"
  database:
    host:     "{{ database.host }}"
    driver:   "{{ database.driver }}"
    username: "{{ database.user }}"
    password: "{{ database.pass }}"
```

Save this as `journalname.yml` in your inventory/sites folder.

2. Create your site:
`$ just dojo-create journalname $SERVER;`

3. Raise and install your new journal:
`$ just dojo-manage journalname $SERVER up; just dojo-run install journalname $SERVER;`

4. Create your new journal with "journalname" as the url slug.

5. Uncomment your volumes/config/apache.conf and restart:
`$ just dojo-manage journalname $SERVER restart;`

6. Complete your journal's installation.