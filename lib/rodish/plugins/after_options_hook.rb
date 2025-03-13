# frozen_string_literal: true

# The after_options_hook plugin supports an after_options configuration
# method, specifying a block to execute in context after parsing options,
# before executing the command or any subcommands.  It is passed the remaining
# argv and already parsed options:
#
#   after_options do |argv, options|
#     # ...
#   end

#
module Rodish
  module Plugins
    module AfterOptionsHook
      module DSLMethods
        # Sets the after_options block.  This block is executed in the same
        # context as the run block would be executed, directly after
        # option parsing.
        def after_options(&block)
          @command.after_options = block
        end
      end

      module CommandMethods
        # A hook to execute after parsing options for the command.
        attr_accessor :after_options

        # Run after_options hook if present after parsing options.
        def process_command_options(context, options, argv)
          super
          context.instance_exec(argv, options, &after_options) if after_options
        end
      end
    end

    register(:after_options_hook, AfterOptionsHook)
  end
end
