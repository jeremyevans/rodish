# frozen_string_literal: true

# The default_help_order plugin allows setting the default help order
# for all subcommands. You provide the default order for help sections
# as the plugin argument:
#
#   plugin :default_help_order, [:usage, :options]

#
module Rodish
  module Plugins
    module DefaultHelpOrder
      def self.after_load(app, help_order)
        app::DSL::Command.define_method(:default_help_order){help_order.dup}
      end
    end

    register(:default_help_order, DefaultHelpOrder)
  end
end
