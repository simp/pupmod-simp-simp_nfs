require 'spec_helper_acceptance'

test_name 'SIMP NFS profile'

describe 'simp_nfs stock classes' do
  servers = hosts_with_role( hosts, 'nfs_server' )
  clients = hosts_with_role( hosts, 'client' )
  el7_server = fact_on(only_host_with_role(servers, 'el7'), 'fqdn')
  el6_server = fact_on(only_host_with_role(servers, 'el6'), 'fqdn')

  context 'with exported home directories' do
    hosts.each do |node|

      # Determine who your nfs server is
      os = fact_on(node, 'operatingsystem')
      if os == 'CentOS'
        os_release = fact_on(node, 'operatingsystemmajrelease')
        if os_release == '6'
          server = el6_server
        elsif os_release == '7'
          server = el7_server
        else
          STDERR.puts "#{os_release} not a supported OS release"
          next
        end
      else
        STDERR.puts "OS #{os} not supported"
        next
      end
      nfs_server = server

      # Determine what your domain is, in dn form
      _domains = fact_on(node, 'domain').split('.')
      _domains.map! { |d|
        "dc=#{d}"
      }
      domains = _domains.join(',')

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

      hieradata = <<-EOM
---

simp_nfs::home_dir_server: #{nfs_server}
nfs::client::stunnel::nfs_server: #{nfs_server}

# Options
# Use fallback ciphers/macs to ensure ssh capability on any platform
ssh::server::conf::ciphers:
- 'aes256-cbc'
- 'aes192-cbc'
- 'aes128-cbc'
ssh::server::conf::macs:
- 'hmac-sha1'
simp_options::clamav: false
simp_options::dns::servers: ['8.8.8.8']
simp_options::puppet::server: #{server}
simp_options::puppet::ca: #{server}
simp::yum::servers: ['#{server}']
simp_options::ntpd::servers: ['time.nist.gov']
simp_options::sssd: true
simp_options::stunnel: true
simp_options::tcpwrappers: true
simp_options::pam: true
simp_options::firewall: true
simp_options::pki: true
simp_options::pki::source: '/etc/pki/simp-testing/pki'
simp_options::trusted_nets: ['ALL']
simp_options::ldap: true
simp_options::ldap::bind_pw: 'foobarbaz'
simp_options::ldap::bind_hash: '{SSHA}BNPDR0qqE6HyLTSlg13T0e/+yZnSgYQz'
simp_options::ldap::sync_pw: 'foobarbaz'
simp_options::ldap::sync_hash: '{SSHA}BNPDR0qqE6HyLTSlg13T0e/+yZnSgYQz'
# simp_openldap::server::conf::rootpw: '{SSHA}BNPDR0qqE6HyLTSlg13T0e/+yZnSgYQz'
# suP3rP@ssw0r!
simp_openldap::server::conf::rootpw: "{SSHA}ZcqPNbcqQhDNF5jYTLGl+KAGcrHNW9oo"
sssd::domains:
  - LDAP
simp::is_mail_server: false
pam::wheel_group: 'administrators'

# Settings to make beaker happy
pam::access::users:
  defaults:
    origins:
      - ALL
    permission: '+'
  vagrant:
sudo::user_specifications:
  vagrant_all:
    user_list: ['vagrant']
    cmnd: ['ALL']
    passwd: false
ssh::server::conf::permitrootlogin: true
ssh::server::conf::authorizedkeysfile: .ssh/authorized_keys
      EOM

      test_user_ldif = <<-EOM
dn: cn=test.user,ou=Group,#{domains}
objectClass: posixGroup
objectClass: top
cn: test.user
gidNumber: 10000
description: 'Test user'

dn: uid=test.user,ou=People,#{domains}
uid: test.user
cn: test.user
givenName: Test
sn: User
mail: test.user@funurl.net
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: top
objectClass: shadowAccount
objectClass: ldapPublicKey
shadowMax: 180
shadowMin: 1
shadowWarning: 7
shadowLastChange: 10701
sshPublicKey:
loginShell: /bin/bash
uidNumber: 10000
gidNumber: 10000
homeDirectory: /home/test.user
#suP3rP@ssw0r!
userPassword: {SSHA}r2GaizHFWY8pcHpIClU0ye7vsO4uHv/y
pwdReset: TRUE
      EOM

      test_group_ldif = <<-EOM
dn: cn=administrators,ou=Group,#{domains}
changetype: modify
add: memberUid
memberUid: test.user
      EOM

      if servers.include?(node)
        it 'should install nfs, openldap, and create test.user' do
          # Construct server hieradata; export home directories.
          server_hieradata = hieradata + <<-EOM.gsub(/^\s+/,'')
            nfs::is_server: true
            simp_nfs::export_home::create_home_dirs: true
          EOM

          server_manifest = manifest + <<-EOM
            include 'simp_nfs::export::home'
            include 'simp::server::ldap'
          EOM

          # Apply
          set_hieradata_on(node, server_hieradata, 'default')
          on(node, 'mkdir -p /usr/local/sbin/simp')
          apply_manifest_on(node, server_manifest, :catch_failures => true)
          apply_manifest_on(node, server_manifest, :catch_failures => true)

          # Create test.user
          create_remote_file(node, '/root/user_ldif.ldif', test_user_ldif)
          create_remote_file(node, '/root/group_ldif.ldif', test_group_ldif)

          # Create test.user and add to administrators
          on(node, "ldapadd -D cn=LDAPAdmin,ou=People,#{domains} -H ldap://#{nfs_server} -w suP3rP@ssw0r! -x -Z -f /root/user_ldif.ldif")
          on(node, "ldapmodify -D cn=LDAPAdmin,ou=People,#{domains} -H ldap://#{nfs_server} -w suP3rP@ssw0r! -x -Z -f /root/group_ldif.ldif")

          # Ensure the cache is built, don't wait for enum timeout
          require 'pry';binding.pry
          on(node, 'service sssd restart')

          user_info = on(node, 'id test.user', :acceptable_exit_codes => [0])
          expect(user_info.stdout).to match(/.*uid=10000\(test.user\).*gid=10000\(test.user\)/)
        end
      else
        it "should set up #{node}" do
          set_hieradata_on(node, hieradata, 'default')
          on(node, 'mkdir -p /usr/local/sbin/simp')
          apply_manifest_on(node, manifest, :catch_failures => true)
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
        on(node, 'ls /home/test.user/testfile', :acceptable_exit_codes => [0])
      end
    end
  end
end
