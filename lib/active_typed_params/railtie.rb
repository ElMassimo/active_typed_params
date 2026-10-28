# frozen_string_literal: true

module ActiveTypedParams
  # Makes `typed_params` available in every controller, compiles every schema
  # at boot when eager loading, and starts over when code reloads.
  class Railtie < Rails::Railtie
    initializer "active_typed_params.controller" do
      ActiveSupport.on_load(:action_controller) { include ActiveTypedParams::Controller }
    end

    initializer "active_typed_params.reloader" do |app|
      app.reloader.before_class_unload { ActiveTypedParams.unload! }
    end

    config.after_initialize do |app|
      ActiveTypedParams.compile_all! if app.config.eager_load
    end
  end
end
