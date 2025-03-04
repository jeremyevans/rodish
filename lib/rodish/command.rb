# frozen_string_literal: true

require_relative "option_parser"
require_relative "skip_option_parser"
require_relative "errors"

module Rodish
  # Rodish::Command is the main object in Rodish's processing.
  # It handles a single command, and may have one or more
  # subcommands and/or post subcommands, forming a tree.
  #
  # Rodish's argv processing starts with the root command,
  # processing options and deleting appropriately to subcommands,
  # until the requested command or subcommand is located,
  # which is then executed.
  class Command
    option_parser = OptionParser.new
    option_parser.set_banner("")
    option_parser.freeze

    # The default option parser if no options are given for
    # the command.
    DEFAULT_OPTION_PARSER = option_parser

    # A hash of subcommands for the command.  Keys are
    # subcommand name strings.
    attr_reader :subcommands

    # A hash of post subcommands for the command.  Keys are
    # post subcommand name strings.
    attr_reader :post_subcommands

    # The block to execute if this command is the requested
    # subcommand.  May be nil if this subcommand cannot be
    # executed, and can only dispatch to subcommands.
    attr_accessor :run_block

    # An array of command names that represent a path to the
    # current command.  Empty for the root command.
    attr_accessor :command_path

    # The option parser for the current command.  May be nil,
    # in which case the default option parser is used.
    attr_accessor :option_parser

    # If set, places parsed options in a subhash of the options
    # hash, keyed by the given value.  If nil, parsed options
    # are placed directly in the options hash.
    attr_accessor :option_key

    # The post option parser for the current command.  Called
    # only before dispatching to post subcommands.
    attr_accessor :post_option_parser

    # Similar to +option_key+, but for post options instead
    # of normal subcommands.
    attr_accessor :post_option_key

    # A hook to execute after parsing options for the command.
    attr_accessor :after_options

    # A hook to execute before executing the current
    # command or dispatching to subcommands. This will not
    # be called if an invalid subcommand is given and no
    # run block is present.
    attr_accessor :before

    # The number of arguments the run block will accept.
    # Should be either an integer or a range of integers.
    attr_accessor :num_args

    # The error message to use if an invalid number of
    # arguments is provided.
    attr_accessor :invalid_args_message

    def initialize(command_path)
      @command_path = command_path
      @command_name = command_path.join(" ").freeze
      @subcommands = {}
      @post_subcommands = {}
      @num_args = 0
    end

    # Freeze all subcommands and option parsers in
    # addition to the command itself.
    def freeze
      @subcommands.each_value(&:freeze)
      @subcommands.freeze
      @post_subcommands.each_value(&:freeze)
      @post_subcommands.freeze
      @option_parser.freeze
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
        raise CommandFailure.new(e.message, @post_option_parser)
      end

      arg = argv[0]
      if arg && @post_subcommands[arg]
        process_subcommand(@post_subcommands, context, options, argv)
      else
        process_command_failure(arg, @post_subcommands, @post_option_parser, "post ")
      end
    end
    alias run_post_subcommand run

    # Process the current command.  This first processes the options.
    # After processing the options, it checks if the first argument
    # in the remaining argv is a subcommand.  If so, it dispatches to
    # that subcommand.  If not, it dispatches to the run block.
    def process(context, options, argv)
      process_options(argv, options, @option_key, @option_parser)
      context.instance_exec(argv, options, &after_options) if after_options

      arg = argv[0]
      if argv && @subcommands[arg]
        process_subcommand(@subcommands, context, options, argv)
      elsif run_block
        if valid_args?(argv)
          context.instance_exec(argv, options, &before) if before

          if @num_args.is_a?(Integer)
            context.instance_exec(*argv, options, self, &run_block)
          else
            context.instance_exec(argv, options, self, &run_block)
          end
        elsif @invalid_args_message
          raise_failure("invalid arguments#{subcommand_name} (#{@invalid_args_message})")
        else
          raise_failure("invalid number of arguments#{subcommand_name} (accepts: #{@num_args}, given: #{argv.length})")
        end
      else
        process_command_failure(arg, @subcommands, @option_parser, "")
      end
    rescue ::OptionParser::InvalidOption => e
      if @option_parser || @post_option_parser
        raise_failure(e.message)
      else
        raise
      end
    end

    # This yields the current command and all subcommands and
    # post subcommands, recursively.
    def each_subcommand(names = [].freeze, &block)
      yield names, self
      _each_subcommand(names, @subcommands, &block)
      _each_subcommand(names, @post_subcommands, &block)
    end

    # Raise a CommandFailure with the given error and the given
    # option parsers.
    def raise_failure(message, option_parsers = self.option_parsers)
      raise CommandFailure.new(message, option_parsers)
    end

    # Returns a string of options text for the command's option parsers.
    def options_text
      option_parsers = self.option_parsers
      unless option_parsers.empty?
        _options_text(option_parsers)
      end
    end

    # Returns a Command instance for the named subcommand.
    # This will autoload the subcommand if not already loaded.
    def subcommand(name)
      _subcommand(@subcommands, name)
    end

    # Returns a Command instance for the named post subcommand.
    # This will autoload the post subcommand if not already loaded.
    def post_subcommand(name)
      _subcommand(@post_subcommands, name)
    end

    # An array of option parsers for the command.  May be empty
    # if the command has no option parsers.
    def option_parsers
      [@option_parser, @post_option_parser].compact
    end

    private

    # Yield to the block for each subcommand in the given
    # subcommands.  Internals of #each_subcommand.
    def _each_subcommand(names, subcommands, &block)
      subcommands.each_key do |name|
        sc_names = names + [name]
        _subcommand(subcommands, name).each_subcommand(sc_names.freeze, &block)
      end
    end

    # Return the named subcommand from the given subcommands hash,
    # autoloading it if it is not already loaded.
    def _subcommand(subcommands, name)
      subcommand = subcommands[name]

      if subcommand.is_a?(String)
        require subcommand
        subcommand = subcommands[name]
        unless subcommand.is_a?(Command)
          raise ProgramBug, "program bug, autoload of subcommand #{name} failed"
        end
      end

      subcommand
    end

    # Return a string containing all option parser text.
    def _options_text(option_parsers)
      option_parsers.join("\n\n")
    end

    # Handle command failures for both subcommands and post subcommands.
    def process_command_failure(arg, subcommands, option_parser, prefix)
      if subcommands.empty?
        raise ProgramBug, "program bug, no run block or #{prefix}subcommands defined#{subcommand_name}"
      elsif arg
        raise_failure("invalid #{prefix}subcommand: #{arg}", option_parser)
      else
        raise_failure("no #{prefix}subcommand provided", option_parser)
      end
    end

    # Process options for the given command. If option_key is set,
    # parsed options are added as a options subhash under the given key.
    # Otherwise, parsed options placed directly into options.
    def process_options(argv, options, option_key, option_parser)
      case option_parser
      when SkipOptionParser
        # do nothing
      when nil
        DEFAULT_OPTION_PARSER.order!(argv)
      else
        command_options = option_key ? {} : options

        option_parser.order!(argv, into: command_options)

        if option_key
          options[option_key] = command_options
        end
      end
    end

    # Dispatch to the appropriate subcommand using the first entry in
    # the provided argv.
    def process_subcommand(subcommands, context, options, argv)
      subcommand = _subcommand(subcommands, argv[0])
      argv.shift
      context.instance_exec(argv, options, &before) if before
      subcommand.process(context, options, argv)
    end

    # Helper used for constructing error messages.
    def subcommand_name
      if @command_name.empty?
        " for command"
      else
        " for #{@command_name} subcommand"
      end
    end

    # Return whether the given argv has a valid number of arguments.
    def valid_args?(argv)
      if @num_args.is_a?(Integer)
        argv.length == @num_args
      else
        @num_args.include?(argv.length)
      end
    end
  end
end
