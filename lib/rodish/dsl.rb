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

    # Set the number of arguments supported by this command.
    # The default is 0.  To support a fixed number of arguments,
    # pass an Integer.  To support a variable number of arguments,
    # pass a Range.
    def args(args)
      @command.num_args = args
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

    # Create a new subcommand with the given name and yield to
    # the block to configure the subcommand.
    def on(command_name, &block)
      _on(@command.subcommands, command_name, &block)
    end

    # Set the block to run for subcommand execution.  Commands
    # should have subcommands and/or a run block, otherwise it
    # is not possible to use the command successfully.
    def run(&block)
      @command.run_block = block
    end

    private

    # Internals of autoloading of subcommands.
    # This sets the value of the subcommand as a string instead of a
    # Command instance, and the Command#_subcommand method recognizes
    # this and handles the autoloading.
    def _autoload_subcommand_dir(hash, base)
      Dir.glob("*.rb", base:).each do |filename|
        hash[filename.chomp(".rb")] = File.expand_path(File.join(base, filename))
      end
    end

    # Internals of +on+.
    def _on(hash, command_name, &block)
      command_path = @command.command_path + [command_name]
      hash[command_name] = self.class.command(command_path.freeze, &block)
    end

    # Internals of +options+.
    def create_option_parser(&block)
      option_parser = self.class::OptionParser.new
      option_parser.banner = "" # Avoids issues when parser is frozen
      option_parser.instance_exec(&block)
      option_parser
    end
  end
end
