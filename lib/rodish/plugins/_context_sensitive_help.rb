# frozen_string_literal: true

# _context_sensitive_help is an internal plugin to implement context
# sensitive help output.

#
module Rodish
  module Plugins
    module ContextSensitiveHelp_
      # Object that wraps a block, which is instance execed in the provided
      # context when called.
      class ContextHelp
        def initialize(block)
          @block = block
        end

        def call(context)
          context.instance_exec(&@block)
        end
      end

      module CommandMethods
        # Render help with context-sensitive information.
        def context_help(context)
          lines = help_lines(include_context_help: true)
          lines.map! do |line|
            if line.is_a?(ContextHelp)
              line.call(context)
            else
              line
            end
          end
          lines.flatten!
          lines.join("\n")
        end

        # Exclude ContextHelp lines unless they are explicitly requested.
        def help_lines(include_context_help: false)
          lines = super()
          lines.reject!{|l| l.is_a?(ContextHelp)} unless include_context_help
          lines
        end
      end
    end
  end
end
