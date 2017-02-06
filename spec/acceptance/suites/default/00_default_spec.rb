require 'spec_helper_acceptance'

test_name 'SIMP NFS profile'

describe 'simp_nfs stock classes' do
  servers = hosts_with_role( hosts, 'nfs_server' )
  clients = hosts_with_role( hosts, 'client' )
  let(:el7_server) { fact_on(only_host_with_role(servers, 'el7'), 'fqdn') }
  let(:el6_server) { fact_on(only_host_with_role(servers, 'el6'), 'fqdn') }

  let(:manifest) {
    <<-EOM
      hiera_include("classes")
    EOM
  }

  let(:hieradata) {
    <<-EOM
---
# Turn this off because we don't have a remote server
simp_options::rsync : false
simp_options::ldap : true
simp_options::sssd : true
simp_options::stunnel : true
simp_options::tcpwrappers : true
simp_options::firewall : true
simp_options::pki : true
simp_options::pki::source : '/etc/pki/simp-testing/pki'
simp_options::pki::private_key_source : "file://%{hiera('pki_dir')}/private/%{::fqdn}.pem"
simp_options::pki::public_key_source : "file://%{hiera('pki_dir')}/public/%{::fqdn}.pub"
simp_options::pki::cacerts_sources :
  - "file://%{hiera('pki_dir')}/cacerts"

simp_options::trusted_nets :
 - 'ALL'

simp_options::ldap::uri:
 - 'ldap://#{nfs_server}'
simp_options::ldap::base_dn: '#{domains}'
simp_options::ldap::bind_dn: 'cn=hostAuth,ou=Hosts,#{domains}'
simp_options::ldap::bind_pw: 'foobarbaz'
simp_options::ldap::bind_hash: '{SSHA}BNPDR0qqE6HyLTSlg13T0e/+yZnSgYQz'
simp_options::ldap::sync_dn: 'cn=LDAPSync,ou=Hosts,#{domains}'
simp_options::ldap::sync_pw: 'foobarbaz'
simp_options::ldap::sync_hash: '{SSHA}BNPDR0qqE6HyLTSlg13T0e/+yZnSgYQz'
simp_options::ldap::root_dn: 'cn=LDAPAdmin,ou=People,#{domains}'
simp_options::ldap::root_hash: '{SSHA}BNPDR0qqE6HyLTSlg13T0e/+yZnSgYQz'
simp_options::ldap::master: 'ldap://#{nfs_server}'
# suP3rP@ssw0r!
simp_options::ldap::root_hash: "{SSHA}ZcqPNbcqQhDNF5jYTLGl+KAGcrHNW9oo"

sssd::domains:
 - 'LDAP'

pam::wheel_group : 'administrators'

ssh::server::conf::permitrootlogin : true
ssh::server::conf::authorizedkeysfile : ".ssh/authorized_keys"

# Use fallback ciphers/macs to ensure ssh capability on any platform
ssh::server::conf::ciphers:
 - 'aes256-cbc'
 - 'aes192-cbc'
 - 'aes128-cbc'
ssh::server::conf::macs:
 - 'hmac-sha1'

# For testing
simp::is_mail_server : false

simp_nfs::home_dir_server : #{nfs_server}

classes :
  - "pam::access"
  - "pam::wheel"
  - "simp"
  - "simp::admin"
  - "simp_nfs"
  - "simp::nsswitch"
  - "ssh"
  - "tcpwrappers"
      EOM
  }

  let(:nfs_server) {
    os = fact_on(current_node, 'operatingsystem')
    if os == 'CentOS'
      os_release = fact_on(current_node, 'operatingsystemmajrelease')
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

    server
  }

  let(:domains) {
    _domains = fact_on(current_node, 'domain').split('.')
    _domains.map! { |d|
      "dc=#{d}"
    }

    _domains.join(',')
  }

  let(:test_user_ldif){
    <<-EOM
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
  }

  let(:test_group_ldif){
    <<-EOM
dn: cn=administrators,ou=Group,#{domains}
changetype: modify
add: memberUid
memberUid: test.user
    EOM
  }

  context 'with exported home directories' do
    hosts.each do |node|
      let(:current_node) { node }

      if servers.include?(node)
        it 'should install nfs, openldap, and create test.user' do
          # Construct server hieradata; export home directories.
          server_hieradata = hieradata + <<-EOM
nfs::is_server: true
simp_nfs::export_home::create_home_dirs: true
          EOM

          server_manifest = manifest + <<-EOM
            include 'simp_nfs::export::home'
            include 'simp::server::ldap'
          EOM

          # Apply
          set_hieradata_on(node, server_hieradata, 'default')
          on(node, ('mkdir -p /usr/local/sbin/simp'))
          apply_manifest_on(node, server_manifest, :catch_failures => true)

          # Create test.user
          on(node, "cat <<EOF > /root/user_ldif.ldif
#{test_user_ldif}
EOF")

          on(node, "cat <<EOF > /root/group_ldif.ldif
#{test_group_ldif}
EOF")

          # Create test.user and add to administrators
          on(node, "ldapadd -D cn=LDAPAdmin,ou=People,#{domains} -H ldap://#{nfs_server} -w suP3rP@ssw0r! -x -Z -f /root/user_ldif.ldif")
          on(node, "ldapmodify -D cn=LDAPAdmin,ou=People,#{domains} -H ldap://#{nfs_server} -w suP3rP@ssw0r! -x -Z -f /root/group_ldif.ldif")

          # Ensure the cache is built, don't wait for enum timeout
          on(node, "service sssd restart")

          user_info = on(node, "id test.user", :acceptable_exit_codes => [0])
          expect(user_info.stdout).to match(/.*uid=10000\(test.user\).*gid=10000\(test.user\)/)
        end
      else
        it "should set up #{node}" do
          set_hieradata_on(node, hieradata, 'default')
          on(node, ('mkdir -p /usr/local/sbin/simp'))
          apply_manifest_on(node, manifest, :catch_failures => true)
        end
      end
    end

    it 'should create the test.user home directory mount on the servers using the cron job' do
      servers.each do |node|
        # Create test.user's homedir via cron, and ensure it gets mounted
        on(node, "/etc/cron.hourly/create_home_directories.rb")
        on(node, 'ls /var/nfs/home/test.user')
        on(node, "runuser -l test.user -c 'touch ~/testfile'")
        mount = on(node, "mount")
        expect(mount.stdout).to match(/127.0.0.1:\/home\/test.user.*nfs/)
      end
    end

    it 'should have file propagation to the clients' do
      clients.each do |node|
        on(node, "ls /home/test.user/testfile", :acceptable_exit_codes => [0])
      end
    end
  end
end
