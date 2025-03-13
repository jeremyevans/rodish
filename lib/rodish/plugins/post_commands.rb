# frozen_string_literal: true

# The post_commands plugin supports subcommands after arguments,
# instead of requiring subcommands before arguments.  You can
# use Command#run to dispatch to post subcommands inside the
# Command's run block.
#
#   run do |argv, opts, command|
#     @something = argv.shift
#     command.run(self, opts, argv)
#   end

#
module Rodish
  module Plugins
    module PostCommands
      def self.after_load(app)
        app.command.instance_exec do
          @post_subcommands ||= {}
        end
      end

      module DSLMethods
        # Set the banner for post subcommand usage.
        def post_banner(banner)
          @command.post_banner = banner
        end

        # Similar to +options+, but sets the option parser for post
        # subcommands.  This option parser is only used when the
        # command is executed and chooses to run a post subcommand.
        def post_options(banner, key: nil, &block)
          @command.post_banner = banner
          @command.post_option_key = key
          @command.post_option_parser = create_option_parser(&block)
        end

        # Similar to +autoload_subcommand_dir+, but for post
        # subcommands instead of normal subcommands.
        def autoload_post_subcommand_dir(dir)
          _autoload_subcommand_dir(@command.post_subcommands, dir)
        end

        # Same as +on+, but for post subcommands instead of normal
        # subcommands.
        def run_on(command_name, &block)
          _on(@command.post_subcommands, command_name, &block)
        end
      end

      module CommandMethods
        # A hash of post subcommands for the command.  Keys are
        # post subcommand name strings.
        attr_reader :post_subcommands

        # The post option parser for the current command.  Called
        # only before dispatching to post subcommands.
        attr_accessor :post_option_parser

        # Similar to +option_key+, but for post options instead
        # of normal subcommands.
        attr_accessor :post_option_key

        # A usage banner for any post subcommands.
        attr_accessor :post_banner

        def initialize(command_path)
          super
          @post_subcommands = {}
        end

        # Freeze all post subcommands and the post option parsers in
        # addition to the command itself.
        def freeze
          @post_subcommands.each_value(&:freeze)
          @post_subcommands.freeze
          @post_option_parser.freeze
          super
        end

        # Run a post subcommand using the given context (generally self),
        # options, and argv.  Usually called inside a run block, after
        # shifting one or more values off the given argv:
        #
        #   run do |argv, opts, command|
        #     @name = argv.shift
        #     command.run(self, opts, argv)
        #   end
        def run(context, options, argv)
          begin
            process_options(argv, options, @post_option_key, @post_option_parser)
          rescue ::OptionParser::InvalidOption => e
            raise CommandFailure.new(e.message, self)
          end

          arg = argv[0]
          if arg && @post_subcommands[arg]
            process_subcommand(@post_subcommands, context, options, argv)
          else
            process_command_failure(arg, @post_subcommands, "post ")
          end
        end
        alias run_post_subcommand run

        # Also yield each post subcommand, recursively.
        def each_subcommand(names = [].freeze, &block)
          super
          _each_subcommand(names, @post_subcommands, &block)
        end

        # Also yield the post banner
        def each_banner
          super
          yield post_banner if post_banner
          nil
        end

        # Returns a Command instance for the named post subcommand.
        # This will autoload the post subcommand if not already loaded.
        def post_subcommand(name)
          _subcommand(@post_subcommands, name)
        end

        private

        # Include post subcommands as separate help section.
        def __help_command_hashes
          hash = super
          hash["Post Commands:"] = @post_subcommands
          hash
        end

        # Include post option parser as separate help section.
        def __help_option_parser_hashes
          hash = super
          hash["Post Options:"] = @post_option_parser
          hash
        end

        # Also yield each local post subcommand to the block.
        def each_local_subcommand(&block)
          super
          _each_local_subcommand(@post_subcommands, &block)
        end
      end
    end

    register(:post_commands, PostCommands)
  end
end
