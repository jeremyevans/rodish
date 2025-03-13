# frozen_string_literal: true

# Support showing allowed option values in help output.  The allowed
# options are wrapped.  The also allows for context-sensitive allowed
# options, where the allowed options may vary per-call.

require_relative "_context_sensitive_help"
require_relative "_wrap"

#
module Rodish
  module Plugins
    module HelpOptionValues
      def self.before_load(app)
        app.plugin(ContextSensitiveHelp_)
      end

      # Used to wrap context sensitive option values, when the allowed options
      # differ depending on the context.
      class ContextWrappedOptionValues < ContextSensitiveHelp_::ContextHelp
        def initialize(name, block)
          @name = name
          super(block)
        end

        # Get the allowed values using the provided context, then wrap the values.
        def call(context)
          Wrap_.wrap("    #{@name}", super)
        end
      end

      module DSLMethods
        # Add allowed option values to show in help output.
        def help_option_values(option_name, values=nil, &block)
          values ||= ContextWrappedOptionValues.new(option_name, block)
          (@command.help_option_values ||= {})[option_name] = values
        end
      end

      module CommandMethods
        # An hash with option name string keys, and keys that are either
        # arrays of strings or ContextWrappedOptionValues instances.
        attr_accessor :help_option_values

        private

        # Include option values after options.
        def default_help_order
          order = super
          index = order.index(:options) || -2
          order.insert(index+1, :option_values)
          order
        end

        # Include allowed options in the help output, if there are any
        # option values for this command.
        def _help_option_values(output)
          if help_option_values
            output << "Allowed Option Values:"
            help_option_values.each do |name, values|
              if values.is_a?(ContextWrappedOptionValues)
                output << values
              else
                output.concat(Wrap_.wrap("    #{name}", values))
              end
            end
            output << ""
          end
        end
      end
    end

    register(:help_option_values, HelpOptionValues)
  end
end
