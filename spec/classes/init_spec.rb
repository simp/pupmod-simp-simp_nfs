require 'spec_helper'

describe 'simp_nfs' do
  shared_examples_for "a structured module" do
    it { is_expected.to compile.with_all_deps }
    it { is_expected.to contain_class('simp_nfs') }
  end

  context 'supported operating systems' do
    on_supported_os.each do |os, facts|
      context "on #{os}" do
        let(:facts) do
          facts
        end

        it_behaves_like "a structured module"

        context 'when exporting home directories' do
          let(:params) {{
            :export_home_dirs => true
          }}

          it_behaves_like "a structured module"

          it { is_expected.to contain_class('nfs').with_is_server(true) }
          it { is_expected.to contain_class('simp_nfs::export::home') }
          it { is_expected.to_not contain_class('simp_nfs::mount::home') }
        end

        context 'when exporting and mounting home directories' do
          let(:params) {{
            :export_home_dirs => true,
            :home_dir_server  => '1.2.3.4' 
          }}

          it_behaves_like "a structured module"

          it { is_expected.to contain_class('nfs').with_is_server(true) }
          it { is_expected.to contain_class('simp_nfs::export::home') }
          it { is_expected.to contain_class('simp_nfs::mount::home').with_nfs_server('127.0.0.1') }
        end

        context 'when mounting home directories' do
          let(:params) {{
            :home_dir_server => '1.2.3.4'
          }}

          it_behaves_like "a structured module"

          it { is_expected.to contain_class('nfs').with_is_server(false) }
          it { is_expected.to_not contain_class('simp_nfs::export::home') }
          it { is_expected.to contain_class('simp_nfs::mount::home').with_nfs_server('1.2.3.4') }

          it {
            is_expected.to contain_nfs__client__mount('/home').with_nfs_server('1.2.3.4')
            is_expected.to contain_nfs__client__mount('/home').with_autofs(true)
          }

          context 'without autofs' do
            let(:params) {{
              :home_dir_server => '1.2.3.4',
              :use_autofs     => false
            }}

            it {
              is_expected.to contain_nfs__client__mount('/home').with_nfs_server('1.2.3.4')
              is_expected.to contain_nfs__client__mount('/home').with_autofs(false)
            }
          end
        end
      end
    end
  end
end
