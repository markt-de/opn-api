# frozen_string_literal: true

require_relative 'lib/opn_api/version'

Gem::Specification.new do |spec|
  spec.name          = 'opn_api'
  spec.version       = OpnApi::VERSION
  spec.license       = 'BSD-2-Clause'
  spec.authors       = ['markt-de']
  spec.email         = ['github-oss-noreply@markt.de']
  spec.homepage      = 'https://github.com/markt-de/opn-api'
  spec.summary       = 'Ruby client library and CLI for the OPNsense REST API'
  spec.description   = <<~DESC
    A standalone Ruby library and command-line tool for communicating with
    OPNsense firewalls via their REST API. Features include UUID resolution
    for ModelRelationField references, service reconfigure orchestration,
    and OPNsense selection-hash normalization.
  DESC

  spec.required_ruby_version = '>= 3.1'

  spec.files         = Dir['lib/**/*.rb', 'bin/*', 'LICENSE', 'README.md', 'CHANGELOG.md']
  spec.bindir        = 'bin'
  spec.executables   = ['opn-api']
  spec.require_paths = ['lib']

  # No runtime dependencies — only Ruby stdlib (net/http, json, yaml, openssl, optparse)

  spec.metadata['rubygems_mfa_required'] = 'true'
end
