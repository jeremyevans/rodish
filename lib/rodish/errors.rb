# frozen_string_literal: true

module Rodish
  # Rodish::CommandExit is the base error class for Rodish, signaling
  # that a command execution finished. Callers of
  # Rodish::Processor#process should rescue CommandExit to handle
  # both failures as well as early exits.
  #
  # Direct instances represent successful execution. This is
  # raised when calling halt inside an options parser block (if an
  # option should result in an early exit).  It can also be raised
  # manually inside command run blocks to exit early.
  class CommandExit < StandardError
    # Whether or not the command failed.  For CommandExit, this always
    # returns false, since CommandExit represents successful execution
    # exits.
    def failure?
      false
    end
  end

  # Rodish::CommandFailure is used for failures of commands, such as:
  #
  # * Invalid options
  # * Invalid number of arguments for a command
  # * Invalid subcommands
  # * No subcommand given for a command that only supports subcommands
  class CommandFailure < CommandExit
    attr_reader :command

    def initialize(message, command=nil)
      @command = command
      super(message)
    end

    # Always returns false, since CommandFailure represents failures.
    def failure?
      true
    end

    # Return the message along with the content of any related option
    # parsers.  This can be used to show usage an options along with
    # error messages for failing commands.
    def message_with_usage
      help = @command&.help || ''
      if help.empty?
        message
      else
        "#{message}\n\n#{help}"
      end
    end
  end

  # Rodish::ProgramBug is a subclass of Rodish::CommandFailure only used
  # in cases where there is a bug in the program, such as a command with
  # no subcommands or run block, or when subcommand autoloads do not
  # result in the subcommand being defined.
  class ProgramBug < CommandFailure
  end
end
