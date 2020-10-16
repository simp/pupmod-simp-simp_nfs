[![License](https://img.shields.io/:license-apache-blue.svg)](https://www.apache.org/licenses/LICENSE-2.0.html)
[![CII Best Practices](https://bestpractices.coreinfrastructure.org/projects/73/badge)](https://bestpractices.coreinfrastructure.org/projects/73)
[![Puppet Forge](https://img.shields.io/puppetforge/v/simp/simp_nfs.svg)](https://forge.puppetlabs.com/simp/simp_nfs)
[![Puppet Forge Downloads](https://img.shields.io/puppetforge/dt/simp/simp_nfs.svg)](https://forge.puppetlabs.com/simp/simp_nfs)
[![Build Status](https://travis-ci.org/simp/pupmod-simp-simp_nfs.svg)](https://travis-ci.org/simp/pupmod-simp-simp_nfs)

#### Table of Contents

<!-- vim-markdown-toc GFM -->

* [Description](#description)
  * [This is a SIMP module](#this-is-a-simp-module)
* [Setup](#setup)
  * [What simp_nfs affects](#what-simp_nfs-affects)
* [Usage](#usage)
  * [Serve NFS Home Directories over Stunnel](#serve-nfs-home-directories-over-stunnel)
  * [Mount NFS Home Directories](#mount-nfs-home-directories)
  * [Mount Home NFS Directories on another NFS server](#mount-home-nfs-directories-on-another-nfs-server)
* [Reference](#reference)
* [Known Issues](#known-issues)
* [Limitations](#limitations)
* [Development](#development)
  * [Acceptance tests](#acceptance-tests)

<!-- vim-markdown-toc -->

## Description

This module is a [SIMP](https://simp-project.com) Puppet profile for setting up
common NFS configurations as supported by the SIMP ecosystem

### This is a SIMP module

This module is a component of the [System Integrity Management Platform](https://simp-project.com),
a compliance-management framework built on Puppet.


If you find any issues, they may be submitted to our [bug tracker](https://simp-project.atlassian.net/).

This module is optimally designed for use within a larger SIMP ecosystem, but
it can be used independently:

 * When included within the SIMP ecosystem, security compliance settings will
   be managed from the Puppet server.
 * If used independently, all SIMP-managed security subsystems are disabled by
   default and must be explicitly opted into by administrators.  Please review
   the parameters in
   [`simp/simp_options`](https://github.com/simp/pupmod-simp-simp_options) for
   details.

## Setup

### What simp_nfs affects

This module provides commonly used configurations for NFS server and client
systems.

## Usage

### Serve NFS Home Directories over Stunnel

To export home directories for your users, over an Stunnel encrypted
connection, use the following code and Hiera data:

```ruby
include 'simp_nfs'
```

```yaml
---
simp_options::stunnel: true
simp_nfs::export_home_dirs: true
```

### Mount NFS Home Directories

To mount your exported home directories, over an Stunnel encrypted connection,
use the following code and Hiera data:

```ruby
include 'simp_nfs'
```

```yaml
---
simp_options::stunnel: true
simp_nfs::home_dir_server : <your NFS server IP>
```

### Mount Home NFS Directories on another NFS server

To mount home directories on another NFS server do not include the ``simp_nfs``
class. This will try to call the ``nfs`` class a second time.  Instead
create a site manifest and call the ``simp_nfs::mount::home`` class directly.
Note: Use the port parameter if you are using stunnel and set it to a different
port then the one the local NFS server is using.

```ruby
class  mounthome {
  class { simp_nfs::mount::home:
    nfs_server        => $home_server,
    port              => 12049,
    autodetect_remote => false
  }
}
```

```ruby
include mounthome
```

## Reference

See [REFERENCE.md](REFERENCE.md) for details.

## Known Issues

The ``autofs`` package that was released with CentOS 7.3 (**5.0.7-56**)
worked properly over a ``stunnel`` connection.

The release shipped with with CentOS 7.4 (**5.0.7-69**) prevents any connection
from happening to the local ``stunnel`` process and breaks mounts to remote systems
over ``stunnel`` connections.

The release that ship with CentOS 7.6 (**5.0.7-99**) has fixed the issue.

To use NFS over ``stunnel`` and ``automount`` directories with old
CentOS 7 releases, you must use the appropriate ``autofs`` package.

To determine what version of ``autofs`` is installed, run ``automount -V``.

To force the package to the desired version:

* Make sure the package is available via your package-management facility then
  set the package version in Hiera data:

``` yaml
   autofs::autofs_package_ensure: '5.0.7-99'
```

* Alternatively, ensure that the latest packages are available and set the
  following:

``` yaml
   autofs::autofs_package_ensure: 'latest'
```


The associated bug reports can be found at:

- CentOS 7  https://bugs.centos.org/view.php?id=14080.

## Limitations

This is a SIMP Profile. It will not expose **all** options of the underlying
modules, only the ones that are conducive to a supported SIMP infrastructure.
If you need to do things that this module does not cover, you may need to
create your own profile or inherit this profile and extend it to meet your
needs.

SIMP Puppet modules are generally intended for use on Red Hat Enterprise Linux
and compatible distributions, such as CentOS. Please see the
[`metadata.json` file](./metadata.json) for the most up-to-date list of
supported operating systems, Puppet versions, and module dependencies.

## Development

Please read our [Contribution Guide](https://simp.readthedocs.io/en/stable/contributors_guide/index.html).

### Acceptance tests

This module includes [Beaker](https://github.com/puppetlabs/beaker) acceptance
tests using the SIMP [Beaker Helpers](https://github.com/simp/rubygem-simp-beaker-helpers).
By default the tests use [Vagrant](https://www.vagrantup.com/) with
[VirtualBox](https://www.virtualbox.org) as a back-end; Vagrant and VirtualBox
must both be installed to run these tests without modification. To execute the
tests run the following:

```shell
bundle install
bundle exec rake beaker:suites
```

Please refer to the [SIMP Beaker Helpers documentation](https://github.com/simp/rubygem-simp-beaker-helpers/blob/master/README.md)
for more information.
