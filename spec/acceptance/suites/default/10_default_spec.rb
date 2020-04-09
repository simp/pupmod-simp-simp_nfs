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
  hieradata_common = File.read(hiera_file).gsub('SERVERNAME',ldap_fqdn)

  el8_server_host =only_host_with_role(servers,'el8')
  el8_server = fact_on(el8_server_host, 'fqdn')
  el8_server_ip = fact_on(el8_server_host,%(ipaddress_#{get_private_network_interface(el8_server_host)}))
  el7_server_host =only_host_with_role(servers,'el7')
  el7_server = fact_on(el7_server_host, 'fqdn')
  el7_server_ip = fact_on(el7_server_host,%(ipaddress_#{get_private_network_interface(el7_server_host)}))

  context 'with exported home directories using stunnel' do
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
simp_nfs::mount::home::local_home: /mnt
      EOM

      if servers.include?(node)
        it 'should install nfs server' do
          # Construct server hieradata; export home directories.
          server_hieradata = hieradata_common + hieradata_extra + <<-EOM.gsub(/^\s+/,'')
            nfs::is_server: true
            simp_nfs::export_home::create_home_dirs: true
          EOM
          server_manifest = manifest + <<-EOM
            include 'simp_nfs::export::home'
            Class['simp::sssd::client'] ->  Class['simp_nfs::export::home']
          EOM
          ldap_server_manifest =  server_manifest + <<-EOM
            # Need to make sure ldap ports don't get removed.
            include simp::server::ldap
          EOM

          set_hieradata_on(node, server_hieradata, 'default')
          on(node, 'mkdir -p /usr/local/sbin/simp')
          if node == ldap_server
            apply_manifest_on(node, ldap_server_manifest, catch_failures: true)
            apply_manifest_on(node, ldap_server_manifest, catch_failures: true)
            apply_manifest_on(node, ldap_server_manifest, catch_changes: true)
          else
            apply_manifest_on(node, server_manifest, catch_failures: true)
            apply_manifest_on(node, server_manifest, catch_failures: true)
            apply_manifest_on(node, server_manifest, catch_changes: true)
          end

          # Ensure the cache is built, don't wait for enum timeout
          on(node, 'service sssd restart')

          user_info = on(node, 'id test.user', :acceptable_exit_codes => [0])
          expect(user_info.stdout).to match(/.*uid=10000\(test.user\).*gid=10000\(test.user\)/)
        end
      else
        it "should set up with stunnel #{node}" do
          client_hieradata = hieradata_common + hieradata_extra
          set_hieradata_on(node, client_hieradata, 'default')
          on(node, 'mkdir -p /usr/local/sbin/simp')
          apply_manifest_on(node, manifest, catch_failures: true)
          apply_manifest_on(node, manifest, catch_failures: true)
          apply_manifest_on(node, manifest, catch_changes: true)
          #  LDAP server should be set up and the client should be able
          #  to talk to it.
          on(node, 'service sssd restart')
          user_info = on(node, 'id test.user', :acceptable_exit_codes => [0])
          expect(user_info.stdout).to match(/.*uid=10000\(test.user\).*gid=10000\(test.user\)/)
        end
      end
    end

    it 'should create the test.user home directory mount on the servers using the cron job' do
      servers.each do |node|
        # Create test.user's homedir via cron, and ensure it gets mounted
        on(node, '/etc/cron.hourly/create_home_directories.rb')
        on(node, 'ls /var/nfs/home/test.user')
        on(node, "runuser -l test.user -c 'touch ~/testfile'")
        mount = on(node, "mount")
        expect(mount.stdout).to match(/127.0.0.1:\/home\/test.user.*nfs/)
      end
    end

    it 'should have file propagation to the clients' do
      clients.each do |node|
        retry_on(node, 'ls /mnt/test.user/testfile', acceptable_exit_codes: [0])
      end
    end
  end
end
