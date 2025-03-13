# frozen_string_literal: true

require "optparse"
require_relative "errors"

module Rodish
  # Rodish::OptionPaser is a subclass of Ruby's standard OptionParser
  # (from the optparse library).
  class OptionParser < ::OptionParser
    # Don't add officious, which includes options that call exit.
    # With Rodish, there are no secret options, only options you define.
    def add_officious
    end

    # Halt processing with a CommandExit using the given string.
    # This can be used to implement early exits, by calling this
    # method in a block:
    #
    #   on("--version", "show program version") { halt VERSION }
    def halt(string)
      raise CommandExit, string
    end
  end
end
