require 'beaker-rspec'
require 'tmpdir'
require 'yaml'
require 'simp/beaker_helpers'
include Simp::BeakerHelpers

unless ENV['BEAKER_provision'] == 'no'
  hosts.each do |host|
    # Install Puppet
    if host.is_pe?
      install_pe
    else
      install_puppet
    end
  end
end


RSpec.configure do |c|
  # ensure that environment OS is ready on each host
  fix_errata_on hosts

  # Readable test descriptions
  c.formatter = :documentation

  # Configure all nodes in nodeset
  c.before :suite do
    begin
      # Install modules and dependencies from spec/fixtures/modules
      copy_fixture_modules_to( hosts )

      # Generate and install PKI certificates on each SUT
      Dir.mktmpdir do |cert_dir|
        run_fake_pki_ca_on( default, hosts, cert_dir )
        hosts.each{ |sut| copy_pki_to( sut, cert_dir, '/etc/pki/simp-testing' )}
      end
    rescue StandardError, ScriptError => e
      if ENV['PRY']
        require 'pry'; binding.pry
      else
        raise e
      end
    end
  end
end

def get_private_network_interface(host)
  interfaces = fact_on(host, 'interfaces').split(',')

  # remove interfaces we know are not the private network interface
  interfaces.delete_if do |ifc|
    ifc == 'lo' or
    ifc.include?('ip_') or # IPsec tunnel
    ifc == 'enp0s3' or     # public interface for puppetlabs/centos-7.2-64-nocm virtual box
    ifc == 'eth0'          # public interface for centos/7 virtual box
  end
  fail("Could not determine the interface for the #{host}'s private network") unless interfaces.size == 1
  interfaces[0]
end
