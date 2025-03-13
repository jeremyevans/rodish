# frozen_string_literal: true

require_relative "command"
require_relative "option_parser"

module Rodish
  # The Rodish::DSL class implements Rodish's DSL.  Blocks
  # passed to Rodish.processor and on/run_on blocks inside
  # those blocks evaluated in the context of an instance of
  # Rodish::DSL.
  #
  # Each Rodish::DSL instance is bound to a single
  # Rodish::Command and allows the DSL to modify the state
  # of the command.
  class DSL
    # Create a new command with the given path and evaluate
    # the given block in the context of a new instance using
    # that command.
    def self.command(command_path, &block)
      command = self::Command.new(command_path)
      new(command).instance_exec(&block) if block
      command
    end

    def initialize(command)
      @command = command
    end

    # Set the description for the command.
    def desc(description)
      @command.desc = description
    end

    # Set the banner for the command execution and subcommand usage.
    def banner(banner)
      @command.banner = banner
    end

    # Set the banner for post subcommand usage.
    def post_banner(banner)
      @command.post_banner = banner
    end

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

    # Set the option parser for the command to based on the
    # provided block, which is executed in the context of a new
    # instance of Rodish::OptionParser. These options are parsed
    # for execuction of both subcommands and the current command.
    #
    # The banner argument is required and sets the usage string
    # for the command.
    #
    # If +key+ is given, parsed options
    # will be placed in a subhash using that key.
    def options(banner, key: nil, &block)
      @command.banner = banner
      @command.option_key = key
      @command.option_parser = create_option_parser(&block)
    end

    # Similar to +options+, but sets the option parser for post
    # subcommands.  This option parser is only used when the
    # command is executed and chooses to run a post subcommand.
    def post_options(banner, key: nil, &block)
      @command.post_banner = banner
      @command.post_option_key = key
      @command.post_option_parser = create_option_parser(&block)
    end

    # Set the number of arguments supported by this command.
    # The default is 0.  To support a fixed number of arguments,
    # pass an Integer.  To support a variable number of arguments,
    # pass a Range.  The +invalid_args_message+ argument sets the
    # error message to use if an invalid number of arguments is
    # passed.
    def args(args, invalid_args_message: nil)
      @command.num_args = args
      @command.invalid_args_message = invalid_args_message
    end

    # Autoload subcommands from the given directory. Filenames
    # ending in .rb in this directory should be valid subcommands,
    # and requiring the related file should load the subcommand.
    #
    # You can use this so that your argv parser does not need to
    # load code not needed to support processing the command.
    def autoload_subcommand_dir(dir)
      _autoload_subcommand_dir(@command.subcommands, dir)
    end

    # Similar to +autoload_subcommand_dir+, but for post
    # subcommands instead of normal subcommands.
    def autoload_post_subcommand_dir(dir)
      _autoload_subcommand_dir(@command.post_subcommands, dir)
    end

    # Create a new subcommand with the given name and yield to
    # the block to configure the subcommand.
    def on(command_name, &block)
      _on(@command.subcommands, command_name, &block)
    end

    # Same as +on+, but for post subcommands instead of normal
    # subcommands.
    def run_on(command_name, &block)
      _on(@command.post_subcommands, command_name, &block)
    end

    # Set the block to run for subcommand execution.  Commands
    # should have subcommands and/or a run block, otherwise it
    # is not possible to use the command successfully.
    def run(&block)
      @command.run_block = block
    end

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
    #
    # The +invalid_args_message+ arguments set the error message to
    # use if an invalid number of arguments is provided.
    def is(command_name, args: 0, invalid_args_message: nil, &block)
      _is(:on, command_name, args:, invalid_args_message:, &block)
    end

    # Similar to +is+, but for post subcommands instead of normal
    # subcommands.
    def run_is(command_name, args: 0, invalid_args_message: nil, &block)
      _is(:run_on, command_name, args:, invalid_args_message:, &block)
    end

    private

    # Internals of autoloading of normal and post subcommands.
    # This sets the value of the subcommand as a string instead of a
    # Command instance, and the Command#_subcommand method recognizes
    # this and handles the autoloading.
    def _autoload_subcommand_dir(hash, base)
      Dir.glob("*.rb", base:).each do |filename|
        hash[filename.chomp(".rb")] = File.expand_path(File.join(base, filename))
      end
    end

    # Internals of +is+ and +run_is+.
    def _is(meth, command_name, args:, invalid_args_message: nil, &block)
      public_send(meth, command_name) do
        args(args, invalid_args_message:)
        run(&block)
      end
    end

    # Internals of +on+ and +run_on+.
    def _on(hash, command_name, &block)
      command_path = @command.command_path + [command_name]
      hash[command_name] = self.class.command(command_path.freeze, &block)
    end

    # Internals of +options+ and +post_options+.
    def create_option_parser(&block)
      option_parser = self.class::OptionParser.new
      option_parser.banner = "" # Avoids issues when parser is frozen
      option_parser.instance_exec(&block)
      option_parser
    end
  end
end
