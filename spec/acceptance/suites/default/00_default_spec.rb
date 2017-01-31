require 'spec_helper_acceptance'

test_name 'SIMP NFS profile'

describe 'simp_nfs stock classes' do
  before(:context) do
    hosts.each do |host|
      interfaces = fact_on(host, 'interfaces').strip.split(',')
      interfaces.delete_if do |x|
        x =~ /^lo/
      end

      interfaces.each do |iface|
        if fact_on(host, "ipaddress_#{iface}").strip.empty?
          on(host, "ifup #{iface}", :accept_all_exit_codes => true)
        end
      end
    end
  end

  let(:servers) { hosts_with_role( hosts, 'nfs_server' ) }
  let(:clients) { hosts_with_role( hosts, 'client' ) }
  let(:el7_server) { fact_on(only_host_with_role(servers, 'el7'), 'fqdn') }
  let(:el6_server) { fact_on(only_host_with_role(servers, 'el6'), 'fqdn') }

  context 'with exported home directories' do

    it 'should install nfs, openldap, and create test.user' do

      # Determine appropriate server for each node
      [servers, clients].flatten.each do |node|
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

        # Construct common hieradata
        domains = fact_on(node, 'domain').split('.')
        domains.map! { |d|
          "dc=#{d}"
        }
        domains = domains.join(',')
        hieradata = <<-EOM
---
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
 - 'ldap://#{server}'
simp_options::ldap::base_dn: '#{domains}'
simp_options::ldap::bind_dn: 'cn=hostAuth,ou=Hosts,#{domains}'
simp_options::ldap::bind_pw: 'foobarbaz'
simp_options::ldap::bind_hash: '{SSHA}BNPDR0qqE6HyLTSlg13T0e/+yZnSgYQz'
simp_options::ldap::sync_dn: 'cn=LDAPSync,ou=Hosts,#{domains}'
simp_options::ldap::sync_pw: 'foobarbaz'
simp_options::ldap::sync_hash: '{SSHA}BNPDR0qqE6HyLTSlg13T0e/+yZnSgYQz'
simp_options::ldap::root_dn: 'cn=LDAPAdmin,ou=People,#{domains}'
simp_options::ldap::root_hash: '{SSHA}BNPDR0qqE6HyLTSlg13T0e/+yZnSgYQz'
simp_options::ldap::master: 'ldap://#{server}'
# suP3rP@ssw0r!
simp_options::ldap::root_hash: "{SSHA}ZcqPNbcqQhDNF5jYTLGl+KAGcrHNW9oo"

nfs::client::nfs_servers :
  "#{server}"

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

classes :
  - "nsswitch"
  - "pam::access"
  - "pam::wheel"
  - "simp"
  - "simp::admin"
  - "simp_nfs::mount::home"
  - "ssh"
  - "tcpwrappers"
        EOM

        # Construct server hieradata; export home directories.
        if servers.include?(node)
          hieradata << <<-EOM
nfs::is_server: true
simp_nfs::export_home::create_home_dirs: true
          EOM

          manifest = <<-EOM
            include 'simp_nfs::export::home'
            include 'simp::server::ldap'

            hiera_include('classes')
          EOM
        end

        # Apply
        set_hieradata_on(node, hieradata, 'default')
        on(node, ('mkdir -p /usr/local/sbin/simp'))
        apply_manifest_on(node, manifest, :catch_failures => true)

        # Create test.user
        if servers.include?(node)
          on(node, "cat <<EOF > /root/user_ldif.ldif
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
EOF")

          on(node, "cat <<EOF > /root/group_ldif.ldif
dn: cn=administrators,ou=Group,#{domains}
changetype: modify
add: memberUid
memberUid: test.user
EOF")


          # Create test.user and add to administrators
          on(node, "ldapadd -D cn=LDAPAdmin,ou=People,#{domains} -H ldap://#{server} -w suP3rP@ssw0r! -x -Z -f /root/user_ldif.ldif")
          on(node, "ldapmodify -D cn=LDAPAdmin,ou=People,#{domains} -H ldap://#{server} -w suP3rP@ssw0r! -x -Z -f /root/group_ldif.ldif")

          # Ensure the cache is built, don't wait for enum timeout
          on(node, "service sssd restart")

          user_info = on(node, "id test.user", :acceptable_exit_codes => [0])
          expect(user_info.stdout).to match(/.*uid=10000\(test.user\).*gid=10000\(test.user\)/)

          # Create test.user's homedir via cron, and ensure it gets mounted
          on(node, "/etc/cron.hourly/create_home_directories.rb")
          on(node, "runuser -l test.user -c 'touch ~/testfile'")
          mount = on(node, "mount")
          expect(mount.stdout).to match(/127.0.0.1:\/home\/test.user.*nfs/)
        end
      end
    end

    it 'should have file propagation to the clients' do
      clients.each do |node|
        on(node, "ls /home/test.user/testfile", :acceptable_exit_codes => [0])
      end
    end
  end
end
