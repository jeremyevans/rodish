# frozen_string_literal: true

# The is plugin adds an +is+ method as a shortcut for calling the +on+ method
# and +run+ method.
#
# For example:
# 
#   is "hello" do
#     :world
#   end
#   
# is equivalent to:
# 
#   on "hello" do
#     run do
#       :world
#     end
#   end
# 
# The +is+ method also takes +args+ keyword arguments to specify the number
# of arguments.
#
# This does not allow you to set a command description or usage, so it is
# not recommended in new code.

#
module Rodish
  module Plugins
    module Is
      module DSLMethods
        # A shortcut for calling +on+ and +run+.
        #
        #   is "hello" do
        #     :world
        #   end
        #  
        # is equivalent to:
        #
        #   on "hello" do
        #     run do
        #       :world
        #     end
        #   end
        #
        # The +args+ argument sets the number of arguments supported by
        # the command.
        def is(command_name, args: 0, &block)
          _is(:on, command_name, args:, &block)
        end

        private

        # Internals of +is+.
        def _is(meth, command_name, args:, &block)
          public_send(meth, command_name) do
            args(args)
            run(&block)
          end
        end
      end
    end

    register(:is, Is)
  end
end
