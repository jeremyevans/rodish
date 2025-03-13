# frozen_string_literal: true

# The run_is plugin adds a +run_is+ method that is similar to +is+,
# but adds a post subcommand instead of a regular subcommand.
#
# This does not allow you to set a command description or usage, so it is
# not recommended in new code.
#
# This plugin depends on the is and post_commands plugins.

#
module Rodish
  module Plugins
    module RunIs
      def self.before_load(app)
        app.plugin :is
        app.plugin :post_commands
      end

      module DSLMethods
        # Similar to +is+, but for post subcommands instead of normal
        # subcommands.
        def run_is(command_name, args: 0, &block)
          _is(:run_on, command_name, args:, &block)
        end
      end
    end

    register(:run_is, RunIs)
  end
end

