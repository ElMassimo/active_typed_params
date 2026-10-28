# frozen_string_literal: true

require "json"
require "digest"
require "bigdecimal"
require "date"
require "time"
require "active_support"
require "active_support/core_ext/hash/indifferent_access"
require "active_support/notifications"
require "action_controller"

require "active_typed_params/version"
require "active_typed_params/errors"
require "active_typed_params/node"
require "active_typed_params/enum_adapter"
require "active_typed_params/runtime"
require "active_typed_params/declaration"
require "active_typed_params/builder"
require "active_typed_params/compiler"
require "active_typed_params/schema"
require "active_typed_params/inline"
require "active_typed_params/controller"
require "active_typed_params/inference"
require "active_typed_params/railtie" if defined?(Rails::Railtie)

# Typed, compiled request parameters: see the `typed_params` controller DSL.
module ActiveTypedParams
  class Configuration
    # Each adapter receives the source given to `enum` and returns a Hash from
    # raw request value to returned value, or nil when it does not handle it.
    attr_accessor :enum_adapters

    attr_accessor :file_classes

    # The cap for `text` and for strings inference leaves to the model or the
    # interaction: long, but bounded.
    attr_accessor :text_max_length

    # Each inferrer receives an ActiveModel attribute type and returns a
    # Declaration, or nil when it does not handle it.
    attr_accessor :type_inferrers

    # Filter names `inputs_from` never declares, for inputs every interaction shares.
    attr_accessor :ignored_filters

    # Each inferrer receives an ActiveInteraction filter and returns a
    # Declaration, or nil when it does not handle it.
    attr_accessor :filter_inferrers

    def initialize
      @enum_adapters = []
      @type_inferrers = []
      @ignored_filters = []
      @filter_inferrers = []
      @text_max_length = 65_535
      @file_classes = []
      @file_classes << ActionDispatch::Http::UploadedFile if defined?(ActionDispatch::Http::UploadedFile)
      @file_classes << Rack::Test::UploadedFile if defined?(Rack::Test::UploadedFile)
    end
  end

  class << self
    def config
      @config ||= Configuration.new
    end

    def configure
      yield config
    end

    # A definition survives code reloading, so one declared in an initializer
    # must not reference reloadable classes, such as models or enums. Declare
    # it beside the model instead, where reloading declares it again.
    def define(name, **options, &block)
      definitions[name.to_sym] = Schema.new(name:, options:, block:)
    end

    # Keys to merge with `use`, kept beside the model they describe, with no
    # method and no global name: `IDEA_PARAMS = ActiveTypedParams.fragment { … }`.
    def fragment(&block)
      Schema.new(name: :fragment, block:)
    end

    def definition(name)
      definitions.fetch(name.to_sym) { raise SchemaError, "no schema defined as #{name.inspect}" }
    end

    def register(schema)
      (registry[schema.owner] ||= {})[schema.name] = schema
    end

    def schema(owner, name)
      registry.dig(owner, name.to_sym) || raise(SchemaError, "#{owner} declares no typed_params #{name.inspect}")
    end

    # A schema declared on the owner or one of its ancestors, or else a global definition.
    def find_schema(owner, name)
      owner&.ancestors&.each do |ancestor|
        schema = registry.dig(ancestor, name.to_sym)
        return schema if schema
      end
      definition(name)
    end

    def source(owner, name)
      schema(owner, name).source
    end

    def schemas
      registry.values.flat_map(&:values)
    end

    # Every schema a controller or a global definition declares, as a snapshot spec lists them.
    def all_schemas
      schemas + definitions.values
    end

    def compile_all!
      all_schemas.each(&:install!)
    end

    def inline_schema(key)
      inline_schemas[key] ||= yield
    end

    # Code reloading replaces controller classes, which register their schemas
    # again on load; schemas registered with `define` live in initializers and stay.
    def unload!
      registry.clear
      inline_schemas.clear
    end

  private

    def registry
      @registry ||= {}
    end

    def definitions
      @definitions ||= {}
    end

    def inline_schemas
      @inline_schemas ||= {}
    end
  end
end
