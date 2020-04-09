# @summary A SIMP Profile for common NFS configurations
#
# @param export_home_dirs
#   Set up home directory exports for this system
#
#   * The ``simp_options::trusted_nets`` parameter will govern what clients may
#     connect to the share by default.
#   * Further configuration for home directory exports can be tweaked via the
#     parameters in ``simp_nfs::export_home``
#
# @param home_dir_server
#   If set, specifies the server from which you want to mount NFS home
#   directories for your users
#
#   * If ``$export_home_dirs`` is also set, this class will assume that you
#     want to mount on the local server if this is set at all
#   * Further configuration for the home directory mounts can be tweaked via
#     the parameters in ``simp_nfs::mount::home``
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
#   Use ``autofs`` for home directory mounts
#
class simp_nfs (
  Boolean                 $export_home_dirs  = false,
  Optional[Simplib::Ip]   $home_dir_server   = undef,
  Boolean                 $autodetect_remote = true,
  Boolean                 $use_autofs        = true
) {
  if $export_home_dirs {
    class { 'nfs': * => { 'is_server' => true } }

    include '::simp_nfs::export::home'

    if $home_dir_server {
      class { 'simp_nfs::mount::home':
        nfs_server        => '127.0.0.1',
        autodetect_remote => $autodetect_remote,
        use_autofs        => $use_autofs
      }
    }
  }
  else {
    class { 'nfs': * => { 'is_client' => true } }

    if $home_dir_server {
      class { 'simp_nfs::mount::home':
        nfs_server        => $home_dir_server,
        autodetect_remote => $autodetect_remote,
        use_autofs        => $use_autofs
      }
    }
  }
}
