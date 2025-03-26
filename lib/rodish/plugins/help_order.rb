# frozen_string_literal: true

# The help_order plugin allows overriding the order of help sections in
# commands:
#
#   help_order(:desc, :options)
#
# You can provide the default order for help sections using the
# +default_help_order+ keyword argument:
#
#   plugin :help_order, default_help_order: [:usage, :options]

#
module Rodish
  module Plugins
    module HelpOrder
      def self.after_load(app, default_help_order: nil)
        if default_help_order
          app::DSL::Command.class_exec do
            define_method(:default_help_order){default_help_order.dup}
            alias_method(:default_help_order, :default_help_order)
            private(:default_help_order)
          end
        end
      end

      module DSLMethods
        # Override the order of help sections for the command.
        def help_order(*sections)
          @command.help_order = sections
        end
      end

      module CommandMethods
        # The order of sections in returned help. If not set for the
        # command, uses the default order
        attr_writer :help_order

        private

        def help_order
          @help_order || super
        end
      end
    end

    register(:help_order, HelpOrder)
  end
end
