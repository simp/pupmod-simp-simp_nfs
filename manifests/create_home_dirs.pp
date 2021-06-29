# @summary Adds a script to create user home directories for directory server
#   by pulling users from LDAP
#
# @param uri
#   The uri(s) of the LDAP servers
#
# @param enable
#   Enable or disable the systemd timer that runs the script to create home
#   directories for users.
#
# @param create_home_script
#   The path where to place the script.
#
# @param run_schedule
#   The time schedule for the systemd timer.  See systemd.timer man
#   page for correct format.
#
# @param base_dn
#   The root DN that should be used when searching for entries
#
# @param bind_dn
#   The DN to use when binding to the LDAP server
#
# @param bind_pw
#   The password to use when binding to the LDAP server
#
# @param export_dir
#   The location of the home directories being exported
#
#   * This location must be a puppet managed `File` resource
#   * See the `simp_nfs::export_home` class for an example
#
# @param skel_dir
#   The location of sample skeleton files for user directories
#
# @param ldap_scope
#   The search scope to use
#
# @param port
#   The target port on the LDAP server
#
#   * If none specified, defaults to `389` for regular and `start_tls`
#     connections, and `636` for legacy SSL connections
#
# @param tls
#   Whether or not to enable SSL/TLS for the connection
#
#   * `ssl`
#       * `LDAPS` on port `636` unless  different `port` specified
#           * Uses `simple_tls`; No validation of the LDAP server's SSL
#             certificate is performed
#
#   * `start_tls`
#       * Start TLS on port `389` unless different `port` specified
#
#   * `none`
#       * LDAP without encryption on port `389` unless different `port`
#         specified
#
# @param quiet
#   Whether or not to print potentially useful warnings
#
# @param syslog_facility
#   The syslog facility at which to log, must be Ruby `syslog` compatible
#
# @param syslog_severity
#   The syslog severity at which to log, must be Ruby `syslog` compatible
#
# @param strip_128_bit_ciphers
#   **Deprecated** This option does not affect any supported OSes
#
# @param tls_cipher_suite
#   The TLS ciphers that should be used for the connection to LDAP
#
#   * This option was primarily provided for EL6 system support and may be
#     deprecated in the future
#
# @param pki
#   * If 'simp', include SIMP's pki module and use pki::copy to manage
#     application certs in /etc/pki/simp_apps/nfs_home_server/x509
#   * If true, do *not* include SIMP's pki module, but still use pki::copy
#     to manage certs in /etc/pki/simp_apps/nfs_home_server/x509
#   * If false, do not include SIMP's pki module and do not use pki::copy
#     to manage certs.  You will need to appropriately assign a subset of:
#     * app_pki_dir
#     * app_pki_key
#     * app_pki_cert
#     * app_pki_ca
#     * app_pki_ca_dir
#
# @param app_pki_external_source
#   * If pki = 'simp' or true, this is the directory from which certs will be
#     copied, via pki::copy.  Defaults to /etc/pki/simp/x509.
#
#   * If pki = false, this variable has no effect.
#
# @param app_pki_dir
#   This variable controls the basepath of $app_pki_key, $app_pki_cert,
#   $app_pki_ca, $app_pki_ca_dir, and $app_pki_crl.
#   It defaults to /etc/pki/simp_apps/nfs_home_server/pki.
#
# @param app_pki_key
#   Path and name of the private SSL key file
#
# @param app_pki_cert
#   Path and name of the public SSL certificate
#
# @param app_pki_ca_dir
#   Path to the CA.
#
# @param package_ensure The ensure status of the `rubygem-net-ldap` package
#
# https://github.com/simp/pupmod-simp-simp_nfs/graphs/contributors
#
class simp_nfs::create_home_dirs (
  Boolean                        $enable                  = true,
  Array[Simplib::URI]            $uri                     = simplib::lookup('simp_options::ldap::uri'),
  String                         $base_dn                 = simplib::lookup('simp_options::ldap::base_dn'),
  String                         $bind_dn                 = simplib::lookup('simp_options::ldap::bind_dn'),
  String                         $bind_pw                 = simplib::lookup('simp_options::ldap::bind_pw'),
  Variant[Enum['simp'],Boolean]  $pki                     = simplib::lookup('simp_options::pki', { 'default_value' => false }),
  String                         $app_pki_external_source = simplib::lookup('simp_options::pki::source', { 'default_value' => '/etc/pki/simp/x509' }),
  Stdlib::Absolutepath           $app_pki_dir             = '/etc/pki/simp_apps/nfs_home_server/x509',
  Stdlib::Absolutepath           $app_pki_ca_dir          = "${app_pki_dir}/cacerts",
  Stdlib::AbsolutePath           $app_pki_key             = "${app_pki_dir}/private/${facts['fqdn']}.pem",
  Stdlib::AbsolutePath           $app_pki_cert            = "${app_pki_dir}/public/${facts['fqdn']}.pub",
  Stdlib::Absolutepath           $export_dir              = '/var/nfs/home',
  Stdlib::Absolutepath           $skel_dir                = '/etc/skel',
  Stdlib::AbsolutePath           $create_home_script      = '/usr/local/bin/create_home_directories.rb',
  Enum['one','sub','base']       $ldap_scope              = 'one',
  Simplib::Port                  $port                    = 389,
  Enum['ssl','start_tls','none'] $tls                     = 'start_tls',
  String                         $run_schedule            = '*-*-* *:30:00',
  Boolean                        $quiet                   = true,
  Simplib::Syslog::CFacility     $syslog_facility         = 'LOG_LOCAL6',
  Simplib::Syslog::CSeverity     $syslog_severity         = 'LOG_NOTICE',
  Boolean                        $strip_128_bit_ciphers   = true,
  Array[String[1]]               $tls_cipher_suite        = simplib::lookup('simp_options::openssl::cipher_suite', { 'default_value' => ['DEFAULT','!MEDIUM'] }),
  String                         $package_ensure          = simplib::lookup('simp_options::package_ensure', { 'default_value' => 'installed' })
) {

  $_tls_cipher_suite = $tls_cipher_suite

  package { 'rubygem-net-ldap':
    ensure => $package_ensure
  }

  #  Remove the script from the cron directory
  file { '/etc/cron.hourly/create_home_directories.rb':
    ensure => 'absent'
  }

  file { $create_home_script:
    owner   => 'root',
    group   => 'root',
    mode    => '0500',
    content => template("${module_name}/create_home_directories.rb.erb"),
    notify  => [ Exec[$create_home_script] ],
    require => Package['rubygem-net-ldap']
  }

  $_timer = @("EOM")
  [Timer]
  OnCalendar=$run_schedule
  | EOM

  $_service = @("EOM")
  [Service]
  Type=oneshot
  SuccessExitStatus=0
  ExecStart=$create_home_script
  | EOM

  systemd::timer { 'nfs_create_home_dirs.timer':
    timer_content   => $_timer,
    service_content => $_service,
    active          => $enable,
    enable          => $enable,
    require         => File[$create_home_script]
  }

  if $pki {
    simplib::assert_optional_dependency($module_name, 'simp/pki')
    pki::copy { 'nfs_home_server':
      pki    => $pki,
      source => $app_pki_external_source,
      group  => 'root',
    }
  }

  exec { $create_home_script : refreshonly => true }
}
