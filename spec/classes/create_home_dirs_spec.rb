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

        let(:params) {{
          :uri     => ["ldap://#{facts[:fqdn]}"],
          :base_dn => 'dn=foo,ou=bar',
          :bind_dn => 'dn=bind,ou=bar',
          :bind_pw => 'my_password'
        }}

        it_behaves_like "a structured module"
      end
    end
  end
end
