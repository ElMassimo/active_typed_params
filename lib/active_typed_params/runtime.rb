# frozen_string_literal: true

module ActiveTypedParams
  # Helpers the compiled methods call. Each one is either a type conversion
  # (returning nil when the value is invalid) or a boundary with the host
  # framework.
  module Runtime
    INTEGER = /\A-?\d+\z/
    DECIMAL = /\A-?\d+(?:\.\d+)?\z/
    FLOAT = /\A-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?\z/
    DATE = /\A\d{4}-\d{2}-\d{2}\z/
    TIME = /\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}/
    BOOLEANS = {"true" => true, "false" => false, "1" => true, "0" => false}.freeze
    FRAMEWORK_KEYS = Set.new(%w[controller action format authenticity_token _method utf8 commit]).freeze

  module_function

    # The string-keyed hash behind ActionController::Parameters. Reading that
    # internal (here, in `unwrap_hash` and in `plain`) avoids the deep copy
    # `to_unsafe_h` makes; `spec/active_typed_params/runtime_spec.rb` pins it.
    def raw(params)
      case params
      when ActionController::Parameters then params.instance_variable_get(:@parameters)
      when ActiveSupport::HashWithIndifferentAccess then params
      when Hash then ActiveSupport::HashWithIndifferentAccess.new(params)
      else raise ArgumentError, "expected a Hash or ActionController::Parameters, got #{params.class}"
      end
    end

    # What a `source:` returns: a hash, or nil or an empty string for none.
    def source_hash(value)
      return ActiveSupport::HashWithIndifferentAccess.new if value.nil? || value == ""

      Runtime.raw(unwrap_hash(value) || fail(:invalid_type, [], :hash))
    end

    def unwrap_hash(value)
      case value
      when Hash then value
      when ActionController::Parameters then value.instance_variable_get(:@parameters)
      end
    end

    def fail(code, path, type = nil)
      raise InvalidParameter.for(code, path, type)
    end

    def integer(value)
      Integer(value, 10) if value.is_a?(String) && INTEGER.match?(value)
    end

    def decimal(value)
      case value
      when Integer then BigDecimal(value)
      when BigDecimal then value
      when Float then BigDecimal(value, Float::DIG) if value.finite?
      when String then BigDecimal(value) if DECIMAL.match?(value)
      end
    end

    def float(value)
      parsed = case value
      when Float then value
      when Integer then value.to_f
      when String then Float(value) if FLOAT.match?(value)
      end
      parsed if parsed&.finite?
    end

    def boolean(value)
      if value == true || value == false
        value
      elsif value.is_a?(String)
        BOOLEANS[value]
      end
    end

    def date(value)
      return unless value.is_a?(String) && DATE.match?(value)

      Date.iso8601(value)
    rescue Date::Error
      nil
    end

    # A date alone is rejected, since Time.zone would read it as midnight in
    # the server's zone rather than in the zone the client meant.
    def time(value)
      return unless value.is_a?(String) && TIME.match?(value)

      if Time.respond_to?(:zone) && Time.zone
        Time.zone.iso8601(value)
      else
        Time.iso8601(value)
      end
    rescue ArgumentError
      nil
    end

    def file?(value)
      ActiveTypedParams.config.file_classes.any? { |klass| value.is_a?(klass) }
    end

    def parse_json(value, path, type)
      JSON.parse(value)
    rescue JSON::ParserError
      fail(:invalid_type, path, type)
    end

    # Keys are symbols at every level, like the keys a schema declares.
    def plain(value)
      case value
      when Hash then value.each_with_object({}) { |(key, child), result| result[key.to_sym] = plain(child) }
      when Array then value.map { |child| plain(child) }
      when ActionController::Parameters then plain(value.instance_variable_get(:@parameters))
      else value
      end
    end

    def deep_freeze(value)
      case value
      when Hash then value.each_value { |child| deep_freeze(child) }.freeze
      when Array then value.each { |child| deep_freeze(child) }.freeze
      else value.freeze
      end
    end

    def allowed?(allowed, value)
      allowed.is_a?(Range) ? allowed.cover?(value) : allowed.include?(value)
    end

    # Undeclared keys are reported with `unknown: :report`, or rejected with
    # `unknown: :reject`. Route and framework keys are never unknown at the
    # root, and neither is the copy ParamsWrapper makes of a JSON body.
    def check_unknown(hash, declared, mode, path, context, request)
      unknown = nil
      path_parameters = request&.path_parameters
      wrapped = wrapped_keys(hash, declared, context) if request
      hash.each_key do |key|
        next if declared.include?(key)
        next if request && (FRAMEWORK_KEYS.include?(key) || path_parameters&.key?(key.to_sym) || wrapped&.include?(key))

        fail(:unknown, [*path, key]) if mode == :reject
        (unknown ||= []) << [*path, key].join(".")
      end
      report_unknown(unknown, context) if unknown
    end

    # The wrapper key, plus the root keys it copied when the schema reads the
    # wrapped hash instead of the root.
    def wrapped_keys(hash, declared, context)
      return unless context.respond_to?(:_wrapper_key, true)

      wrapper = context.send(:_wrapper_key)&.to_s
      return if wrapper.nil?

      wrapped = unwrap_hash(hash[wrapper]) if declared.include?(wrapper)
      wrapped ? [wrapper, *wrapped.keys] : [wrapper]
    end

    def report_unknown(keys, context)
      ActiveSupport::Notifications.instrument("unknown_parameters.typed_params", keys:, **context_payload(context))
    end

    def report_invalid(error, context)
      ActiveSupport::Notifications.instrument(
        "invalid_parameters.typed_params",
        path: error.path.join("."), code: error.code, **context_payload(context),
      )
    end

    def context_payload(context)
      return {} if context.nil? || context.instance_of?(Object)

      {
        controller: context.class.name,
        action: (context.action_name if context.respond_to?(:action_name)),
        request: (context.request if context.respond_to?(:request, true)),
      }
    end
  end
end
