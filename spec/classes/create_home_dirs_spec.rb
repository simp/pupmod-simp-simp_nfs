require 'spec_helper'

describe 'simp_nfs::create_home_dirs' do
  shared_examples_for 'a structured module' do
    it { is_expected.to compile.with_all_deps }
    it { is_expected.to contain_class('simp_nfs::create_home_dirs') }
  end

  context 'supported operating systems' do
    on_supported_os.each do |os, facts|
      context "on #{os}" do
        let(:facts) do
          facts
        end

        context 'with one URI' do
          let(:params) do
            {
              uri: ["ldap://#{facts[:fqdn]}"],
           base_dn: 'dn=foo,ou=bar',
           bind_dn: 'dn=bind,ou=bar',
           bind_pw: 'my_password',
           tls_cipher_suite: ['AES256', 'AES128']
            }
          end

          it_behaves_like 'a structured module'
          if ['RedHat', 'CentOS'].include?(facts[:os][:name])
            it { is_expected.to create_file('/usr/local/bin/create_home_directories.rb').with_content(%r{ciphers_list = '.*256.*}) }
            it { is_expected.to create_file('/usr/local/bin/create_home_directories.rb').with_content(%r{ciphers_list = '.*128.*}) }
            it { is_expected.to create_file('/usr/local/bin/create_home_directories.rb').with_content(%r{pw = 'my_password'}) }
            it { is_expected.to create_file('/usr/local/bin/create_home_directories.rb').with_content(%r{dn = 'dn=bind,ou=bar'}) }
            it { is_expected.to create_file('/usr/local/bin/create_home_directories.rb').with_content(%r{userou = 'ou=People,dn=foo,ou=bar'}) }
          end
          it {
            is_expected.to create_systemd__timer('nfs_create_home_dirs.timer')
              .with_timer_content(%r{OnCalendar=\*-\*-\* \*:30:00})
              .with_service_content(%r{ExecStart=/usr/local/bin/create_home_directories.rb})
              .with_service_content(%r{SuccessExitStatus=0})
              .that_requires('File[/usr/local/bin/create_home_directories.rb]')
          }
        end
        context 'with multiple URIs' do
          let(:params) do
            {
              uri: ["ldap://#{facts[:fqdn]}", 'ldap://foo.bar.baz'],
           base_dn: 'dn=foo,ou=bar',
           bind_dn: 'dn=bind,ou=bar',
           bind_pw: 'my_password',
           tls_cipher_suite: ['AES256', 'AES128']
            }
          end

          it_behaves_like 'a structured module'
          it { is_expected.to create_file('/usr/local/bin/create_home_directories.rb').with_content(%r{servers =.*'#{facts[:fqdn]}', 'foo.bar.baz'.*}) }
        end
        context 'with pki settings' do
          let(:params) do
            {
              uri: ["ldap://#{facts[:fqdn]}"],
           base_dn: 'dn=foo,ou=bar',
           bind_dn: 'dn=bind,ou=bar',
           bind_pw: 'my_password',
           pki: 'simp',
           tls_cipher_suite: ['AES256', 'AES128']
            }
          end

          it_behaves_like 'a structured module'
          it { is_expected.to create_pki__copy('nfs_home_server') }
          it { is_expected.to create_file('/usr/local/bin/create_home_directories.rb').with_content(%r{ca_path = '/etc/pki/simp_apps/nfs_home_server/x509/cacerts'}) }
          it { is_expected.to create_file('/usr/local/bin/create_home_directories.rb').with_content(%r{cert_file = '/etc/pki/simp_apps/nfs_home_server/x509/public/#{facts[:fqdn]}.pub'}) }
          it { is_expected.to create_file('/usr/local/bin/create_home_directories.rb').with_content(%r{key_file = '/etc/pki/simp_apps/nfs_home_server/x509/private/#{facts[:fqdn]}.pem'}) }
        end
      end
    end
  end
end
