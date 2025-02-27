# frozen_string_literal: true

module Rodish
  # Rodish::SkipOptionParser is used when option parsing should be
  # skipped, treating all entries in argv as arguments.
  class SkipOptionParser
    # A usage banner to use for the related command.
    attr_reader :banner

    # The same as banner, but ending in a newline, similarly
    # to how OptionParser#to_s works.
    attr_reader :to_s

    def initialize(banner)
      @banner = "Usage: #{banner}".freeze
      @to_s = (@banner + "\n").freeze
    end
  end
end
