# Set up an ``NFS4`` client to point to mount your remote home directories
#
# If this system is also the NFS server, you need to set
# ``nfs::client::is_server`` to ``true`` or set
# ``simp_nfs::mount::home::nfs_server`` to ``127.0.0.1``.
#
# @param nfs_server
#   The NFS server to which you will be connecting
#
#   * If you are the server, please make sure that this is ``127.0.0.1``
#
# @param remote_path
#   The NFS share that you want to mount
#
# @param local_home
#   The local base for home directories
#
#   * Most sites will want this to be ``/home`` but some may opt for something
#     like ``/exports/home`` or the like.
#
#   * Top level directories will **not** be automatically managed
#
# @param port
#   The NFS port to which to connect
#
# @param sec
#   The sec mode for the mount
#
#   * Only valid with NFSv4
#
# @param options
#   The mount options string that should be used
#
#   * fstype and port will already be set for you
#
# @param at_boot
#   Ensure that this mount is mounted at boot time
#
#   * Has no effect if ``$use_autofs`` is set
#
# @param autodetect_remote
#   Use inbuilt autodetection to determine if the local system is the server
#   from which we should be mouting directories
#
#   * Generally, you should set this to ``false`` if you have issues with the
#     system mounting to ``127.0.0.1`` when your home directories are actually
#     on another system
#
# @param use_autofs
#   Enable automounting with Autofs
#
# @author Trevor Vaughan <mailto:tvaughan@onyxpoint.com>
# @author Kendall Moore <mailto:kmoore@keywcorp.com>
#
class simp_nfs::mount::home (
  Simplib::Host                      $nfs_server,
  Stdlib::Absolutepath               $remote_path       = '/home',
  Stdlib::Absolutepath               $local_home        = '/home',
  Optional[Simplib::Port]            $port              = undef,
  Enum['sys','krb5','krb5i','krb5p'] $sec               = 'sys',
  Optional[String]                   $options           = undef,
  Boolean                            $at_boot           = true,
  Boolean                            $autodetect_remote = true,
  Boolean                            $use_autofs        = true
) {
  if getvar('::nfs::client::is_server') {
    $_target = '127.0.0.1'
  }
  else {
    $_target = $nfs_server
  }

  if $facts['selinux_current_mode'] and ($facts['selinux_current_mode'] != 'disabled') {
    selboolean { 'use_nfs_home_dirs':
      persistent => true,
      value      => 'on'
    }
  }

  if $use_autofs {
    $_local_home = "wildcard-${local_home}"
  }
  else {
    $_local_home = $local_home
  }

  nfs::client::mount { $_local_home:
    nfs_server         => $nfs_server,
    remote_path        => $remote_path,
    port               => $port,
    nfs_version        => 'nfs4',
    sec                => $sec,
    options            => $options,
    at_boot            => $at_boot,
    autodetect_remote  => $autodetect_remote,
    autofs             => $use_autofs,
    autofs_map_to_user => true
  }
}
