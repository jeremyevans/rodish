# frozen_string_literal: true

require_relative "option_parser"
require_relative "errors"

module Rodish
  # Rodish::Command is the main object in Rodish's processing.
  # It handles a single command, and may have one or more
  # subcommands, forming a tree.
  #
  # Rodish's argv processing starts with the root command,
  # processing options and deleting appropriately to subcommands,
  # until the requested command or subcommand is located,
  # which is then executed.
  class Command
    # A hash of subcommands for the command.  Keys are
    # subcommand name strings.
    attr_reader :subcommands

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

    # The number of arguments the run block will accept.
    # Should be either an integer or a range of integers.
    attr_accessor :num_args

    # A description for the command
    attr_accessor :desc

    # A usage banner for the command or subcommands.
    attr_accessor :banner

    def initialize(command_path)
      @command_path = command_path
      @command_name = _command_name(command_path)
      @subcommands = {}
      @num_args = 0
    end

    # Freeze all subcommands and option parsers in
    # addition to the command itself.
    def freeze
      @subcommands.each_value(&:freeze)
      @subcommands.freeze
      @option_parser.freeze
      super
    end

    # Return a help string for the command.
    def help
      help_lines.join("\n")
    end

    # Return an array of help strings for the command.
    def help_lines
      output = []
      help_order.each do |type|
        send(:"_help_#{type}", output)
      end
      output
    end

    # Process options for the command using the option key and parser.
    def process_command_options(context, options, argv)
      process_options(argv, options, @option_key, @option_parser)
    end

    # Process the current command.  This first processes the options.
    # After processing the options, it checks if the first argument
    # in the remaining argv is a subcommand.  If so, it dispatches to
    # that subcommand.  If not, it dispatches to the run block.
    def process(context, options, argv)
      process_command_options(context, options, argv)

      arg = argv[0]
      if argv && @subcommands[arg]
        process_subcommand(@subcommands, context, options, argv)
      elsif run_block
        if valid_args?(argv)
          if @num_args.is_a?(Integer)
            context.instance_exec(*argv, options, self, &run_block)
          else
            context.instance_exec(argv, options, self, &run_block)
          end
        else
          raise_invalid_args_failure(argv)
        end
      else
        process_command_failure(arg, @subcommands, "")
      end
    rescue ::OptionParser::InvalidOption => e
      raise_failure(e.message)
    end

    # This yields the current command and all subcommands, recursively.
    def each_subcommand(names = [].freeze, &block)
      yield names, self
      _each_subcommand(names, @subcommands, &block)
    end

    # Yield each banner string (if any) to the block.
    def each_banner
      yield banner if banner
      nil
    end

    # Raise a CommandFailure with the given error and the given
    # option parsers.
    def raise_failure(message)
      raise CommandFailure.new(message, self)
    end

    # Returns a Command instance for the named subcommand.
    # This will autoload the subcommand if not already loaded.
    def subcommand(name)
      _subcommand(@subcommands, name)
    end

    private

    # The string to use for the usage heading in help output.
    def help_usage_heading
      "Usage:"
    end

    # The string to use for the command heading in help output.
    def help_command_heading
      "Commands:"
    end

    # The string to use for the options heading in help output.
    def help_options_heading
      "Options:"
    end

    # Use default help order by default.
    def help_order
      default_help_order
    end

    # The default order of help sections
    def default_help_order
      [:desc, :banner, :commands, :options]
    end

    # Add description to help output.
    def _help_desc(output)
      if desc
        output << desc << ""
      end
    end

    # Add banner to help output.
    def _help_banner(output)
      if each_banner{break true}
        output << help_usage_heading
        each_banner do |banner|
          output << "    #{banner}"
        end
        output << ""
      end
    end

    # Add commands to help output.
    def _help_commands(output)
      name_len = 0
      each_local_subcommand do |name|
        len = name.length
        name_len = len if len > name_len
      end

      __help_command_hashes.each do |heading, hash|
        next if hash.empty?
        output << heading
        command_output = []
        _each_local_subcommand(hash) do |name, command|
          command_output << "    #{name.ljust(name_len)}    #{command.desc}" 
        end
        command_output.sort!
        output.concat(command_output)
        output << ""
      end
    end

    # Hash with hash of subcommand values to potentially show help output for.
    def __help_command_hashes
      {help_command_heading => @subcommands}
    end

    # Add options to help output.
    def _help_options(output)
      __help_option_parser_hashes.each do |heading, parser|
        next if omit_option_parser_from_help?(parser)
        output << heading
        output << parser.summarize(String.new)
      end
    end

    # Hash with option parser values to potentially show help output for.
    def __help_option_parser_hashes
      {help_options_heading => @option_parser}
    end

    # Whether the given option parser should be ommitted from the
    # command help output.
    def omit_option_parser_from_help?(parser)
      parser.nil?
    end

    # Raise a error when an invalid number of arguments has been provided.
    def raise_invalid_args_failure(argv)
      raise_failure(invalid_num_args_failure_error_message(argv))
    end

    # Yield each local subcommand to the block.  This does not
    # yield the current command or nested subcommands.
    def each_local_subcommand(&block)
      _each_local_subcommand(@subcommands, &block)
    end

    # Internals of each_local_subcommand.
    def _each_local_subcommand(subcommands)
      subcommands.each_key do |name|
        yield name, _subcommand(subcommands, name)
      end
    end

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

    # Handle command failures for subcommands.
    def process_command_failure(arg, subcommands, prefix)
      if subcommands.empty?
        raise ProgramBug, "program bug, no run block or #{prefix}subcommands defined#{subcommand_name}"
      elsif arg
        raise_failure(invalid_subcommand_error_message(arg, subcommands, prefix))
      else
        raise_failure(no_subcommand_provided_error_message(arg, subcommands, prefix))
      end
    end

    # The error message to use when an invalid number of arguments is provided.
    def invalid_num_args_failure_error_message(argv)
      "invalid number of arguments#{subcommand_name} (requires: #{@num_args}, given: #{argv.length})"
    end

    # Error message for cases where an invalid subcommand is provided.
    def invalid_subcommand_error_message(arg, subcommands, prefix)
      "invalid #{prefix}subcommand: #{arg}"
    end

    # Error message for cases where a subcommand is required and not provided.
    def no_subcommand_provided_error_message(arg, subcommands, prefix)
      "no #{prefix}subcommand provided"
    end

    # Process options for the given command. If option_key is set,
    # parsed options are added as a options subhash under the given key.
    # Otherwise, parsed options placed directly into options.
    def process_options(argv, options, option_key, option_parser)
      if option_parser
        command_options = option_key ? {} : options

        option_parser.order!(argv, into: command_options)

        if option_key
          options[option_key] = command_options
        end
      else
        self.class::DEFAULT_OPTION_PARSER.order!(argv)
      end
    end

    # Dispatch to the appropriate subcommand using the first entry in
    # the provided argv.
    def process_subcommand(subcommands, context, options, argv)
      subcommand = _subcommand(subcommands, argv[0])
      argv.shift
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

    # Set the command name for the command.  The command name is used
    # in error messages.
    def _command_name(command_path)
      command_path.join(" ").freeze
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
