# AGENTS.md

This file provides guidance to AI agents when working with code in this repository.

## What this module does

`simp-simp_nfs` is a SIMP Puppet **profile** that provides SIMP-integrated NFS
home-directory export and mount on top of the `simp/nfs` module. It wires
`simp/nfs` into the wider SIMP stack: automounted (`autofs`) home directories,
LDAP-driven on-demand home-directory creation, and PKI-secured NFS transport —
all fed by the `simp_options::*` Hiera seam so a site configures NFS home dirs
the same way it configures every other SIMP feature.

The module does **not** reimplement NFS. Every actual NFS resource
(`nfs::server::export`, `nfs::client::mount`, the `nfs-server.service`,
`stunnel` wrapping) comes from `simp/nfs`; `simp_nfs` only decides *whether this
node is a server or a client*, lays out the export directory tree, and layers
LDAP home-dir creation and PKI on top.

The main entry class picks one of two roles per node from a single boolean:
`simp_nfs::export_home_dirs` (`manifests/init.pp:31-61`). When `true` the node
becomes an NFS **server** (`class { 'nfs': is_server => true }`); when `false`
it becomes an NFS **client** (`class { 'nfs': is_client => true }`).

### Business logic

Four manifests: the `simp_nfs` entry class plus three role/feature classes.

- **`simp_nfs` (`manifests/init.pp:31-61`)** — Public entry class (not
  `assert_private()`'d; consumers `include simp_nfs`). Parameters
  (`init.pp:31-36`):
  - `$export_home_dirs` (`Boolean`, default `false`) — the role switch. `false`
    → NFS client; `true` → NFS server (`init.pp:37-38,50-51`).
  - `$home_dir_server` (`Optional[Simplib::Ip]`, default `undef`) — the server
    to mount home dirs from.
  - `$autodetect_remote` (`Boolean`, default `true`) — passed through to the
    mount class; set `false` if the node wrongly mounts `127.0.0.1`.
  - `$use_autofs` (`Boolean`, default `true`) — use `autofs` for the mounts.

  Control flow (`init.pp:37-60`):
  - **Server branch** (`$export_home_dirs` true): `include
    simp_nfs::export::home`, and *if* `$home_dir_server` is also set, mount from
    **`127.0.0.1`** — the code assumes a server that also sets
    `$home_dir_server` wants to mount its own export locally
    (`init.pp:42-48`; see the docstring at `init.pp:15-16`).
  - **Client branch** (`$export_home_dirs` false): if `$home_dir_server` is set,
    `class { 'simp_nfs::mount::home': nfs_server => $home_dir_server, ... }`
    (`init.pp:53-58`). With no `$home_dir_server` the node is just an NFS client
    with nothing mounted by this profile.

- **`simp_nfs::export::home` (`manifests/export/home.pp:37-118`)** — the NFS
  **server** side; `inherits simp_nfs` (`export/home.pp:42`). Builds the NFSv4
  pseudo-filesystem export tree under `${data_dir}/nfs` (default `$data_dir` is
  `/var`): creates `nfs`, `nfs/exports`, `nfs/exports/home`, and `nfs/home`
  (`export/home.pp:46-56`), then **bind-mounts** `nfs/home` under
  `nfs/exports/home` via a `mount` resource (`options => 'rw,bind'`,
  `export/home.pp:107-117`). It orders itself before the NFS service:
  `Class['simp_nfs::export::home'] -> Service['nfs-server.service']`
  (`export/home.pp:44`).
  - **stunnel fork** (`export/home.pp:67-104`): if `!$::nfs::stunnel`, exports
    are opened to `simplib::nets2cidr($trusted_nets)`; **if `$::nfs::stunnel` is
    set, both exports are locked to `['127.0.0.1']` with `insecure => true`** —
    because with stunnel the real clients terminate at the local stunnel, not on
    the wire.
  - **LDAP home-dir creation** (`export/home.pp:61-65`): if `$create_home_dirs`
    (defaults to `simplib::lookup('simp_options::ldap', ...)`), it declares
    `simp_nfs::create_home_dirs` and threads `export_dir => ${data_dir}/nfs/home`
    into it, ordered after the export dirs exist.

- **`simp_nfs::create_home_dirs` (`manifests/create_home_dirs.pp:115-192`)** —
  installs `rubygem-net-ldap` (`create_home_dirs.pp:144-146`), renders the
  `create_home_directories.rb` script from
  `templates/create_home_directories.rb.erb`
  (`create_home_dirs.pp:153-160`), and drives it on a **systemd timer**
  (`nfs_create_home_dirs.timer`, default schedule `*-*-* *:30:00`,
  `create_home_dirs.pp:174-180`). The script binds to LDAP and creates missing
  home directories for users under `$export_dir` (default `/var/nfs/home`) from
  `$skel_dir`. It also removes the legacy cron drop-in
  `/etc/cron.hourly/create_home_directories.rb` (`create_home_dirs.pp:149-151`).
  - **PKI branch** (`create_home_dirs.pp:182-189`): only if `$pki` is truthy, it
    calls **`simplib::assert_optional_dependency($module_name, 'simp/pki')`**
    (`create_home_dirs.pp:183`) and then `pki::copy { 'nfs_home_server': }` to
    stage app certs under `/etc/pki/simp_apps/nfs_home_server/x509`. This is the
    module's only optional dependency and the only place it is enforced.

- **`simp_nfs::mount::home` (`manifests/mount/home.pp:55-93`)** — the NFS
  **client** side. Required parameter `$nfs_server` (`Simplib::IP`); mounts
  `$remote_path` (default `/home`) at `$local_home` (default `/home`) via
  `nfs::client::mount` with `nfs_version => 4` and autofs indirect mapping
  (`autofs_indirect_map_key => '*'`, `autofs_add_key_subst => true`,
  `mount/home.pp:80-92`).
  - If `getvar('::nfs::client::is_server')` is true, `$_target` is forced to
    `127.0.0.1` (`mount/home.pp:66-71`).
  - **SELinux boolean** (`mount/home.pp:73-78`): when SELinux is in a non-`disabled`
    mode, sets `selboolean { 'use_nfs_home_dirs': value => 'on' }` persistently.

### Gotchas / non-obvious details

- **This is a thin profile over `simp/nfs`.** All real NFS resources come from
  `simp/nfs`; do not add raw NFS resources here — configure through the
  `nfs`/`simp_nfs` parameters instead. `simp_nfs` only chooses server-vs-client
  and layers LDAP + PKI on top.
- **A server that also sets `$home_dir_server` mounts itself over `127.0.0.1`,
  not over the given IP** (`init.pp:42-48`). The `$home_dir_server` value in the
  server branch is only used as a "yes, also mount" flag; the actual target is
  hard-coded to loopback.
- **Four LDAP lookups have NO `default_value` and will hard-fail compilation if
  unset.** `simp_options::ldap::uri` / `::base_dn` / `::bind_dn` / `::bind_pw`
  (`create_home_dirs.pp:117-120`) are looked up with a bare
  `simplib::lookup(...)`. They only matter when LDAP home-dir creation is
  enabled (`export/home.pp:41` / `create_home_dirs.pp`), but if that path runs
  without LDAP hieradata, the catalog fails to compile. By contrast the `pki`,
  `pki::source`, `openssl::cipher_suite`, and `package_ensure` lookups **do**
  carry defaults.
- **PKI is optional and only asserted when enabled.** `simp/pki` is *not* a hard
  dependency; `simplib::assert_optional_dependency` runs only inside `if $pki`
  (`create_home_dirs.pp:182-183`). Don't hard-`include` `pki`.
- **stunnel flips the export ACLs to loopback-only.** When `$::nfs::stunnel` is
  set the exports are restricted to `127.0.0.1` with `insecure => true`
  (`export/home.pp:85-104`); `$trusted_nets` is ignored in that mode. This is
  intentional, not a bug.
- **`simp/simp_options` is NOT a declared dependency** in `metadata.json`, yet
  every manifest consumes the `simp_options::*` seam via `simplib::lookup`
  (provided by `simp/simplib`). `simp_options` appears only as a fixture
  (`.fixtures.yml`).
- **No `assert_private()` calls anywhere.** `export::home`, `mount::home`, and
  `create_home_dirs` are all technically includable directly, but the intended
  entry point is the `simp_nfs` class driving them via its parameters.
- **`$strip_128_bit_ciphers` is deprecated** and affects no supported OS
  (`create_home_dirs.pp:69-70,137`); leave it alone.

## The `simp_options` / `simplib::lookup` seam

This is the module's real business-logic seam (the natural target for a
lookup-path unit test). The four LDAP-credential keys have **no default** and
hard-fail if unset; the rest carry explicit defaults:

| Line | Key | `default_value` |
|------|-----|-----------------|
| `create_home_dirs.pp:117` | `simp_options::ldap::uri` | *(none — hard-fail)* |
| `create_home_dirs.pp:118` | `simp_options::ldap::base_dn` | *(none — hard-fail)* |
| `create_home_dirs.pp:119` | `simp_options::ldap::bind_dn` | *(none — hard-fail)* |
| `create_home_dirs.pp:120` | `simp_options::ldap::bind_pw` | *(none — hard-fail)* |
| `create_home_dirs.pp:121` | `simp_options::pki` | `false` |
| `create_home_dirs.pp:122` | `simp_options::pki::source` | `'/etc/pki/simp/x509'` |
| `create_home_dirs.pp:138` | `simp_options::openssl::cipher_suite` | `['DEFAULT','!MEDIUM']` |
| `create_home_dirs.pp:139` | `simp_options::package_ensure` | `'installed'` |
| `export/home.pp:39` | `simp_options::trusted_nets` | `['127.0.0.1']` |
| `export/home.pp:41` | `simp_options::ldap` | `false` |

Keep routing SIMP feature toggles through `simplib::lookup('simp_options::*', {
'default_value' => ... })` with an explicit default rather than assuming
`simp_options` is included — except where an unset value should intentionally
fail the catalog (the LDAP credentials above).

## Dependencies

Module dependencies (from `metadata.json`):

- `simp/nfs` `>= 7.0.0 < 8.0.0` — provides all real NFS resources
  (`nfs::server::export`, `nfs::client::mount`, `nfs-server.service`, the
  `nfs::stunnel` toggle). This module is a profile on top of it.
- `simp/simplib` `>= 4.9.0 < 5.0.0` — provides `simplib::lookup`,
  `simplib::assert_optional_dependency`, `simplib::nets2cidr`, and the
  `Simplib::*` data types (`Simplib::Ip`, `Simplib::URI`, `Simplib::Netlist`,
  `Simplib::Port`, `Simplib::Syslog::*`).
- `puppetlabs/stdlib` `>= 8.0.0 < 10.0.0` — provides the `Stdlib::*` types and
  `getvar()`.

Optional dependency (from `metadata.json` `simp.optional_dependencies`):

- `simp/pki` `>= 6.2.0 < 7.0.0` — used **only** when `$pki` is truthy, asserted
  at runtime via `simplib::assert_optional_dependency($module_name, 'simp/pki')`
  (`create_home_dirs.pp:183`). This is the module's only optional dependency.

Fixture-only repositories (from `.fixtures.yml`, checked out for test
compilation, not runtime deps): the runtime and optional deps above plus a large
acceptance stack — `autofs`, `ds389`, `simp_ds389`, `simp_openldap`, `sssd`,
`stunnel`, `simp_firewalld`/`firewalld`/`iptables`, `pam`, `ssh`, `svckill`,
`systemd`, `simp_options`, and others.

Runtime requirement (from `metadata.json` `requirements`): `puppet
>= 7.0.0 < 9.0.0`. This is an **older baseline** than some SIMP modules and it
names **`puppet`** (not `openvox`). SIMP is migrating Puppet → OpenVox; if
`metadata.json` switches this to `openvox`, update this line to match.

Supported OS matrix (from `metadata.json`): CentOS 7/8/9; RedHat 7/8/9;
OracleLinux 7/8/9; Rocky 8/9; AlmaLinux 8/9.

## Repository layout

- `manifests/init.pp` — the `simp_nfs` entry class (server-vs-client role
  selection).
- `manifests/export/home.pp` — `simp_nfs::export::home`, the NFS server side
  (export tree, bind mount, stunnel fork, LDAP hook).
- `manifests/create_home_dirs.pp` — `simp_nfs::create_home_dirs`, the LDAP-driven
  home-dir-creation script + systemd timer + optional PKI.
- `manifests/mount/home.pp` — `simp_nfs::mount::home`, the NFS client side
  (autofs NFSv4 mount + SELinux boolean).
- `templates/create_home_directories.rb.erb` — the Ruby script rendered by
  `create_home_dirs` that binds to LDAP and creates home directories.
- `metadata.json` — deps, optional deps, OS matrix, Puppet requirement.
- `spec/classes/init_spec.rb`, `spec/classes/create_home_dirs_spec.rb` —
  rspec-puppet unit tests.
- `spec/acceptance/suites/default/` — beaker acceptance suite: stands up a 389DS
  directory server (`00_setup_389ds_spec.rb`, `00_setup_ldap_spec.rb`), then
  exercises the default (`10_default_spec.rb`) and no-stunnel
  (`11_nostunnel_spec.rb`) paths, with hieradata `.erb` fixtures under `files/`.
- `spec/acceptance/nodesets/` — two nodesets: `default.yml` and `oel.yml`.
- `REFERENCE.md` — generated Puppet Strings reference.
- No `data/`, `lib/`, or `types/` — this module ships **no module data
  (Hiera-in-module)**, no custom Ruby types/providers/functions/facts, and no
  custom Puppet data types. Every custom type and function it uses comes from
  the dependencies above; the only asset is the one ERB template.
- **Acceptance is NOT run in CI:** `.github/workflows/pr_tests.yml` has only the
  standard six jobs — `puppet-syntax`, `puppet-style`, `ruby-style`,
  `file-checks`, `releng-checks`, and `spec-tests`. The shipped nodesets are run
  manually / locally.

## Common commands

```sh
# Install dependencies
bundle install

# Run all unit tests
bundle exec rake spec

# Run a single class spec
bundle exec rspec spec/classes/init_spec.rb
bundle exec rspec spec/classes/create_home_dirs_spec.rb

# Puppet lint
bundle exec rake lint

# Ruby lint
bundle exec rake rubocop

# Regenerate REFERENCE.md from puppet-strings docstrings
puppet strings generate --format markdown --out REFERENCE.md

# Run a beaker acceptance suite against a shipped nodeset (run manually — not in CI)
bundle exec rake beaker:suites[default]
```

The `Gemfile` installs the **`puppet` gem only** (`gem 'puppet', puppet_version`,
`Gemfile:29`), with `puppet_version` defaulting to `['>= 7', '< 9']`
(`Gemfile:23`) — there is no `openvox` gem here. Relevant gem pins (from
`Gemfile`): `rubocop ~> 1.88.0` (`Gemfile:16`), `puppetlabs_spec_helper ~> 8.0.0`
(`Gemfile:30`), `simp-rake-helpers ~> 5.24.0` (`Gemfile:36`), and
`simp-beaker-helpers ~> 2.0.0` (`Gemfile:52`). `spec/spec_helper.rb:11` requires
`puppetlabs_spec_helper/module_spec_helper`.

## Conventions

- Preserve the `@summary` / `@param` puppet-strings docstrings on each class —
  they drive `REFERENCE.md`. Regenerate `REFERENCE.md` after changing docs or
  parameters.
- Keep this module a **profile**: drive NFS through `simp/nfs`
  classes/defines and parameters; don't add raw NFS resources or reimplement
  what `simp/nfs` provides.
- Continue routing SIMP feature toggles through
  `simplib::lookup('simp_options::*', { 'default_value' => ... })` rather than
  assuming `simp_options` is included. Preserve the deliberate no-default LDAP
  credential lookups (`create_home_dirs.pp:117-120`).
- Guard the optional PKI integration with
  `simplib::assert_optional_dependency` inside the `if $pki` branch, as
  `create_home_dirs` does — don't hard-`include` `simp/pki`.
- `Gemfile`, `spec/spec_helper.rb`, and `.github/workflows/pr_tests.yml` carry a
  **puppetsync** notice — they are baseline-managed and the next sync overwrites
  local edits. Push changes to those files upstream to the baseline, not here.
- Match the existing 2-space Puppet indentation and aligned-arrow parameter
  style used throughout `manifests/`.
