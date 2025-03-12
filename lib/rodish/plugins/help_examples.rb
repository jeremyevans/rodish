# frozen_string_literal: true

# The help_examples plugin supports showing examples in help output.
# By default, examples are shown at the end of the help output, but you
# can change the order using the help_order method.

#
module Rodish
  module Plugins
    module HelpExamples
      module DSLMethods
        # Add an example to show in the help output for the command.
        def help_example(example)
          (@command.help_examples ||= []) << example
        end
      end

      module CommandMethods
        # An array of strings for any examples to display in the help.
        attr_accessor :help_examples

        private

        # Include examples at the end of the help text by default.
        def default_help_order
          super << :examples
        end

        def _help_examples(output)
          if help_examples
            output << "Examples:"
            help_examples.each  do |example|
              output << "    #{example}"
            end
            output << ""
          end
        end
      end
    end

    register(:help_examples, HelpExamples)
  end
end
