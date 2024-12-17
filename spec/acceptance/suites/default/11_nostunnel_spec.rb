require 'spec_helper_acceptance'

test_name 'SIMP NFS profile'

describe 'simp_nfs stock classes without stunnel' do
  stunnel_setting = false
  root_pw = 'suP3rP@ssw0r!'
  servers = hosts_with_role(hosts, 'nfs_server')
  clients = hosts_with_role(hosts, 'client')
  manifest = <<~EOM
    include 'simp_options'
    include 'pam::access'
    include 'sudo'
    include 'ssh'
    include 'simp::nsswitch'
    include 'simp_openldap::client'
    include 'simp::sssd::client'
    include 'simp_nfs'
    file {  '/mnt1':
       ensure => 'directory',
       owner  => 'root',
       group => 'root',
       mode => '0755',
       before => Class['simp_nfs']
    }
    # let vagrant get back in
    simp_firewalld::rule { 'allow_all_ssh':
      trusted_nets => ['all'],
      protocol     => tcp,
      dports       => 22
    }
    EOM
  nfsserver_hieradata = <<~EOM
    nfs::is_server: true
    simp_nfs::export_home::create_home_dirs: true
    EOM
  nfsserver_manifest = <<~EOM
    include 'simp_nfs::export::home'
    Class['simp::sssd::client'] ->  Class['simp_nfs::export::home']
    EOM
  clear_sssd_cache = <<~EOM
    #!/bin/bash
    if [ -f /var/lib/sss/db/cache_LDAP.ldb ]; then
      rm -f /var/lib/sss/db/cache_LDAP.ldb
    fi
    systemctl restart sssd
    EOM

  ['389ds', 'plain'].each do |ldaptype|
    context "using ldap server type #{ldaptype} with no stunnel" do
      let(:ldap_type) { ldaptype }
      let(:ldap_server_fqdn) { fact_on(ldap_server, 'fqdn') }
      let(:_domains) do
        fact_on(ldap_server, 'domain').split('.')
        _domains.map! do |d|
          "dc=#{d}"
        end
      end
      let(:domains) { _domains.join(',') }
      let(:common_hieradata) { File.read(File.expand_path('files/common_hieradata.yaml.erb', File.dirname(__FILE__))) }
      let(:ldap_server_hieradata) { File.read(File.expand_path("files/#{ldap_type}/server_hieradata.yaml.erb", File.dirname(__FILE__))) }

      if ldaptype == '389ds'
        let(:ldap_server) { only_host_with_role(hosts, '389ds') }
        let(:ldap_manifest) do
          <<-EOM
            include 'simp_ds389::instances::accounts'
          EOM
        end
      else
        let(:ldap_server) { only_host_with_role(hosts, 'ldap') }
        let(:ldap_manifest) do
          <<-EOM
            include 'simp::server::ldap'
          EOM
        end
      end

      it 'installs ldap server' do
        # This server may have just been an NFS server in a previous test.
        # We need run puppet again with the ldap manifest to make sure
        # the firewall is configured correctly.
        ldap_server_manifest = [manifest, ldap_manifest].join("\n")

        set_hieradata_on(ldap_server, ERB.new(common_hieradata + ldap_server_hieradata).result(binding))
        apply_manifest_on(ldap_server, ldap_server_manifest, catch_failures: true)
        apply_manifest_on(ldap_server, ldap_server_manifest, catch_failures: true)
        apply_manifest_on(ldap_server, ldap_server_manifest, catch_changes: true)
      end

      # Ensure the cache is built, don't wait for enum timeout

      servers.each do |server|
        context "On #{server} with #{ldaptype} ldap server export home directories wthout stunnel" do
          let(:nfs_server) { server }
          let(:nfs_server_ip) { fact_on(nfs_server, %(ipaddress_#{get_private_network_interface(nfs_server)})) }

          let(:hieradata_extra) do
            <<~EOM
             simp_nfs::home_dir_server: #{nfs_server_ip}
             nfs::client::stunnel::nfs_server: #{nfs_server}
             simp_nfs::mount::home::local_home: '/mnt1'
             EOM
          end

          let(:server_hieradata) { [common_hieradata, ldap_server_hieradata, hieradata_extra, nfsserver_hieradata].join("\n") }

          it 'clears the sssd cache' do
            # since we are switching around ldap servers make sure the
            # sssd cache is clear.  It might have users from
            # the previous ldap server
            create_remote_file(nfs_server, '/root/clear_sssd_cache.sh', clear_sssd_cache)
            on(nfs_server, 'chmod +x /root/clear_sssd_cache.sh')
            on(nfs_server, '/root/clear_sssd_cache.sh')
          end

          it 'installs nfs server' do
            server_manifest = if server == ldap_server
                                # Don't want to disable the firewall for the ldap server
                                [manifest, nfsserver_manifest, ldap_manifest].join("\n")
                              else
                                [manifest, nfsserver_manifest].join("\n")
                              end

            set_hieradata_on(nfs_server, ERB.new(server_hieradata).result(binding))
            apply_manifest_on(nfs_server, server_manifest, catch_failures: true)
            apply_manifest_on(nfs_server, server_manifest, catch_failures: true)
            apply_manifest_on(nfs_server, server_manifest, catch_changes: true)
          end

          # Ensure the cache is built, don't wait for enum timeout
          it 'sees the monster user' do
            user_info = on(nfs_server, 'id monster.user', acceptable_exit_codes: [0])
            expect(user_info.stdout).to match(%r{.*uid=11000\(monster.user\).*gid=11000\(monster.user\)})
          end

          it ' should create home dirs and export them' do
            # Create test.user's homedir via cron, and ensure it gets mounted
            on(nfs_server, '/usr/local/bin/create_home_directories.rb')
            on(nfs_server, 'ls /var/nfs/home/monster.user')
            on(nfs_server, "runuser -l monster.user -c 'touch ~/monstertestfile'")
            mount = on(nfs_server, 'mount')
            expect(mount.stdout).to match(%r{127.0.0.1:/home/monster.user.*nfs})
          end

          clients.each do |client|
            context "On #{client} using #{server} as nfs and #{ldaptype} ldap server without stunnel" do
              let(:client_hieradata) { [common_hieradata, hieradata_extra].join("\n") }

              it 'cleans up from any previous tests' do
                create_remote_file(client, '/root/clear_sssd_cache.sh', clear_sssd_cache)
                on(client, 'chmod +x /root/clear_sssd_cache.sh')
                on(client, '/root/clear_sssd_cache.sh', accept_all_exit_codes: true)
                on(client, 'umount -f /mnt1/monster.user', accept_all_exit_codes: true)
              end

              it "sets without stunnel #{client}" do
                set_hieradata_on(client, ERB.new(client_hieradata).result(binding))
                apply_manifest_on(client, manifest, catch_failures: true)
                apply_manifest_on(client, manifest, catch_failures: true)
                apply_manifest_on(client, manifest, catch_changes: true)
              end

              it 'sees the monster user' do
                user_info = on(client, 'id monster.user', acceptable_exit_codes: [0])
                expect(user_info.stdout).to match(%r{.*uid=11000\(monster.user\).*gid=11000\(monster.user\)})
              end

              it 'sees the file created on the server' do
                retry_on(client, 'ls /mnt1/monster.user/monstertestfile', acceptable_exit_codes: [0])
                # should be able to create new file
                on(client, "runuser -l monster.user -c 'touch ~/difftestfile'")
              end

              it 'removes mount to next test has no problems' do
                on(client, 'umount -f /mnt1/monster.user')
              end
              # End client context
            end
          end
          # End server context
        end
      end
      # End Ldap server context
    end
  end
  # End it all
end
