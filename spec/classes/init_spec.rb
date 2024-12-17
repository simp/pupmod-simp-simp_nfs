require 'spec_helper'

describe 'simp_nfs' do
  shared_examples_for 'a structured module' do
    it { is_expected.to compile.with_all_deps }
    it { is_expected.to contain_class('simp_nfs') }
  end

  context 'supported operating systems' do
    on_supported_os.each do |os, os_facts|
      context "on #{os}" do
        let(:facts) do
          # to workaround service provider issues related to masking haveged
          # when tests are run on GitLab runners which are docker containers
          os_facts.merge({ haveged__rngd_enabled: false })
        end

        it_behaves_like 'a structured module'

        context 'when exporting home directories' do
          let(:params) do
            {
              export_home_dirs: true
            }
          end

          it_behaves_like 'a structured module'

          it { is_expected.to contain_class('nfs').with_is_server(true) }
          it { is_expected.to contain_class('simp_nfs::export::home') }
          it { is_expected.not_to contain_class('simp_nfs::mount::home') }
        end

        context 'when exporting and mounting home directories' do
          let(:params) do
            {
              export_home_dirs: true,
           home_dir_server: '1.2.3.4'
            }
          end

          it_behaves_like 'a structured module'

          it { is_expected.to contain_class('nfs').with_is_server(true) }
          it { is_expected.to contain_class('simp_nfs::export::home') }
          it { is_expected.to contain_class('simp_nfs::mount::home').with_nfs_server('127.0.0.1') }
        end

        context 'when mounting home directories' do
          let(:params) do
            {
              home_dir_server: '1.2.3.4'
            }
          end

          it_behaves_like 'a structured module'

          it { is_expected.to contain_class('nfs').with_is_server(false) }
          it { is_expected.not_to contain_class('simp_nfs::export::home') }
          it { is_expected.to contain_class('simp_nfs::mount::home').with_nfs_server('1.2.3.4') }

          it {
            is_expected.to contain_nfs__client__mount('/home').with_nfs_server('1.2.3.4')
            is_expected.to contain_nfs__client__mount('/home').with_autofs(true)
          }

          context 'without autofs' do
            let(:params) do
              {
                home_dir_server: '1.2.3.4',
             use_autofs: false
              }
            end

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
