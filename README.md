# opn_api

A Ruby client library and CLI tool for the OPNsense REST API.

#### Table of Contents

1. [Overview](#overview)
1. [Supported resources](#supported-resources)
1. [Install](#install)
1. [Modes](#modes)
1. [CLI Usage](#cli-usage)
1. [Configuration](#configuration)
1. [Basics](#basics)
1. [Table output and field filtering](#table-output-and-field-filtering)
1. [Examples](#examples)
    - [ACME Client](#acme-client)
    - [Backup](#backup)
    - [Cron](#cron)
    - [DHC Relay](#dhc-relay)
    - [Firewall](#firewall)
    - [Gateways](#gateways)
    - [Groups](#groups)
    - [HA Sync](#ha-sync)
    - [HAProxy](#haproxy)
    - [IPsec](#ipsec)
    - [Kea DHCP](#kea-dhcp)
    - [Node Exporter](#node-exporter)
    - [OpenVPN](#openvpn)
    - [Plugins](#plugins)
    - [Routes](#routes)
    - [Service reconfigure](#service-reconfigure-1)
    - [Snapshots](#snapshots)
    - [Syslog](#syslog)
    - [Trust certificates](#trust-certificates)
    - [Tunables](#tunables)
    - [Users](#users)
    - [Zabbix](#zabbix)
    - [Error handling](#error-handling)
    - [Wrapper keys](#wrapper-keys)
    - [Raw API access](#raw-api-access)
    - [Ruby API](#ruby-api)
1. [Features](#features)
    - [Config loader](#config-loader)
    - [ID resolver](#id-resolver)
    - [Normalize](#normalize)
    - [Resource CRUD](#resource-crud)
    - [Resource registry](#resource-registry)
    - [Service reconfigure](#service-reconfigure)
1. [Development](#development)
    - [Contributing](#contributing)
1. [License](#license)

## Overview

opn_api is a standalone Ruby library and command-line tool for communicating with [OPNsense](https://opnsense.org/) firewalls via their REST API. It is meant as a replacement for [opn-cli](https://github.com/andreas-stuerz/opn-cli). It provides:

- An HTTP client with SSL, redirect handling, and API key authentication
- UUID/name resolution for ModelRelationField and CertificateField references
- Service reconfigure orchestration with configtest support
- OPNsense selection-hash normalization
- A CLI tool for interactive API access
- A resource registry that abstracts away inconsistent endpoint naming

## Supported resources

Backups and plugins are managed separately via dedicated commands (`backup`, `plugins`, `install`, `uninstall`).

| Resource | Manages |
|----------|---------|
| `acmeclient_account` | ACME Client accounts |
| `acmeclient_action` | ACME Client automation actions |
| `acmeclient_certificate` | ACME Client certificates |
| `acmeclient_settings` | ACME Client global settings (singleton) |
| `acmeclient_validation` | ACME Client validation methods |
| `cron` | Cron jobs |
| `dhcrelay` | DHCP Relay instances |
| `dhcrelay_destination` | DHCP Relay destinations |
| `firewall_alias` | Firewall aliases |
| `firewall_category` | Firewall categories |
| `firewall_group` | Firewall interface groups |
| `firewall_rule` | Firewall filter rules (new GUI) |
| `gateway` | Routing gateways |
| `group` | Local groups |
| `haproxy_acl` | HAProxy ACLs (conditions) |
| `haproxy_action` | HAProxy actions (rules) |
| `haproxy_backend` | HAProxy backend pools |
| `haproxy_cpu` | HAProxy CPU affinity / thread binding |
| `haproxy_errorfile` | HAProxy error files |
| `haproxy_fcgi` | HAProxy FastCGI applications |
| `haproxy_frontend` | HAProxy frontend listeners |
| `haproxy_group` | HAProxy user-list groups |
| `haproxy_healthcheck` | HAProxy health checks |
| `haproxy_lua` | HAProxy Lua scripts |
| `haproxy_mailer` | HAProxy mailers |
| `haproxy_mapfile` | HAProxy map files |
| `haproxy_resolver` | HAProxy DNS resolvers |
| `haproxy_server` | HAProxy backend servers |
| `haproxy_settings` | HAProxy global settings (singleton) |
| `haproxy_user` | HAProxy user-list users |
| `hasync` | HA sync / CARP settings (singleton) |
| `ipsec_child` | IPsec child SAs (Swanctl) |
| `ipsec_connection` | IPsec connections (Swanctl) |
| `ipsec_keypair` | IPsec key pairs (Swanctl) |
| `ipsec_local` | IPsec local authentication (Swanctl) |
| `ipsec_pool` | IPsec address pools (Swanctl) |
| `ipsec_presharedkey` | IPsec pre-shared keys (Swanctl) |
| `ipsec_remote` | IPsec remote authentication (Swanctl) |
| `ipsec_settings` | IPsec global settings (singleton) |
| `ipsec_vti` | IPsec VTI entries (Swanctl) |
| `kea_ctrl_agent` | KEA Control Agent settings (singleton) |
| `kea_dhcpv4` | KEA DHCPv4 global settings (singleton) |
| `kea_dhcpv4_peer` | KEA DHCPv4 HA peers |
| `kea_dhcpv4_reservation` | KEA DHCPv4 reservations |
| `kea_dhcpv4_subnet` | KEA DHCPv4 subnets |
| `kea_dhcpv6` | KEA DHCPv6 global settings (singleton) |
| `kea_dhcpv6_pd_pool` | KEA DHCPv6 prefix delegation pools |
| `kea_dhcpv6_peer` | KEA DHCPv6 HA peers |
| `kea_dhcpv6_reservation` | KEA DHCPv6 reservations |
| `kea_dhcpv6_subnet` | KEA DHCPv6 subnets |
| `node_exporter` | Prometheus Node Exporter settings (singleton) |
| `openvpn_cso` | OpenVPN client-specific overrides |
| `openvpn_instance` | OpenVPN instances |
| `openvpn_statickey` | OpenVPN static keys |
| `route` | Static routes |
| `snapshot` | ZFS snapshots |
| `syslog` | Syslog remote destinations |
| `trust_ca` | Trust Certificate Authorities |
| `trust_cert` | Trust certificates |
| `trust_crl` | Trust Certificate Revocation Lists |
| `tunable` | System tunables (sysctl) |
| `user` | Local users |
| `zabbix_agent` | Zabbix Agent settings (singleton) |
| `zabbix_agent_alias` | Zabbix Agent Alias entries |
| `zabbix_agent_userparameter` | Zabbix Agent UserParameter entries |
| `zabbix_proxy` | Zabbix Proxy settings (singleton) |

## Install

```
gem install opn_api
```

Or add to your Gemfile:

```ruby
gem 'opn_api'
```

## Modes

opn_api can be used in 2 modes: CLI mode and Ruby API mode.

CLI mode provides the `opn-api` command for interactive use and shell scripts. Ruby API mode allows direct integration into Ruby projects.

## CLI Usage

```
$ opn-api --help

Usage: opn-api [options] <command> [command-options] [args...]

A CLI tool for the OPNsense REST API.

Global options:
  -c, --config-dir PATH    Config directory for device files
  -d, --device NAME        Device name (default: "default")
  -f, --format FORMAT      Output format: table, json, yaml (default: table)
  -F, --fields FIELDS      Comma-separated field names for table output
  -A, --all-fields         Show all fields in table output (default: first 5)
  -E, --show-empty         Show empty fields in table output (default: hidden)
  -v, --verbose            Enable debug output (includes API error details)
  --version                Show version
  -h, --help               Show this help

Commands:
  backup       Download config backup
  create       Create resource
  delete       Delete resource
  devices      List configured devices
  get          GET request to API path
  groups       List reconfigure groups
  install      Install plugin
  plugins      List installed plugins
  post         POST request to API path
  reconfigure  Trigger service reconfigure
  resources    List known resource types
  search       Search resources
  show         Show single resource
  test         Test device connectivity
  uninstall    Uninstall plugin
  update       Update resource
```

Resource commands (`search`, `show`, `create`, `update`, `delete`) accept a resource name from the built-in registry. Run `opn-api resources` for a full list. Singleton resources (settings) are auto-detected and work without UUID for `show` and `update`.

## Configuration

Device credentials are stored in YAML files, one per OPNsense device. The config directory is searched in this order (highest priority last):

1. `/etc/opn-api/devices/` (system-wide)
2. `~/.config/opn-api/devices/` (per-user)
3. Explicit `config_dir` parameter or `-c` CLI flag
4. `OPN_API_CONFIG_DIR` environment variable (override)

### Device file format

Each device is a YAML file named `<device_name>.yaml`:

```yaml
# ~/.config/opn-api/devices/opnsense01.yaml
url: https://192.168.1.1/api
api_key: +OPNSENSE_API_KEY
api_secret: +OPNSENSE_API_SECRET
ssl_verify: false
timeout: 60
```

This format is compatible with [puppet-opn](https://github.com/markt-de/puppet-opn) device files, so existing Puppet configurations can be reused by pointing `config_dir` to the Puppet config directory.

## Basics

```
# List configured devices
$ opn-api devices

# Test connectivity
$ opn-api -d opnsense01 test

# List known resource types (shows name, wrapper key, type)
$ opn-api resources
```

## Table output and field filtering

By default, the table output shows only the first 5 fields to keep it readable. Use `-F` to select specific fields or `-A` to show all fields. Fields with empty values are hidden by default — use `-E` to show them. JSON and YAML output (`-f json`, `-f yaml`) always includes all data unmodified.

```
# Search resources (default: first 5 fields shown)
$ opn-api -d opnsense01 search firewall_alias

# Select specific fields
$ opn-api -d opnsense01 -F uuid,enabled,name,type search firewall_alias

# Show all fields
$ opn-api -d opnsense01 -A search firewall_alias

# Show empty fields (hidden by default)
$ opn-api -d opnsense01 -E show acmeclient_settings

# JSON output always includes all data (unaffected by -F/-A/-E)
$ opn-api -d opnsense01 -f json search haproxy_server
```

## Examples

### ACME Client

```
# List ACME accounts
$ opn-api -d opnsense01 search acmeclient_account

# List ACME certificates
$ opn-api -d opnsense01 search acmeclient_certificate

# List ACME validations
$ opn-api -d opnsense01 search acmeclient_validation

# List ACME actions
$ opn-api -d opnsense01 search acmeclient_action

# Show ACME settings (singleton)
$ opn-api -d opnsense01 show acmeclient_settings

# Update ACME settings (wrapper key: "acmeclient")
$ opn-api -d opnsense01 update acmeclient_settings \
    -j '{"acmeclient":{"settings":{"environment":"production"}}}'
```

### Backup

Download the OPNsense configuration backup (XML). The backup endpoint returns XML instead of JSON, so this command uses a raw (non-JSON) mode internally.

```
# Download backup to file
$ opn-api -d opnsense01 backup /tmp/opnsense01-backup.xml

# Print backup XML to stdout (e.g. for piping)
$ opn-api -d opnsense01 backup > /tmp/opnsense01-backup.xml
```

Ruby API:

```ruby
# Download backup as raw XML string
config = OpnApi::Config.new
client = config.client_for('opnsense01')
xml = client.get('core/backup/download/this', raw: true)
File.write('/tmp/backup.xml', xml)
```

### Cron

```
# List cron jobs
$ opn-api -d opnsense01 search cron

# Show cron job details
$ opn-api -d opnsense01 show cron a1b2c3d4-...

# Create cron job (wrapper key: "job")
$ opn-api -d opnsense01 create cron \
    -j '{"job":{"enabled":"1","minutes":"0","hours":"3","description":"nightly backup"}}'

# Delete cron job
$ opn-api -d opnsense01 delete cron a1b2c3d4-...
```

### DHC Relay

```
# List DHC relays
$ opn-api -d opnsense01 search dhcrelay

# List DHC relay destinations
$ opn-api -d opnsense01 search dhcrelay_destination

# Create relay destination (wrapper key: "destination")
$ opn-api -d opnsense01 create dhcrelay_destination \
    -j '{"destination":{"server":"10.0.0.5"}}'
```

### Firewall

```
# List all aliases
$ opn-api -d opnsense01 search firewall_alias

# Show single alias by UUID
$ opn-api -d opnsense01 show firewall_alias 8a2f3b4c-...

# Create alias (wrapper key: "alias")
$ opn-api -d opnsense01 create firewall_alias \
    -j '{"alias":{"name":"test","type":"host","content":"10.0.0.1","enabled":"1"}}'

# Create via stdin
$ echo '{"alias":{"name":"test","type":"host","content":"10.0.0.1","enabled":"1"}}' \
    | opn-api -d opnsense01 create firewall_alias

# Update alias
$ opn-api -d opnsense01 update firewall_alias 8a2f3b4c-... \
    -j '{"alias":{"content":"10.0.0.2"}}'

# Delete alias
$ opn-api -d opnsense01 delete firewall_alias 8a2f3b4c-...

# List firewall rules
$ opn-api -d opnsense01 search firewall_rule

# List firewall categories
$ opn-api -d opnsense01 search firewall_category

# List firewall groups
$ opn-api -d opnsense01 search firewall_group
```

### Gateways

```
# List all gateways
$ opn-api -d opnsense01 search gateway

# Show gateway details
$ opn-api -d opnsense01 show gateway a1b2c3d4-...

# Create gateway (wrapper key: "gateway_item")
$ opn-api -d opnsense01 create gateway \
    -j '{"gateway_item":{"name":"WAN_GW","interface":"wan","gateway":"192.168.1.1"}}'
```

### Groups

```
# List all groups
$ opn-api -d opnsense01 search group

# Show group details
$ opn-api -d opnsense01 show group a1b2c3d4-...

# Create group (wrapper key: "group")
$ opn-api -d opnsense01 create group \
    -j '{"group":{"name":"admins","description":"Admin group"}}'
```

### HA Sync

HA Sync is a singleton resource (one per device).

```
# Show HA Sync settings (singleton)
$ opn-api -d opnsense01 show hasync

# Update HA Sync settings (wrapper key: "hasync")
$ opn-api -d opnsense01 update hasync \
    -j '{"hasync":{"pfsyncenabled":"1","synchronizeinterface":"lan"}}'
```

### HAProxy

#### Servers

```
# List all servers
$ opn-api -d opnsense01 search haproxy_server

# Show server details
$ opn-api -d opnsense01 show haproxy_server 1a2b3c4d-...

# Create server (wrapper key: "server")
$ opn-api -d opnsense01 create haproxy_server \
    -j '{"server":{"name":"web01","address":"10.0.0.10","port":"8080"}}'

# Update server
$ opn-api -d opnsense01 update haproxy_server 1a2b3c4d-... \
    -j '{"server":{"port":"8443"}}'

# Delete server
$ opn-api -d opnsense01 delete haproxy_server 1a2b3c4d-...
```

#### Backends

```
# List all backends
$ opn-api -d opnsense01 search haproxy_backend

# Show backend details
$ opn-api -d opnsense01 show haproxy_backend 2b3c4d5e-...

# Create backend (wrapper key: "backend")
$ opn-api -d opnsense01 create haproxy_backend \
    -j '{"backend":{"name":"web_pool","mode":"http","linkedServers":"1a2b3c4d-..."}}'

# Update backend
$ opn-api -d opnsense01 update haproxy_backend 2b3c4d5e-... \
    -j '{"backend":{"mode":"tcp"}}'

# Delete backend
$ opn-api -d opnsense01 delete haproxy_backend 2b3c4d5e-...
```

#### Frontends

```
# List all frontends
$ opn-api -d opnsense01 search haproxy_frontend

# Show frontend details
$ opn-api -d opnsense01 show haproxy_frontend 3c4d5e6f-...

# Create frontend (wrapper key: "frontend")
$ opn-api -d opnsense01 create haproxy_frontend \
    -j '{"frontend":{"name":"https_in","bind":"0.0.0.0:443","mode":"http","defaultBackend":"2b3c4d5e-..."}}'

# Update frontend
$ opn-api -d opnsense01 update haproxy_frontend 3c4d5e6f-... \
    -j '{"frontend":{"bind":"0.0.0.0:8443"}}'

# Delete frontend
$ opn-api -d opnsense01 delete haproxy_frontend 3c4d5e6f-...
```

#### Settings and other sub-resources

```
# Show HAProxy settings (singleton)
$ opn-api -d opnsense01 show haproxy_settings

# Update HAProxy settings (wrapper key: "haproxy")
$ opn-api -d opnsense01 update haproxy_settings \
    -j '{"haproxy":{"general":{"tuning":{"maxconn":"2000"}}}}'

# List other HAProxy sub-resources
$ opn-api -d opnsense01 search haproxy_acl
$ opn-api -d opnsense01 search haproxy_action
$ opn-api -d opnsense01 search haproxy_cpu
$ opn-api -d opnsense01 search haproxy_errorfile
$ opn-api -d opnsense01 search haproxy_fcgi
$ opn-api -d opnsense01 search haproxy_group
$ opn-api -d opnsense01 search haproxy_healthcheck
$ opn-api -d opnsense01 search haproxy_lua
$ opn-api -d opnsense01 search haproxy_mailer
$ opn-api -d opnsense01 search haproxy_mapfile
$ opn-api -d opnsense01 search haproxy_resolver
$ opn-api -d opnsense01 search haproxy_user

# Apply changes (includes configtest)
$ opn-api -d opnsense01 reconfigure haproxy
```

### IPsec

```
# List all IPsec connections
$ opn-api -d opnsense01 search ipsec_connection

# Show connection details
$ opn-api -d opnsense01 show ipsec_connection 4d5e6f7a-...

# Full JSON output
$ opn-api -d opnsense01 -f json show ipsec_connection 4d5e6f7a-...

# List other IPsec sub-resources
$ opn-api -d opnsense01 search ipsec_child
$ opn-api -d opnsense01 search ipsec_keypair
$ opn-api -d opnsense01 search ipsec_local
$ opn-api -d opnsense01 search ipsec_pool
$ opn-api -d opnsense01 search ipsec_presharedkey
$ opn-api -d opnsense01 search ipsec_remote
$ opn-api -d opnsense01 search ipsec_vti

# Show IPsec settings (singleton)
$ opn-api -d opnsense01 show ipsec_settings

# Apply changes
$ opn-api -d opnsense01 reconfigure ipsec
```

### Kea DHCP

```
# Show Kea DHCPv4 settings (singleton)
$ opn-api -d opnsense01 show kea_dhcpv4

# List DHCPv4 subnets
$ opn-api -d opnsense01 search kea_dhcpv4_subnet

# Create DHCPv4 subnet (wrapper key: "subnet4")
$ opn-api -d opnsense01 create kea_dhcpv4_subnet \
    -j '{"subnet4":{"subnet":"10.0.1.0/24"}}'

# List DHCPv4 reservations
$ opn-api -d opnsense01 search kea_dhcpv4_reservation

# List DHCPv4 HA peers
$ opn-api -d opnsense01 search kea_dhcpv4_peer

# Show Kea DHCPv6 settings (singleton)
$ opn-api -d opnsense01 show kea_dhcpv6

# List DHCPv6 subnets, reservations, PD pools, peers
$ opn-api -d opnsense01 search kea_dhcpv6_subnet
$ opn-api -d opnsense01 search kea_dhcpv6_reservation
$ opn-api -d opnsense01 search kea_dhcpv6_pd_pool
$ opn-api -d opnsense01 search kea_dhcpv6_peer

# Show Kea control agent settings (singleton)
$ opn-api -d opnsense01 show kea_ctrl_agent
```

### Node Exporter

Node Exporter is a singleton resource.

```
# Show Node Exporter settings (singleton)
$ opn-api -d opnsense01 show node_exporter

# Update Node Exporter settings (wrapper key: "general")
$ opn-api -d opnsense01 update node_exporter \
    -j '{"general":{"listen_address":"0.0.0.0","listen_port":"9100"}}'
```

### OpenVPN

```
# List all OpenVPN instances
$ opn-api -d opnsense01 search openvpn_instance

# Show instance details
$ opn-api -d opnsense01 show openvpn_instance 5e6f7a8b-...

# Full JSON output
$ opn-api -d opnsense01 -f json show openvpn_instance 5e6f7a8b-...

# List client-specific overrides
$ opn-api -d opnsense01 search openvpn_cso

# List static keys
$ opn-api -d opnsense01 search openvpn_statickey

# Apply changes
$ opn-api -d opnsense01 reconfigure openvpn
```

### Plugins

```
# List installed plugins
$ opn-api -d opnsense01 plugins

# Install a plugin
$ opn-api -d opnsense01 install os-haproxy

# Uninstall a plugin
$ opn-api -d opnsense01 uninstall os-haproxy
```

Note: Install/uninstall are asynchronous — the API returns immediately while the operation continues in the background.

### Routes

```
# List all routes
$ opn-api -d opnsense01 search route

# Show route details
$ opn-api -d opnsense01 show route a1b2c3d4-...

# Create route (wrapper key: "route")
$ opn-api -d opnsense01 create route \
    -j '{"route":{"network":"10.0.2.0/24","gateway":"WAN_GW","descr":"office network"}}'

# Apply changes
$ opn-api -d opnsense01 reconfigure route
```

### Service reconfigure

After creating, updating, or deleting resources, trigger a service reconfigure to apply the changes.

```
# Trigger HAProxy reconfigure (includes configtest)
$ opn-api -d opnsense01 reconfigure haproxy

# Trigger IPsec reconfigure
$ opn-api -d opnsense01 reconfigure ipsec

# Trigger OpenVPN reconfigure
$ opn-api -d opnsense01 reconfigure openvpn

# Trigger tunable reconfigure
$ opn-api -d opnsense01 reconfigure tunable

# Trigger Zabbix agent reconfigure
$ opn-api -d opnsense01 reconfigure zabbix_agent

# List all available reconfigure groups
$ opn-api groups
```

### Snapshots

```
# List all snapshots (uses GET-based search)
$ opn-api -d opnsense01 search snapshot
```

### Syslog

```
# List syslog destinations
$ opn-api -d opnsense01 search syslog

# Show syslog destination details
$ opn-api -d opnsense01 show syslog a1b2c3d4-...

# Create syslog destination (wrapper key: "destination")
$ opn-api -d opnsense01 create syslog \
    -j '{"destination":{"enabled":"1","transport":"udp4","hostname":"10.0.0.100","port":"514"}}'

# Apply changes
$ opn-api -d opnsense01 reconfigure syslog
```

### Trust certificates

```
# List all certificates
$ opn-api -d opnsense01 search trust_cert

# Show certificate details
$ opn-api -d opnsense01 show trust_cert 6f7a8b9c-...

# List all CAs
$ opn-api -d opnsense01 search trust_ca

# Show CA details
$ opn-api -d opnsense01 show trust_ca 7a8b9c0d-...

# List CRLs (uses GET-based search)
$ opn-api -d opnsense01 search trust_crl
```

### Tunables

The wrapper key for tunables is `sysctl` (not `tunable` or `item`).

```
# List all tunables
$ opn-api -d opnsense01 search tunable

# Show tunable details
$ opn-api -d opnsense01 show tunable a1b2c3d4-...

# Create tunable (wrapper key: "sysctl")
$ opn-api -d opnsense01 create tunable \
    -j '{"sysctl":{"tunable":"net.inet.ip.forwarding","value":"1"}}'

# Update tunable
$ opn-api -d opnsense01 update tunable a1b2c3d4-... \
    -j '{"sysctl":{"value":"0"}}'

# Delete tunable
$ opn-api -d opnsense01 delete tunable a1b2c3d4-...

# Apply changes
$ opn-api -d opnsense01 reconfigure tunable
```

### Users

```
# List all users
$ opn-api -d opnsense01 search user

# Show user details
$ opn-api -d opnsense01 show user a1b2c3d4-...

# Create user (wrapper key: "user")
$ opn-api -d opnsense01 create user \
    -j '{"user":{"name":"testuser","email":"test@example.com"}}'
```

### Zabbix

#### Zabbix agent

Zabbix agent is a singleton resource (one per device).

```
# Show Zabbix agent settings (singleton)
$ opn-api -d opnsense01 show zabbix_agent

# Show as JSON
$ opn-api -d opnsense01 -f json show zabbix_agent

# Update Zabbix agent settings (wrapper key: "zabbixagent")
$ opn-api -d opnsense01 update zabbix_agent \
    -j '{"zabbixagent":{"settings":{"main":{"enabled":"1","hostname":"opnsense01","serverList":"10.0.0.5"}}}}'

# Apply changes
$ opn-api -d opnsense01 reconfigure zabbix_agent
```

#### Zabbix agent sub-resources

Zabbix agent aliases and user parameters are CRUD resources within the Zabbix agent settings.

```
# List Zabbix agent aliases (uses GET-based search)
$ opn-api -d opnsense01 search zabbix_agent_alias

# Create alias (wrapper key: "alias")
$ opn-api -d opnsense01 create zabbix_agent_alias \
    -j '{"alias":{"key":"system.uptime","item":"system.uptime"}}'

# List Zabbix agent user parameters
$ opn-api -d opnsense01 search zabbix_agent_userparameter
```

#### Zabbix proxy

Zabbix proxy is a singleton resource.

```
# Show Zabbix proxy settings (singleton)
$ opn-api -d opnsense01 show zabbix_proxy

# Update Zabbix proxy settings (wrapper key: "general")
$ opn-api -d opnsense01 update zabbix_proxy \
    -j '{"general":{"enabled":"1","hostname":"zbxproxy01"}}'
```

### Error handling

On failure, the full API response is shown as JSON for debugging:

```
$ opn-api -d opnsense01 create firewall_alias -j '{"alias":{"name":"test"}}'
Error: create failed: {"result":"failed","validations":{"alias.type":"This field is required."}}
```

When OPNsense returns only `{"result":"failed"}` without validation details, the most common cause is a wrong wrapper key. The error message includes the expected wrapper key from the registry:

```
# Wrong wrapper key — error shows expected key
$ opn-api -d opnsense01 create firewall_alias -j '{"item":{"name":"test"}}'
Error: create failed: {"result":"failed"}
Hint: The JSON wrapper key is likely wrong. Expected wrapper key: 'alias'.

# Use -v to see full request/response details for debugging
$ opn-api -v -d opnsense01 create firewall_alias -j '{"alias":{"name":"test"}}'
```

### Wrapper keys

The OPNsense API uses different keys for endpoints and POST body wrappers. The wrapper key wraps the config in the JSON body. When using registry resource names, `opn-api resources` shows the correct wrapper key for each type.

Common examples:

| Resource name | Wrapper key |
|---|---|
| `cron` | `job` |
| `dhcrelay` | `relay` |
| `firewall_alias` | `alias` |
| `firewall_rule` | `rule` |
| `gateway` | `gateway_item` |
| `haproxy_backend` | `backend` |
| `haproxy_frontend` | `frontend` |
| `haproxy_server` | `server` |
| `ipsec_connection` | `connection` |
| `ipsec_keypair` | `keyPair` |
| `kea_dhcpv4_subnet` | `subnet4` |
| `openvpn_instance` | `instance` |
| `route` | `route` |
| `syslog` | `destination` |
| `trust_ca` | `ca` |
| `trust_cert` | `cert` |
| `tunable` | `sysctl` |
| `user` | `user` |

To find the correct wrapper key for any resource, use `show` to inspect an existing item — the top-level key in the raw JSON response (`-f json`) is the wrapper key.

### Raw API access

For endpoints not covered by the resource registry, use the `get` and `post` commands for direct API access.

```
# GET request to any API path
$ opn-api -d opnsense01 get core/firmware/info

# POST request with JSON body
$ opn-api -d opnsense01 post firewall/alias/search_item '{}'
```

### Ruby API

```ruby
#!/usr/bin/env ruby

require 'opn_api'

# Create client from config file
config = OpnApi::Config.new
client = config.client_for('opnsense01')

# Or create client directly
client = OpnApi::Client.new(
  url: 'https://fw.example.com/api',
  api_key: '+ABC...',
  api_secret: '+XYZ...',
  ssl_verify: false,
)

# Simple API calls
info = client.get('core/firmware/info')
puts "OPNsense version: #{info['product_version']}"

aliases = client.post('firewall/alias/search_item', {})
aliases['rows'].each { |a| puts a['name'] }

# CRUD via resource registry (preferred — handles endpoint quirks)
res = OpnApi::ResourceRegistry.build(client, 'haproxy_server')
servers = res.search
new_server = res.add('server' => { 'name' => 'web01', 'address' => '10.0.0.10', 'port' => '8080' })
res.set(new_server['uuid'], 'server' => { 'port' => '8443' })
res.del(new_server['uuid'])

# Singleton resources (settings)
settings = OpnApi::ResourceRegistry.build(client, 'haproxy_settings')
current = settings.show_settings
settings.update_settings('haproxy' => { 'general' => { 'tuning' => { 'maxconn' => '2000' } } })

# CRUD via explicit paths (for resources not in registry)
res = OpnApi::Resource.new(
  client: client,
  base_path: 'firewall/alias',
  search_action: 'search_item',
  crud_action: '%{action}_item',
)
all_aliases = res.search

# Legacy mode (module/controller/type) is also supported
res = OpnApi::Resource.new(
  client: client,
  module_name: 'firewall',
  controller: 'alias',
  resource_type: 'item',
)

# UUID resolution for ModelRelationField references
relation_fields = {
  'linkedServers' => {
    endpoint: 'haproxy/settings/search_servers',
    multiple: true,
  },
  'sslCA' => {
    endpoint: 'trust/ca/search',
    id_field: 'refid',
    name_field: 'descr',
  },
}
config_with_names = OpnApi::IdResolver.translate_to_names(
  client, 'opnsense01', relation_fields, config_hash,
)
config_with_uuids = OpnApi::IdResolver.translate_to_uuids(
  client, 'opnsense01', relation_fields, config_hash,
)

# Service reconfigure orchestration
OpnApi::ServiceReconfigure.load_defaults!
OpnApi::ServiceReconfigure[:haproxy].mark('opnsense01', client)
results = OpnApi::ServiceReconfigure[:haproxy].run
# => { 'opnsense01' => :ok }
```

## Features

### Config loader

`OpnApi::Config` loads device credentials from YAML files with a hierarchical search path. Supports multiple devices and is compatible with puppet-opn's device file format.

### ID resolver

`OpnApi::IdResolver` translates between UUIDs/IDs and human-readable names for OPNsense ModelRelationField and CertificateField references. Features include:

- Per-run caching to minimize API calls
- Automatic cache refresh on miss (retry once)
- Support for dot-path field names (e.g. `general.stats.allowedUsers`)
- Custom `id_field` and `name_field` per relation (e.g. `refid`/`descr` for certificates)
- Multiple values (comma-separated) and single-value fields

### Normalize

`OpnApi::Normalize` handles OPNsense selection-hash normalization. OPNsense returns multi-select fields as hashes with `value`/`selected` keys. This module collapses them to comma-separated strings of selected keys, recursing into nested structures.

### Resource CRUD

`OpnApi::Resource` provides a generic CRUD wrapper for OPNsense API endpoints. It supports three resource patterns:

- **Standard CRUD**: search/get/add/set/del with UUID
- **Singleton settings**: GET get / POST set, no UUID, no search/add/del
- **GET-based search**: Resources using GET instead of POST for search (e.g. snapshots, trust_crl)

### Resource registry

`OpnApi::ResourceRegistry` maps user-friendly resource names to exact API endpoint paths. OPNsense has no consistent endpoint naming — some use snake_case with plural search (`search_servers`/`add_server`), others use camelCase (`searchConnection`/`addConnection`), bare names (`search`/`add`), or no separator (`searchroute`/`addroute`). The registry abstracts these differences so users and code don't need to know the implementation details.

Resource names follow the [puppet-opn](https://github.com/markt-de/puppet-opn) naming convention (`opn_` prefix stripped).

### Service reconfigure

`OpnApi::ServiceReconfigure` orchestrates service reloads after configuration changes. Features include:

- Registry pattern with 18 pre-registered OPNsense service groups
- Mark/run pattern: track devices with changes, then batch-reconfigure
- Configtest support (e.g. HAProxy validates config before reconfigure)
- Error tracking: skip reconfigure for devices with failed resource changes
- Custom group registration for plugins or custom services

## Development

### Contributing

Please use the GitHub issues functionality to report any bugs or requests for new features. Feel free to fork and submit pull requests for potential contributions.

## License

BSD-2-Clause
