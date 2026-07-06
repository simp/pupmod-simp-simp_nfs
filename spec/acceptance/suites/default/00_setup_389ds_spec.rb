require 'spec_helper_acceptance'

test_name 'Set up ds389 server '

describe 'simp_nfs stock classes' do
  # stunnel just needs to be set, it does not effect this test
  let(:stunnel_setting) { true }
  let(:ldap_server) { only_host_with_role(hosts, '389ds') }
  let(:ldap_server_fqdn) { fact_on(ldap_server, 'fqdn') }

  let(:domain_list) do
    list = fact_on(ldap_server, 'domain').split('.')
    list.map! do |d|
      "dc=#{d}"
    end
  end
  let(:domains) { domain_list.join(',') }
  let(:common_hieradata) { File.read(File.expand_path('files/common_hieradata.yaml.erb', File.dirname(__FILE__))) }

  context 'setup 389ds ldap server ' do
    # rubocop:disable RSpec/IndexedLet
    let(:test_user1)       { 'test.user' }
    let(:test_user2)       { 'monster.user' }
    # rubocop:enable RSpec/IndexedLet
    let(:root_pw)          { 'suP3rP@ssw0r!' }
    let(:ldap_type)        { '389ds' }
    let(:server_hieradata) { File.read(File.expand_path("files/#{ldap_type}/server_hieradata.yaml.erb", File.dirname(__FILE__))) }
    let(:hieradata)        { common_hieradata.to_s + "\n#{server_hieradata}" }
    let(:add_testuser)     { File.read(File.expand_path("files/#{ldap_type}/add_testuser.erb", File.dirname(__FILE__))) }
    let(:ds_root_name)     { 'accounts' }

    it 'install,s 389ds accounts instance' do
      server_manifest = <<~EOM
        include 'simp_options'
        include 'pam::access'
        include 'sudo'
        include 'ssh'
        include 'simp::nsswitch'
        include 'simp_ds389::instances::accounts'
        include 'simp_openldap::client'
        include 'simp::sssd::client'
      EOM

      # Apply
      set_hieradata_on(ldap_server, ERB.new(hieradata).result(binding), 'default')
      apply_manifest_on(ldap_server, server_manifest, catch_failures: true)
      apply_manifest_on(ldap_server, server_manifest, catch_failures: true)
      apply_manifest_on(ldap_server, server_manifest, catch_changes: true)
    end

    # Create test.user
    it 'adds the test users' do
      create_remote_file(ldap_server, '/root/ldap_add_user', ERB.new(add_testuser).result(binding))
      on(ldap_server, 'chmod +x /root/ldap_add_user')
      on(ldap_server, '/root/ldap_add_user')
      result = on(ldap_server, "dsidm #{ds_root_name} -b #{domains} user list")
      expect(result.stdout).to include('test.user')
      expect(result.stdout).to include('monster.user')
    end

    it 'is able to get user info through sssd' do
      # WORKAROUND (simp/pupmod-simp-sssd#212): on EL10 sssd runs as the
      # unprivileged 'sssd' user, but sssd::pki's pki::copy writes the client
      # cert tree root-owned, so the daemon cannot read its key and StartTLS
      # fails ("Backend is offline"). Grant the sssd group access until the
      # sssd module makes the pki::copy group configurable. No-op on EL8/9
      # where sssd runs as root.
      on(ldap_server, 'chgrp -R sssd /etc/pki/simp_apps/sssd && chmod -R g+rX /etc/pki/simp_apps/sssd', accept_all_exit_codes: true)

      on(ldap_server, 'systemctl restart sssd')

      user_info = on(ldap_server, "id #{test_user1}", acceptable_exit_codes: [0])
      expect(user_info.stdout).to match(%r{.*uid=10000\(#{test_user1}\).*gid=10000\(#{test_user1}\)})
      monster_info = on(ldap_server, "id #{test_user2}", acceptable_exit_codes: [0])
      expect(monster_info.stdout).to match(%r{.*uid=11000\(#{test_user2}\).*gid=11000\(#{test_user2}\)})
    end
  end
end
