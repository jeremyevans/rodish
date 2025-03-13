# frozen_string_literal: true

require_relative "dsl"
require_relative "plugins"

module Rodish
  module Processor
    # The root command for the processor.
    attr_reader :command

    # Load a plugin into the current processor.
    def plugin(name, ...)
      mod = load_plugin(name)
      mod.before_load(self, ...) if mod.respond_to?(:before_load)
      extend(mod::ProcessorMethods) if defined?(mod::ProcessorMethods)
      self::DSL.include(mod::DSLMethods) if defined?(mod::DSLMethods)
      self::DSL::Command.include(mod::CommandMethods) if defined?(mod::CommandMethods)
      self::DSL::OptionParser.include(mod::OptionParserMethods) if defined?(mod::OptionParserMethods)
      mod.after_load(self, ...) if mod.respond_to?(:after_load)
      nil
    end

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
        if command_name = command_names.pop
          dsl(command_names).on(command_name, &block)
        else
          dsl(command_names).instance_exec(&block)
        end
      else
        dsl(command_names)
      end
    end

    # Uses the last command name to create a subcommand under the other
    # named commands, with the block being the commands
    def is(*command_names, command_name, **kw, &block)
      dsl(command_names).is(command_name, **kw, &block)
    end

    # Freeze the command and classes related to the processor when freezing the processor.
    def freeze
      command.freeze
      self::DSL.freeze
      self::DSL::Command.freeze
      self::DSL::OptionParser.freeze
      super
    end

    private

    # Load the rodish plugin with the given name, which can be either a module
    # (used directly), or a symbol (which will load a registered plugin), requiring
    # the related plugin file if it is not already registered.
    def load_plugin(name)
      case name
      when Module
        name
      when Symbol
        unless mod = Rodish::Plugins.fetch(name)
          require "rodish/plugins/#{name}"
          unless mod = Rodish::Plugins.fetch(name)
            raise RuntimeError, "rodish plugin did not properly register itself: #{name.inspect}"
          end
        end

        mod
      else
        raise ArgumentError, "invalid argument to plugin: #{name.inspect}"
      end
    end

    # Use the array of command names to find the appropriate subcommand
    # (which may be empty to use the root command), and return a DSL instance
    # for it.
    def dsl(command_names)
      command = self.command
      command_names.each do |name|
        command = command.subcommand(name)
      end
      self::DSL.new(command)
    end
  end
end
