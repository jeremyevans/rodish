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

    # Helper method that takes an array of values, wraps them to the given
    # limit, and adds each line as a separator.  This is useful when you
    # have a large amount of information you want to display and you want
    # to wrap if for display to the user when showing options.
    def wrap(prefix, values, separator: " ", limit: 80)
      line = [prefix]
      lines = [line]
      prefix_length = length = prefix.length
      sep_length = separator.length
      indent = " " * prefix_length

      values.each do |value|
        value_length = value.length
        new_length = sep_length + length + value_length
        if new_length > limit
          line = [indent, separator, value]
          lines << line
          length = prefix_length
        else
          line << separator << value
        end
        length += sep_length + value_length
      end

      lines.each do |line|
        separator line.join
      end
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
