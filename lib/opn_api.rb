# frozen_string_literal: true

require_relative 'opn_api/version'
require_relative 'opn_api/errors'
require_relative 'opn_api/logger'
require_relative 'opn_api/client'
require_relative 'opn_api/config'
require_relative 'opn_api/normalize'
require_relative 'opn_api/id_resolver'
require_relative 'opn_api/service_reconfigure'
require_relative 'opn_api/resource'
require_relative 'opn_api/resource_registry'

# Ruby client library for the OPNsense REST API.
#
# Provides HTTP client, UUID resolution, service reconfigure orchestration,
# and OPNsense selection-hash normalization. Usable as a library or via
# the opn-api CLI.
module OpnApi
  class << self
    # Returns the module-level logger instance.
    # @return [OpnApi::Logger]
    def logger
      @logger ||= OpnApi::Logger.new
    end

    # Sets a custom logger (e.g. for Puppet integration).
    # Any object responding to #debug, #info, #notice, #warning, #error.
    # @param logger [#debug, #info, #notice, #warning, #error]
    attr_writer :logger
  end
end
