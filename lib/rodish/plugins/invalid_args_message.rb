# frozen_string_literal: true

# The invalid_args_message plugin allows for using a specific
# error message when an invalid number of arguments has been
# passed to a command.
#
# You can pass the invalid_args_message keyword argument to the
# following configuration methods:
#
# * args
# * is
# * run_is

#
module Rodish
  module Plugins
    module InvalidArgsMessage
      module DSLMethods
        # Support setting +invalid_args_message+ when calling +args+.
        def args(args, **kw)
          _set_invalid_args_message(kw) do
            super
            @command
          end
        end

        # Support setting +invalid_args_message+ when calling +is+.
        def is(command_name, **kw, &block)
          _set_invalid_args_message(kw) do
            super
          end
        end

        # Support setting +invalid_args_message+ when calling +run_is+.
        def run_is(command_name, **kw, &block)
          _set_invalid_args_message(kw) do
            super
          end
        end

        private

        # Remove invalid_args_message from keyword hash, yield to get
        # the command, then set the invalid_args_message on the command
        # if it was set.
        def _set_invalid_args_message(kw)
          message = kw.delete(:invalid_args_message)
          command = yield
          command.invalid_args_message = message if message
          command
        end
      end

      module CommandMethods
        # The error message to use if an invalid number of
        # arguments is provided.
        attr_accessor :invalid_args_message

        private

        # Use invalid_args_message if it has been set.
        def raise_invalid_args_failure(argv)
          if @invalid_args_message
            raise_failure("invalid arguments#{subcommand_name} (#{@invalid_args_message})")
          else
            super
          end
        end
      end
    end

    register(:invalid_args_message, InvalidArgsMessage)
  end
end
