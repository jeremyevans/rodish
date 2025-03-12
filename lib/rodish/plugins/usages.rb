# frozen_string_literal: true

# The usages plugin adds the #usages method to the Rodish processor.
# This returns a hash for the command help for all commands and subcommands
# of the processor.

#
module Rodish
  module Plugins
    module Usages
      module ProcessorMethods
        # Return a hash of usage strings for the root command and all subcommands,
        # recursively.  The hash has string keys for the command name, and
        # string values for the help for the command.
        def usages
          usages = {}

          command.each_subcommand do |names, command|
            usages[names.join(" ")] = command.help
          end

          usages
        end
      end
    end

    register(:usages, Usages)
  end
end
