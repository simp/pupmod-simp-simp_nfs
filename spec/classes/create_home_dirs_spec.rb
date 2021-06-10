require 'spec_helper'

describe 'simp_nfs::create_home_dirs' do
  shared_examples_for "a structured module" do
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
          let(:params) {{
            :uri              => ["ldap://#{facts[:fqdn]}"],
            :base_dn          => 'dn=foo,ou=bar',
            :bind_dn          => 'dn=bind,ou=bar',
            :bind_pw          => 'my_password',
            :tls_cipher_suite => ['AES256','AES128']
          }}
          it_behaves_like "a structured module"
          if ['RedHat','CentOS'].include?(facts[:os][:name])
            it { is_expected.to create_file('/etc/cron.hourly/create_home_directories.rb').with_content(%r(ciphers_list = '.*256.*)) }
            it { is_expected.to create_file('/etc/cron.hourly/create_home_directories.rb').with_content(%r(ciphers_list = '.*128.*)) }
          end
        end
        context 'with multiple URIs' do
          let(:params) {{
            :uri              => ["ldap://#{facts[:fqdn]}","ldap://foo.bar.baz"],
            :base_dn          => 'dn=foo,ou=bar',
            :bind_dn          => 'dn=bind,ou=bar',
            :bind_pw          => 'my_password',
            :tls_cipher_suite => ['AES256','AES128']
          }}
          it_behaves_like "a structured module"
          it { is_expected.to create_file('/etc/cron.hourly/create_home_directories.rb').with_content(%r(servers =.*'#{facts[:fqdn]}', 'foo.bar.baz'.*)) }
        end
      end
    end
  end
end
