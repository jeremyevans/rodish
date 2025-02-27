# frozen_string_literal: true

require_relative "rodish/processor"
require_relative "rodish/dsl"

module Rodish
  # Install a Rodish processor in the given class. This extends the class
  # with Rodish::Processor, and uses the block to configure the processor
  # using Rodish::DSL.
  def self.processor(klass, &block)
    klass.extend(Processor)
    klass.instance_variable_set(:@command, DSL.command([].freeze, &block))
    klass
  end
end
