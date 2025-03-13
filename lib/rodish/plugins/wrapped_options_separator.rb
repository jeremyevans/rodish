# frozen_string_literal: true

# The wrapped_options_separator plugin adds wrap to the option
# parser, which includes a separator with wrapped content.

require_relative "_wrap"

#
module Rodish
  module Plugins
    module WrappedOptionsSeparator
      module OptionParserMethods
        include Wrap_

        # Helper method that takes an array of values, wraps them to the given
        # limit, and adds each line as a separator.  This is useful when you
        # have a large amount of information you want to display and you want
        # to wrap if for display to the user when showing options.
        def wrap(prefix, values, separator: " ", limit: 80)
          super.each do |line|
            separator line
          end
        end
      end
    end

    register(:wrapped_options_separator, WrappedOptionsSeparator)
  end
end
