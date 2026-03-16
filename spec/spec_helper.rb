# frozen_string_literal: true

require 'opn_api'
require 'webmock/rspec'

# Disable external connections in tests
WebMock.disable_net_connect!

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.order = :random
  Kernel.srand config.seed

  # Reset shared state between tests
  config.after do
    OpnApi::IdResolver.reset!
    OpnApi::ServiceReconfigure.reset!
  end
end
