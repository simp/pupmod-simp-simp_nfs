# Adds a script to create user home directories for directory server
# by pulling users from LDAP
#
# @param uri
#   The uri(s) of the LDAP servers
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
#   * This location must be a puppet managed ``File`` resource
#   * See the ``simp_nfs::export_home`` class for an example
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
#   * If none specified, defaults to ``389`` for regular and ``start_tls``
#     connections, and ``636`` for legacy SSL connections
#
# @param tls
#   Whether or not to enable SSL/TLS for the connection
#
#   * ``ssl``
#       * ``LDAPS`` on port ``636`` unless  different ``port`` specified
#           * Uses ``simple_tls``; No validation of the LDAP server's SSL
#             certificate is performed
#
#   * ``start_tls``
#       * Start TLS on port ``389`` unless different ``port`` specified
#
#   * ``none``
#       * LDAP without encryption on port ``389`` unless different ``port``
#         specified
#
# @param quiet
#   Whether or not to print potentially useful warnings
#
# @param syslog_facility
#   The syslog facility at which to log, must be Ruby ``syslog`` compatible
#
# @param syslog_severity
#   The syslog severity at which to log, must be Ruby ``syslog`` compatible
#
# @author Trevor Vaughan <mailto:tvaughan@onyxpoint.com>
#
class simp_nfs::create_home_dirs (
  Array[Simplib::URI]            $uri             = simplib::lookup('simp_options::ldap::uri'),
  String                         $base_dn         = simplib::lookup('simp_options::ldap::base_dn'),
  String                         $bind_dn         = simplib::lookup('simp_options::ldap::bind_dn'),
  String                         $bind_pw         = simplib::lookup('simp_options::ldap::bind_pw'),
  Stdlib::Absolutepath           $export_dir      = '/var/nfs/home',
  Stdlib::Absolutepath           $skel_dir        = '/etc/skel',
  Enum['one','sub','base']       $ldap_scope      = 'one',
  Simplib::Port                  $port            = 389,
  Enum['ssl','start_tls','none'] $tls             = 'start_tls',
  Boolean                        $quiet           = true,
  Simplib::Syslog::CFacility     $syslog_facility = 'LOG_LOCAL6',
  Simplib::Syslog::CSeverity     $syslog_severity = 'LOG_NOTICE',
) {
  package { 'rubygem-net-ldap': ensure => 'latest' }

  file { '/etc/cron.hourly/create_home_directories.rb':
    owner   => 'root',
    group   => 'root',
    mode    => '0500',
    content => template("${module_name}/etc/cron.hourly/create_home_directories.rb.erb"),
    notify  => [ Exec['/etc/cron.hourly/create_home_directories.rb'] ],
    require => Package['rubygem-net-ldap']
  }

  exec { '/etc/cron.hourly/create_home_directories.rb': refreshonly => true }
}
