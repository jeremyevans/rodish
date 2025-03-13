# frozen_string_literal: true

# The cache_help caches help output when the command is frozen, so
# it is only calculated once.  This is useful if help output for
# the command does not depend on external state, and help for the
# command could be requested multiple times during program runtime.

#
module Rodish
  module Plugins
    module CacheHelpOutput
      module CommandMethods
        # Cache and help output when freezing the command.
        def freeze
          @help = help.freeze
          super
        end

        # Return cached help if it is present.
        def help
          @help || super
        end
      end
    end

    register(:cache_help_output, CacheHelpOutput)
  end
end
