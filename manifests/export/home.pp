# Configures an NFS server to share centralized home directories via NFSv4
#
# Sets up the export root at ``${data_dir}/nfs/exports`` and then adds
# ``${data_dir}/nfs/home`` and submounts it under ``${data_dir}/nfs/exports``.

# It should be mounted as ``$nfs_server:/home`` from your clients.
#
# The NFS clients must be provided with the hostname of the NFS server:
#
# @example NFS Server System Hieradata
#   ---
#   nfs::is_server : true
#   classes :
#     - simp_nfs::export::home
#
# @example NFS Client Home Mount
#   ---
#   simp_nfs::mount::home::nfs_server : <nfs_server_ip>
#   classes :
#     - simp_nfs::mount::home
#
# @param data_dir
#
# @param trusted_nets
#   The networks that are allowed to mount this space
#
# @param sec
#   An Array of sec modes for the export.
#
# @param create_home_dirs
#   Automatically create user home directories from LDAP data
#
# @author Trevor Vaughan <tvaughan@onyxpoint.com>
# @author Kendall Moore <kmoore@onyxpoint.com>
#
class simp_nfs::export::home (
  Stdlib::Absolutepath                             $data_dir         = '/var',
  Simplib::Netlist                                 $trusted_nets     = simplib::lookup('simp_options::trusted_nets', { 'default_value' => ['127.0.0.1'] }),
  Array[Enum['none','sys','krb5','krb5i','krb5p']] $sec              = ['sys'],
  Boolean                                          $create_home_dirs = simplib::lookup('simp_options::ldap', { 'default_value' => false })
) inherits simp_nfs {
  include '::nfs::server'

  if $create_home_dirs { include '::simp_nfs::create_home_dirs' }

  if !$::nfs::stunnel {
    nfs::server::export { 'nfs4_root':
      clients     => nets2cidr($trusted_nets),
      export_path => "${data_dir}/nfs/exports",
      sec         => $sec,
      fsid        => '0',
      crossmnt    => true
    }

    nfs::server::export { 'home_dirs':
      clients     => nets2cidr($trusted_nets),
      export_path => "${data_dir}/nfs/exports/home",
      rw          => true,
      sec         => $sec
    }
  }
  else {
    nfs::server::export { 'nfs4_root':
      clients     => ['127.0.0.1'],
      export_path => "${data_dir}/nfs/exports",
      sec         => $sec,
      fsid        => '0',
      crossmnt    => true,
      insecure    => true
    }

    nfs::server::export { 'home_dirs':
      clients     => ['127.0.0.1'],
      export_path => "${data_dir}/nfs/exports/home",
      rw          => true,
      sec         => $sec,
      insecure    => true
    }
  }

  file {
    [ "${data_dir}/nfs",
      "${data_dir}/nfs/exports",
      "${data_dir}/nfs/exports/home",
      "${data_dir}/nfs/home"
    ]:
    ensure => 'directory',
    owner  => 'root',
    group  => 'root',
    mode   => '0755'
  }

  if $create_home_dirs {
    File["${data_dir}/nfs/exports/home"] -> Class['simp_nfs::create_home_dirs']
    File["${data_dir}/nfs/home"]         -> Class['simp_nfs::create_home_dirs']
  }

  mount { "${data_dir}/nfs/exports/home":
    ensure   => 'mounted',
    fstype   => 'none',
    device   => "${data_dir}/nfs/home",
    remounts => true,
    options  => 'rw,bind',
    require  => [
      File["${data_dir}/nfs/exports/home"],
      File["${data_dir}/nfs/home"]
    ]
  }
}
