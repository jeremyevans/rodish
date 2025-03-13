# frozen_string_literal: true

# The skip_option_parsing plugin allows skipping option parsing
# for a command, treating all elements of argv as arguments instead
# of options. This is different than the default behavior, where
# all options use will fail by default (as no options are supported
# by default.
#
# After loading the plugin, when configuring the command, you can
# call skip_options_parsing with the usage banner:
#
#   skip_options_parsing("usage banner")

#
module Rodish
  module Plugins
    module SkipOptionParsing
      module DSLMethods
        # Skip option parsing for the command.  This is different
        # then the default option parsing, which will error if any
        # options are given.  A banner must be provided, setting
        # the usage for the command.
        #
        # The main reason to use this is if you are going to pass
        # the entire remaining argv as the argv to another
        # program.
        def skip_option_parsing(banner)
          @command.banner = banner
          @command.option_parser = :skip
        end
      end

      module CommandMethods
        private

        # Do not process options if the option parser is set to skip.
        def process_options(argv, options, option_key, option_parser)
          super unless option_parser == :skip
        end

        # Whether the given option parser should be ommitted from the
        # command help output.
        def omit_option_parser_from_help?(parser)
          super || parser == :skip
        end
      end
    end

    register(:skip_option_parsing, SkipOptionParsing)
  end
end
