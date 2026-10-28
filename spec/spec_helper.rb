# frozen_string_literal: true

# The specs load ActionPack alone, and run without a Rails app or a database.
require "action_controller"
require "active_support/time"
require "active_support/core_ext/enumerable"
require "rack/test"
require "benchmark"
require "active_typed_params"

module ActiveTypedParamsSpec
  Request = Struct.new(:content_mime_type, :path_parameters, keyword_init: true)
  PATH_PARAMETERS = {controller: "fake", action: "show", id: "7"}.freeze

  def self.json_request
    Request.new(content_mime_type: Mime[:json], path_parameters: PATH_PARAMETERS)
  end

  def self.form_request
    Request.new(content_mime_type: Mime[:url_encoded_form], path_parameters: PATH_PARAMETERS)
  end

  def self.query_request
    Request.new(content_mime_type: nil, path_parameters: PATH_PARAMETERS)
  end

  class FakeController
    include ActiveTypedParams::Controller

    attr_reader :params, :request
    attr_writer :admin

    def initialize(params, request: ActiveTypedParamsSpec.json_request)
      @params = params.is_a?(ActionController::Parameters) ? params : ActionController::Parameters.new(params)
      @request = request
    end

    def action_name
      "show"
    end

    def admin?
      @admin != false
    end

    def max_page_size
      50
    end
  end

  # Declares the schema on a fresh controller class and runs it through the
  # stub, so each call exercises installation.
  def self.run(params:, request: json_request, options: {}, nodes: nil, controller: nil, &block)
    klass = Class.new(FakeController)
    if nodes
      ActiveTypedParams.register(ActiveTypedParams::Schema.new(owner: klass, name: :schema_params, options:, nodes:))
      ActiveTypedParams.schema(klass, :schema_params).install!
    else
      klass.typed_params(:schema_params, **options, &block)
    end
    instance = klass.new(params, request:)
    controller&.call(instance)
    instance.send(:schema_params)
  end

  def self.notifications(name)
    payloads = []
    subscriber = ActiveSupport::Notifications.subscribe(name) { |*, payload| payloads << payload }
    yield
    payloads
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end

  # The validation examples pin the required path by default, so a bare
  # `string :name` in them is a required key; presence defaults have their own examples.
  module Helpers
    def validate(params, request: ActiveTypedParamsSpec.json_request, controller: nil, required: true, **options, &schema)
      ActiveTypedParamsSpec.run(params:, request:, options: {required:, **options}, controller:, &schema)
    end

    def failure(params, request: ActiveTypedParamsSpec.json_request, controller: nil, required: true, **options, &schema)
      validate(params, request:, controller:, required:, **options, &schema)
      raise "expected the parameters to be rejected"
    rescue ActiveTypedParams::InvalidParameter => error
      [error.code, error.path]
    end
  end
end

# Examples register throwaway schemas and expect the library's default settings,
# so each one starts from a clean registry and leaves the settings as it found them.
RSpec.configure do |config|
  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed

  config.around(:each, :active_typed_params) do |example|
    registry = ActiveTypedParams.send(:registry).dup
    definitions = ActiveTypedParams.send(:definitions).dup
    inline_schemas = ActiveTypedParams.send(:inline_schemas).dup
    ActiveTypedParams.send(:inline_schemas).clear
    settings = ActiveTypedParams.config
    adapters = settings.enum_adapters.dup
    inferrers = settings.type_inferrers.dup
    filter_inferrers = settings.filter_inferrers.dup
    ignored = settings.ignored_filters.dup
    text_max_length = settings.text_max_length
    settings.text_max_length = ActiveTypedParams::Configuration.new.text_max_length
    example.run
  ensure
    ActiveTypedParams.send(:registry).replace(registry)
    ActiveTypedParams.send(:definitions).replace(definitions)
    ActiveTypedParams.send(:inline_schemas).replace(inline_schemas)
    settings.enum_adapters = adapters
    settings.type_inferrers = inferrers
    settings.filter_inferrers = filter_inferrers
    settings.ignored_filters = ignored
    settings.text_max_length = text_max_length
  end
end
