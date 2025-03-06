# frozen_string_literal: true

require_relative "tsukuru/version"
require_relative "tsukuru/file_inspector"
require_relative "tsukuru/open_ai_client"

module Tsukuru
  class Error < StandardError; end
end
