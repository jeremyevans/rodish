# frozen_string_literal: true

# _wrap is an an internal plugin module used by other plugins.

#
module Rodish
  module Plugins
    module Wrap_
      module_function

      # Return an array of strings, each no longer than limit,
      # showing the prefix and all values.
      def wrap(prefix, values, separator: " ", limit: 80)
        line = [prefix]
        lines = [line]
        prefix_length = length = prefix.length
        sep_length = separator.length
        indent = " " * prefix_length

        values.each do |value|
          value = value.to_s
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

        lines.map{|l| l.join}
      end
    end
  end
end
