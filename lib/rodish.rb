# frozen_string_literal: true

require_relative "rodish/processor"
require_relative "rodish/dsl"

module Rodish
  # Install a Rodish processor in the given class. This extends the class
  # with Rodish::Processor, and uses the block to configure the processor
  # using Rodish::DSL.
  def self.processor(klass, &block)
    klass.extend(Processor)

    dsl_class = Class.new(DSL)
    klass.const_set(:DSL, dsl_class)

    command_class = Class.new(Command)
    dsl_class.const_set(:Command, command_class)

    option_parser_class = Class.new(OptionParser)
    dsl_class.const_set(:OptionParser, option_parser_class)

    option_parser = option_parser_class.new
    option_parser.set_banner("")
    option_parser.freeze
    command_class.const_set(:DEFAULT_OPTION_PARSER, option_parser)

    klass.instance_variable_set(:@command, dsl_class.command([].freeze, &block))
    klass
  end
end
