# frozen_string_literal: true

require "invoance"
require "webmock/rspec"

RSpec.configure do |config|
  config.expect_with(:rspec) { |c| c.syntax = :expect }
  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed
end

# Disable all real network connections in tests.
WebMock.disable_net_connect!
