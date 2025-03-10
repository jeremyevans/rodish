# frozen_string_literal: true

require_relative "dsl"

module Rodish
  module Processor
    attr_reader :command

    # Process an argv array using a new instance of the class that is
    # extended with Rodish::Processor.  Additional arguments are passed to
    # new when creating the instance.
    #
    # Callers of this method are encouraged to rescue Rodish::CommandExit,
    # to handle both early exits and command failures.
    def process(argv, *a, **kw) 
      # Deliberately do not pass a block here, to reserve
      # block handling for future use.
      @command.process(new(*a, **kw), {}, argv)
    end

    # Without a block, returns the Command instance for related subcommand
    # (a nested subcommand if multiple command names are given).
    #
    # With a block, uses the last command name to create a subcommand under
    # the other named commands, configuring the created subcommand using the
    # block.
    def on(*command_names, &block)
      if block
        command_name = command_names.pop
        dsl(command_names).on(command_name, &block)
      else
        dsl(command_names)
      end
    end

    # Uses the last command name to create a subcommand under the other
    # named commands, with the block being the commands
    def is(*command_names, command_name, args: 0, invalid_args_message: nil, &block)
      dsl(command_names).is(command_name, args:, invalid_args_message:, &block)
    end

    # Freeze the command when freezing the object.
    def freeze
      command.freeze
      super
    end

    # Return a hash of usage strings for the root command and all subcommands,
    # recursively.  The hash has string keys for the command name, and
    # string values for the help for the command.
    def usages
      usages = {}

      command.each_subcommand do |names, command|
        usages[names.join(" ")] = command.help
      end

      usages
    end

    private

    # Use the array of command names to find the appropriate subcommand
    # (which may be empty to use the root command), and return a DSL instance
    # for it.
    def dsl(command_names)
      command = self.command
      command_names.each do |name|
        command = command.subcommand(name)
      end
      DSL.new(command)
    end
  end
end
