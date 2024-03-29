# Reference

<!-- DO NOT EDIT: This document was generated by Puppet Strings -->

## Table of Contents

### Classes

* [`simp_nfs`](#simp_nfs): A SIMP Profile for common NFS configurations
* [`simp_nfs::create_home_dirs`](#simp_nfs--create_home_dirs): Adds a script to create user home directories for directory server
by pulling users from LDAP
* [`simp_nfs::export::home`](#simp_nfs--export--home): Configures an NFS server to share centralized home directories via NFSv4
* [`simp_nfs::mount::home`](#simp_nfs--mount--home): Set up an ``NFS4`` client to point to mount your remote home directories

## Classes

### <a name="simp_nfs"></a>`simp_nfs`

A SIMP Profile for common NFS configurations

#### Parameters

The following parameters are available in the `simp_nfs` class:

* [`export_home_dirs`](#-simp_nfs--export_home_dirs)
* [`home_dir_server`](#-simp_nfs--home_dir_server)
* [`autodetect_remote`](#-simp_nfs--autodetect_remote)
* [`use_autofs`](#-simp_nfs--use_autofs)

##### <a name="-simp_nfs--export_home_dirs"></a>`export_home_dirs`

Data type: `Boolean`

Set up home directory exports for this system

* The ``simp_options::trusted_nets`` parameter will govern what clients may
  connect to the share by default.
* Further configuration for home directory exports can be tweaked via the
  parameters in ``simp_nfs::export_home``

Default value: `false`

##### <a name="-simp_nfs--home_dir_server"></a>`home_dir_server`

Data type: `Optional[Simplib::Ip]`

If set, specifies the server from which you want to mount NFS home
directories for your users

* If ``$export_home_dirs`` is also set, this class will assume that you
  want to mount on the local server if this is set at all
* Further configuration for the home directory mounts can be tweaked via
  the parameters in ``simp_nfs::mount::home``

Default value: `undef`

##### <a name="-simp_nfs--autodetect_remote"></a>`autodetect_remote`

Data type: `Boolean`

Use inbuilt autodetection to determine if the local system is the server
from which we should be mouting directories

* Generally, you should set this to ``false`` if you have issues with the
  system mounting to ``127.0.0.1`` when your home directories are actually
  on another system

Default value: `true`

##### <a name="-simp_nfs--use_autofs"></a>`use_autofs`

Data type: `Boolean`

Use ``autofs`` for home directory mounts

Default value: `true`

### <a name="simp_nfs--create_home_dirs"></a>`simp_nfs::create_home_dirs`

https://github.com/simp/pupmod-simp-simp_nfs/graphs/contributors

#### Parameters

The following parameters are available in the `simp_nfs::create_home_dirs` class:

* [`uri`](#-simp_nfs--create_home_dirs--uri)
* [`enable`](#-simp_nfs--create_home_dirs--enable)
* [`create_home_script`](#-simp_nfs--create_home_dirs--create_home_script)
* [`run_schedule`](#-simp_nfs--create_home_dirs--run_schedule)
* [`base_dn`](#-simp_nfs--create_home_dirs--base_dn)
* [`bind_dn`](#-simp_nfs--create_home_dirs--bind_dn)
* [`bind_pw`](#-simp_nfs--create_home_dirs--bind_pw)
* [`export_dir`](#-simp_nfs--create_home_dirs--export_dir)
* [`skel_dir`](#-simp_nfs--create_home_dirs--skel_dir)
* [`ldap_scope`](#-simp_nfs--create_home_dirs--ldap_scope)
* [`port`](#-simp_nfs--create_home_dirs--port)
* [`tls`](#-simp_nfs--create_home_dirs--tls)
* [`quiet`](#-simp_nfs--create_home_dirs--quiet)
* [`syslog_facility`](#-simp_nfs--create_home_dirs--syslog_facility)
* [`syslog_severity`](#-simp_nfs--create_home_dirs--syslog_severity)
* [`strip_128_bit_ciphers`](#-simp_nfs--create_home_dirs--strip_128_bit_ciphers)
* [`tls_cipher_suite`](#-simp_nfs--create_home_dirs--tls_cipher_suite)
* [`pki`](#-simp_nfs--create_home_dirs--pki)
* [`app_pki_external_source`](#-simp_nfs--create_home_dirs--app_pki_external_source)
* [`app_pki_dir`](#-simp_nfs--create_home_dirs--app_pki_dir)
* [`app_pki_key`](#-simp_nfs--create_home_dirs--app_pki_key)
* [`app_pki_cert`](#-simp_nfs--create_home_dirs--app_pki_cert)
* [`app_pki_ca_dir`](#-simp_nfs--create_home_dirs--app_pki_ca_dir)
* [`package_ensure`](#-simp_nfs--create_home_dirs--package_ensure)

##### <a name="-simp_nfs--create_home_dirs--uri"></a>`uri`

Data type: `Array[Simplib::URI]`

The uri(s) of the LDAP servers

Default value: `simplib::lookup('simp_options::ldap::uri')`

##### <a name="-simp_nfs--create_home_dirs--enable"></a>`enable`

Data type: `Boolean`

Enable or disable the systemd timer that runs the script to create home
directories for users.

Default value: `true`

##### <a name="-simp_nfs--create_home_dirs--create_home_script"></a>`create_home_script`

Data type: `Stdlib::AbsolutePath`

The path where to place the script.

Default value: `'/usr/local/bin/create_home_directories.rb'`

##### <a name="-simp_nfs--create_home_dirs--run_schedule"></a>`run_schedule`

Data type: `String`

The time schedule for the systemd timer.  See systemd.timer man
page for correct format.

Default value: `'*-*-* *:30:00'`

##### <a name="-simp_nfs--create_home_dirs--base_dn"></a>`base_dn`

Data type: `String`

The root DN that should be used when searching for entries

Default value: `simplib::lookup('simp_options::ldap::base_dn')`

##### <a name="-simp_nfs--create_home_dirs--bind_dn"></a>`bind_dn`

Data type: `String`

The DN to use when binding to the LDAP server

Default value: `simplib::lookup('simp_options::ldap::bind_dn')`

##### <a name="-simp_nfs--create_home_dirs--bind_pw"></a>`bind_pw`

Data type: `String`

The password to use when binding to the LDAP server

Default value: `simplib::lookup('simp_options::ldap::bind_pw')`

##### <a name="-simp_nfs--create_home_dirs--export_dir"></a>`export_dir`

Data type: `Stdlib::Absolutepath`

The location of the home directories being exported

* This location must be a puppet managed `File` resource
* See the `simp_nfs::export_home` class for an example

Default value: `'/var/nfs/home'`

##### <a name="-simp_nfs--create_home_dirs--skel_dir"></a>`skel_dir`

Data type: `Stdlib::Absolutepath`

The location of sample skeleton files for user directories

Default value: `'/etc/skel'`

##### <a name="-simp_nfs--create_home_dirs--ldap_scope"></a>`ldap_scope`

Data type: `Enum['one','sub','base']`

The search scope to use

Default value: `'one'`

##### <a name="-simp_nfs--create_home_dirs--port"></a>`port`

Data type: `Simplib::Port`

The target port on the LDAP server

* If none specified, defaults to `389` for regular and `start_tls`
  connections, and `636` for legacy SSL connections

Default value: `389`

##### <a name="-simp_nfs--create_home_dirs--tls"></a>`tls`

Data type: `Enum['ssl','start_tls','none']`

Whether or not to enable SSL/TLS for the connection

* `ssl`
    * `LDAPS` on port `636` unless  different `port` specified
        * Uses `simple_tls`; No validation of the LDAP server's SSL
          certificate is performed

* `start_tls`
    * Start TLS on port `389` unless different `port` specified

* `none`
    * LDAP without encryption on port `389` unless different `port`
      specified

Default value: `'start_tls'`

##### <a name="-simp_nfs--create_home_dirs--quiet"></a>`quiet`

Data type: `Boolean`

Whether or not to print potentially useful warnings

Default value: `true`

##### <a name="-simp_nfs--create_home_dirs--syslog_facility"></a>`syslog_facility`

Data type: `Simplib::Syslog::CFacility`

The syslog facility at which to log, must be Ruby `syslog` compatible

Default value: `'LOG_LOCAL6'`

##### <a name="-simp_nfs--create_home_dirs--syslog_severity"></a>`syslog_severity`

Data type: `Simplib::Syslog::CSeverity`

The syslog severity at which to log, must be Ruby `syslog` compatible

Default value: `'LOG_NOTICE'`

##### <a name="-simp_nfs--create_home_dirs--strip_128_bit_ciphers"></a>`strip_128_bit_ciphers`

Data type: `Boolean`

**Deprecated** This option does not affect any supported OSes

Default value: `true`

##### <a name="-simp_nfs--create_home_dirs--tls_cipher_suite"></a>`tls_cipher_suite`

Data type: `Array[String[1]]`

The TLS ciphers that should be used for the connection to LDAP

* This option was primarily provided for EL6 system support and may be
  deprecated in the future

Default value: `simplib::lookup('simp_options::openssl::cipher_suite', { 'default_value' => ['DEFAULT','!MEDIUM'] })`

##### <a name="-simp_nfs--create_home_dirs--pki"></a>`pki`

Data type: `Variant[Enum['simp'],Boolean]`

* If 'simp', include SIMP's pki module and use pki::copy to manage
  application certs in /etc/pki/simp_apps/nfs_home_server/x509
* If true, do *not* include SIMP's pki module, but still use pki::copy
  to manage certs in /etc/pki/simp_apps/nfs_home_server/x509
* If false, do not include SIMP's pki module and do not use pki::copy
  to manage certs.  You will need to appropriately assign a subset of:
  * app_pki_dir
  * app_pki_key
  * app_pki_cert
  * app_pki_ca
  * app_pki_ca_dir

Default value: `simplib::lookup('simp_options::pki', { 'default_value' => false })`

##### <a name="-simp_nfs--create_home_dirs--app_pki_external_source"></a>`app_pki_external_source`

Data type: `String`

* If pki = 'simp' or true, this is the directory from which certs will be
  copied, via pki::copy.  Defaults to /etc/pki/simp/x509.

* If pki = false, this variable has no effect.

Default value: `simplib::lookup('simp_options::pki::source', { 'default_value' => '/etc/pki/simp/x509' })`

##### <a name="-simp_nfs--create_home_dirs--app_pki_dir"></a>`app_pki_dir`

Data type: `Stdlib::Absolutepath`

This variable controls the basepath of $app_pki_key, $app_pki_cert,
$app_pki_ca, $app_pki_ca_dir, and $app_pki_crl.
It defaults to /etc/pki/simp_apps/nfs_home_server/pki.

Default value: `'/etc/pki/simp_apps/nfs_home_server/x509'`

##### <a name="-simp_nfs--create_home_dirs--app_pki_key"></a>`app_pki_key`

Data type: `Stdlib::AbsolutePath`

Path and name of the private SSL key file

Default value: `"${app_pki_dir}/private/${facts['networking']['fqdn']}.pem"`

##### <a name="-simp_nfs--create_home_dirs--app_pki_cert"></a>`app_pki_cert`

Data type: `Stdlib::AbsolutePath`

Path and name of the public SSL certificate

Default value: `"${app_pki_dir}/public/${facts['networking']['fqdn']}.pub"`

##### <a name="-simp_nfs--create_home_dirs--app_pki_ca_dir"></a>`app_pki_ca_dir`

Data type: `Stdlib::Absolutepath`

Path to the CA.

Default value: `"${app_pki_dir}/cacerts"`

##### <a name="-simp_nfs--create_home_dirs--package_ensure"></a>`package_ensure`

Data type: `String`

The ensure status of the `rubygem-net-ldap` package

Default value: `simplib::lookup('simp_options::package_ensure', { 'default_value' => 'installed' })`

### <a name="simp_nfs--export--home"></a>`simp_nfs::export::home`

Sets up the export root at ``${data_dir}/nfs/exports`` and then adds
``${data_dir}/nfs/home`` and submounts it under ``${data_dir}/nfs/exports``.

* The export root is the root NFS share directory for the NFSv4 pseudo
  filesystem. Each directory below that NFS share should be a bind mount
  to a directory on the NFS server.
* The exported home directory should be mounted as ``$nfs_server:/home`` from
  your clients, where ``$nfs_server`` is the IP address of the NFS server.

#### Examples

##### NFS Server System Hieradata

```puppet
---
nfs::is_server : true
simp::classes :
  - simp_nfs::export::home
```

##### NFS Client Home Mount

```puppet
---
simp_nfs::mount::home::nfs_server : <nfs_server_ip>
simp::classes :
  - simp_nfs::mount::home
```

#### Parameters

The following parameters are available in the `simp_nfs::export::home` class:

* [`data_dir`](#-simp_nfs--export--home--data_dir)
* [`trusted_nets`](#-simp_nfs--export--home--trusted_nets)
* [`sec`](#-simp_nfs--export--home--sec)
* [`create_home_dirs`](#-simp_nfs--export--home--create_home_dirs)

##### <a name="-simp_nfs--export--home--data_dir"></a>`data_dir`

Data type: `Stdlib::Absolutepath`



Default value: `'/var'`

##### <a name="-simp_nfs--export--home--trusted_nets"></a>`trusted_nets`

Data type: `Simplib::Netlist`

The networks that are allowed to mount this space

Default value: `simplib::lookup('simp_options::trusted_nets', { 'default_value' => ['127.0.0.1'] })`

##### <a name="-simp_nfs--export--home--sec"></a>`sec`

Data type: `Array[Enum['none','sys','krb5','krb5i','krb5p']]`

An Array of sec modes for the export.

Default value: `['sys']`

##### <a name="-simp_nfs--export--home--create_home_dirs"></a>`create_home_dirs`

Data type: `Boolean`

Automatically create user home directories from LDAP data

Default value: `simplib::lookup('simp_options::ldap', { 'default_value' => false })`

### <a name="simp_nfs--mount--home"></a>`simp_nfs::mount::home`

If this system is also the NFS server, you need to set
``nfs::client::is_server`` to ``true`` or set
``simp_nfs::mount::home::nfs_server`` to ``127.0.0.1``.

#### Parameters

The following parameters are available in the `simp_nfs::mount::home` class:

* [`nfs_server`](#-simp_nfs--mount--home--nfs_server)
* [`remote_path`](#-simp_nfs--mount--home--remote_path)
* [`local_home`](#-simp_nfs--mount--home--local_home)
* [`port`](#-simp_nfs--mount--home--port)
* [`sec`](#-simp_nfs--mount--home--sec)
* [`options`](#-simp_nfs--mount--home--options)
* [`at_boot`](#-simp_nfs--mount--home--at_boot)
* [`autodetect_remote`](#-simp_nfs--mount--home--autodetect_remote)
* [`use_autofs`](#-simp_nfs--mount--home--use_autofs)

##### <a name="-simp_nfs--mount--home--nfs_server"></a>`nfs_server`

Data type: `Simplib::IP`

The NFS server to which you will be connecting

* If you are the server, please make sure that this is ``127.0.0.1``

##### <a name="-simp_nfs--mount--home--remote_path"></a>`remote_path`

Data type: `Stdlib::Absolutepath`

The NFS share that you want to mount

Default value: `'/home'`

##### <a name="-simp_nfs--mount--home--local_home"></a>`local_home`

Data type: `Stdlib::Absolutepath`

The local base for home directories

* Most sites will want this to be ``/home`` but some may opt for something
  like ``/exports/home`` or the like.

* Top level directories will **not** be automatically managed

Default value: `'/home'`

##### <a name="-simp_nfs--mount--home--port"></a>`port`

Data type: `Optional[Simplib::Port]`

The NFS port to which to connect

Default value: `undef`

##### <a name="-simp_nfs--mount--home--sec"></a>`sec`

Data type: `Enum['sys','krb5','krb5i','krb5p']`

The sec mode for the mount

* Only valid with NFSv4

Default value: `'sys'`

##### <a name="-simp_nfs--mount--home--options"></a>`options`

Data type: `Optional[String]`

The mount options string that should be used

* fstype and port will already be set for you

Default value: `undef`

##### <a name="-simp_nfs--mount--home--at_boot"></a>`at_boot`

Data type: `Boolean`

Ensure that this mount is mounted at boot time

* Has no effect if ``$use_autofs`` is set

Default value: `true`

##### <a name="-simp_nfs--mount--home--autodetect_remote"></a>`autodetect_remote`

Data type: `Boolean`

Use inbuilt autodetection to determine if the local system is the server
from which we should be mouting directories

* Generally, you should set this to ``false`` if you have issues with the
  system mounting to ``127.0.0.1`` when your home directories are actually
  on another system

Default value: `true`

##### <a name="-simp_nfs--mount--home--use_autofs"></a>`use_autofs`

Data type: `Boolean`

Enable automounting with Autofs

Default value: `true`

