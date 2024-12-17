require 'spec_helper_acceptance'

test_name 'Set up ldap server '

describe 'simp_nfs stock classes' do
  stunnel_setting = true
  ldap_server = only_host_with_role(hosts, 'ldap')
  ldap_server_fqdn = fact_on(ldap_server, 'fqdn')

  _domains = fact_on(ldap_server, 'domain').split('.')
  _domains.map! do |d|
    "dc=#{d}"
  end
  domains = _domains.join(',')

  common_hieradata = File.read(File.expand_path('files/common_hieradata.yaml.erb', File.dirname(__FILE__)))

  context 'setup ldap server ' do
    let(:ldap_type)        { 'plain' }
    let(:server_hieradata) { File.read(File.expand_path("files/#{ldap_type}/server_hieradata.yaml.erb", File.dirname(__FILE__))) }
    let(:hieradata) { common_hieradata.to_s + "\n#{server_hieradata}" }

    test_user_ldif = <<-EOM
dn: cn=test.user,ou=Group,#{domains}
objectClass: posixGroup
objectClass: top
cn: test.user
gidNumber: 10000
description: 'Test user'

dn: cn=monster.user,ou=Group,#{domains}
objectClass: posixGroup
objectClass: top
cn: monster.user
gidNumber: 11000
description: 'Monster user'

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
loginShell: /bin/bash
uidNumber: 10000
gidNumber: 10000
homeDirectory: /mnt/test.user
# suP3rP@ssw0r!
userPassword: {SSHA}yOdnVOQYXOEc0Gjv4RRY5BnnFfIKLI3/
pwdReset: TRUE

dn: uid=monster.user,ou=People,#{domains}
uid: monster.user
cn: monster.user
givenName: monster
sn: User
mail: monster.user@funurl.net
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: top
objectClass: shadowAccount
objectClass: ldapPublicKey
shadowMax: 180
shadowMin: 1
shadowWarning: 7
shadowLastChange: 10701
loginShell: /bin/bash
uidNumber: 11000
gidNumber: 11000
homeDirectory: /mnt1/monster.user
# suP3rP@ssw0r!
userPassword: {SSHA}yOdnVOQYXOEc0Gjv4RRY5BnnFfIKLI3/
pwdReset: TRUE
    EOM

    test_group_ldif = <<-EOM
dn: cn=administrators,ou=Group,#{domains}
changetype: modify
add: memberUid
memberUid: test.user
memberUid: monster.user
    EOM

    it 'install,s openldap, and create test.user' do
      server_manifest = <<-EOM
        include 'simp_options'
        include 'pam::access'
        include 'sudo'
        include 'ssh'
        include 'simp::nsswitch'
        include 'simp_openldap::client'
        include 'simp::sssd::client'
        include 'simp::server::ldap'
      EOM

      # Apply
      set_hieradata_on(ldap_server, ERB.new(hieradata).result(binding), 'default')
      apply_manifest_on(ldap_server, server_manifest, catch_failures: true)
      apply_manifest_on(ldap_server, server_manifest, catch_failures: true)
      apply_manifest_on(ldap_server, server_manifest, catch_changes: true)

      # Create test.user
      create_remote_file(ldap_server, '/root/user_ldif.ldif', test_user_ldif)
      create_remote_file(ldap_server, '/root/group_ldif.ldif', test_group_ldif)

      # Create test.user and add to administrators
      on(ldap_server, "ldapadd -D cn=LDAPAdmin,ou=People,#{domains} -H ldap://#{ldap_server} -w suP3rP@ssw0r! -x -Z -f /root/user_ldif.ldif")
      on(ldap_server, "ldapmodify -D cn=LDAPAdmin,ou=People,#{domains} -H ldap://#{ldap_server} -w suP3rP@ssw0r! -x -Z -f /root/group_ldif.ldif")

      # Ensure the cache is built, don't wait for enum timeout
      on(ldap_server, 'service sssd restart')

      user_info = on(ldap_server, 'id test.user', acceptable_exit_codes: [0])
      expect(user_info.stdout).to match(%r{.*uid=10000\(test.user\).*gid=10000\(test.user\)})
      monster_info = on(ldap_server, 'id monster.user', acceptable_exit_codes: [0])
      expect(monster_info.stdout).to match(%r{.*uid=11000\(monster.user\).*gid=11000\(monster.user\)})
    end
  end
end
