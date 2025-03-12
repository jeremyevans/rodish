# frozen_string_literal: true

module Rodish
  MUTEX = Mutex.new
  private_constant :MUTEX

  # Hash of symbol keys to module values for registered rodish plugins.
  PLUGINS = {}
  private_constant :PLUGINS

  # Namespace for Rodish plugins.  Plugins do not have to be in this
  # namespace, but this is what plugins that ship with Rodish use.
  module Plugins
    # Load a Rodish plugin.  +name+ should be a symbol.
    def self.fetch(name)
      MUTEX.synchronize{PLUGINS[name]}
    end

    # Register a Rodish plugin.  +name+ should be a symbol, and +mod+
    # should be a module.
    def self.register(name, mod)
      MUTEX.synchronize{PLUGINS[name] = mod}
    end
  end
end
