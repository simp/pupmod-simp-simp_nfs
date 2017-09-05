[![License](http://img.shields.io/:license-apache-blue.svg)](http://www.apache.org/licenses/LICENSE-2.0.html) [![Build Status](https://travis-ci.org/simp/pupmod-simp-simp_nfs.svg)](https://travis-ci.org/simp/pupmod-simp-simp_nfs) [![SIMP compatibility](https://img.shields.io/badge/SIMP%20compatibility-6.*-orange.svg)](https://img.shields.io/badge/SIMP%20compatibility-6.*-orange.svg)

#### Table of Contents

1. [Description](#description)
2. [Setup - The basics of getting started with simp_nfs](#setup)
    * [What simp_nfs affects](#what-simp_nfs-affects)
3. [Usage - Configuration options and additional functionality](#usage)
4. [Reference - An under-the-hood peek at what the module is doing and how](#reference)
5. [Known Issues](#known-issues)
6. [Limitations - OS compatibility, etc.](#limitations)
7. [Development - Guide for contributing to the module](#development)
    * [Acceptance Tests - Beaker env variables](#acceptance-tests)

## Description

This module is a [SIMP](https://simp-project.com) Puppet profile for setting up
common NFS configurations as supported by the SIMP ecosystem

### This is a SIMP module

This module is a component of the [System Integrity Management Platform](https://github.com/NationalSecurityAgency/SIMP), a
compliance-management framework built on Puppet.

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
simp_nfs::home_dir_server : <your NFS server IP or Hostname>
```

## Reference

See the [API Documentation](https://github.com/simp/pupmod-simp-simp_nfs/tree/master/docs/index.html) for full details.

## Known Issues

The ``autofs package`` that was released with CentOS 6.8 (**autofs-5.0.5-122**) worked
properly over a stunnel connection.

The release shipped with CentOS 6.9 (**5.0.5-132**) prevents any connection from happening
to the local ``stunnel`` process and breaks mounts to remote systems over stunnel connections.

To use NFS over stunnel on CentOS 6.9 and automount directories the old package must be used.

To determine what package is installed on the system, run ``automount -V``.

This has been identified as a bug in autofs and is being publicly
tracked at https://bugs.centos.org/view.php?id=13575.

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

Please read our [Contribution Guide](http://simp-doc.readthedocs.io/en/stable/contributors_guide/index.html).

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
