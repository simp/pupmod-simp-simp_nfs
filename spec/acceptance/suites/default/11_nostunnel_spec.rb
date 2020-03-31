require 'spec_helper_acceptance'

test_name 'SIMP NFS profile'

describe 'simp_nfs stock classes' do
  servers = hosts_with_role( hosts, 'nfs_server' )
  clients = hosts_with_role( hosts, 'client' )
  ldap_server = only_host_with_role(hosts,'ldap')
  ldap_fqdn = fact_on(ldap_server, 'fqdn')

  _domains = fact_on(ldap_server, 'domain').split('.')
  _domains.map! { |d|
    "dc=#{d}"
  }
  domains = _domains.join(',')
  hiera_file = File.expand_path('./files/common_hieradata.yaml',File.dirname(__FILE__))
  hieradata_common = File.read(hiera_file).gsub('SERVERNAME',ldap_fqdn).gsub('simp_options::stunnel: true','simp_options::stunnel: false')

  el8_server_host =only_host_with_role(servers,'el8')
  el8_server = fact_on(el8_server_host, 'fqdn')
  el8_server_ip = fact_on(el8_server_host,%(ipaddress_#{get_private_network_interface(el8_server_host)}))
  el7_server_host =only_host_with_role(servers,'el7')
  el7_server = fact_on(el7_server_host, 'fqdn')
  el7_server_ip = fact_on(el7_server_host,%(ipaddress_#{get_private_network_interface(el7_server_host)}))

  context 'with exported home directories with no stunnel on a non-default data_dir' do
    hosts.each do |node|

      # Determine who your nfs server is
      os = fact_on(node, 'operatingsystem')
      if os =~ /CentOS|RedHat|OracleLinux/
        os_release = fact_on(node, 'operatingsystemmajrelease')
        case  os_release
        when '7'
          server = el7_server
          server_ip = el7_server_ip
        when '8'
          server = el8_server
          server_ip = el8_server_ip
        else
          STDERR.puts "#{os_release} not a supported OS release"
          next
        end
      else
        STDERR.puts "OS #{os} not supported"
        next
      end
      nfs_server = server
      nfs_server_ip = server_ip

      manifest = <<-EOM
        include 'simp_options'
        include 'pam::access'
        include 'sudo'
        include 'ssh'
        include 'simp::nsswitch'
        include 'simp_openldap::client'
        include 'simp::sssd::client'
        include 'simp_nfs'
      EOM

      hieradata_extra = <<-EOM

simp_nfs::home_dir_server: #{nfs_server_ip}
nfs::client::stunnel::nfs_server: #{nfs_server}
#mount to /mnt so vagrant home directory is not overwritten
simp_nfs::mount::home::local_home: /mnt
      EOM

      if servers.include?(node)
        it 'should install nfs using alternate data directory' do
          # Construct server hieradata; export home directories.
          server_hieradata = hieradata_common + hieradata_extra + <<-EOM.gsub(/^\s+/,'')
            nfs::is_server: true
            simp_nfs::create_home_dirs: true
            simp_nfs::export::home::data_dir: '/var/newnfs'
          EOM

          _server_manifest = <<-EOM
             include 'simp_nfs::export::home'
              #make sure sssd is configured before running
              #create_home_directories or it fails.
              Class['simp::sssd::client'] ->  Class['simp_nfs::export::home']
              file { '/var/newnfs':
                ensure => 'directory',
                owner  => 'root',
                group => 'root',
                mode => '0755',
                before => Class['simp_nfs']
              }
          EOM

          if node == ldap_server
            server_manifest = manifest + _server_manifest  + <<-EOM
              include simp::server::ldap
            EOM
          else
            server_manifest = manifest + _server_manifest
          end

          # Apply
          set_hieradata_on(node, server_hieradata, 'default')
          #remove stale mount point
          on(node, 'umount /mnt/test.user')
          apply_manifest_on(node, server_manifest, catch_failures: true)
          apply_manifest_on(node, server_manifest, catch_failures: true)
          apply_manifest_on(node, server_manifest, catch_changes: true)

          # Ensure the cache is built, don't wait for enum timeout
          on(node, 'service sssd restart')
        end
      else
        it "should set up #{node}" do
          client_hieradata = hieradata_common + hieradata_extra
          set_hieradata_on(node, client_hieradata, 'default')
          #remove stale mount point from previous test
          on(node, 'umount /mnt/test.user')
          apply_manifest_on(node, manifest, catch_failures: true)
          apply_manifest_on(node, manifest, catch_changes: true)
          #  LDAP server should be set up and the client should be able
          #  to talk to it.
        end
      end
    end

    it 'should create the test.user home directory mount on the servers using the cron job' do
      servers.each do |node|
        # Create test.user's homedir via cron, and ensure it gets mounted
        on(node, '/etc/cron.hourly/create_home_directories.rb')
        on(node, 'ls /var/nfs/home/test.user')
        on(node, "runuser -l test.user -c 'touch ~/newtestfile'")
        mount = on(node, "mount")
        expect(mount.stdout).to match(/127.0.0.1:\/home\/test.user.*nfs/)
      end
    end

    it 'should have file propagation to the clients' do
      clients.each do |node|
        retry_on(node, 'ls /mnt/test.user/newtestfile', acceptable_exit_codes: [0])
      end
    end
  end
end
