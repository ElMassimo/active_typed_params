# frozen_string_literal: true

module ActiveTypedParams
  class SchemaError < StandardError; end

  # Raised when a request parameter does not match its declaration. Subclasses
  # ActionController::BadRequest when ActionPack is loaded, so Rails and
  # existing `rescue_from` handlers treat it as a client error.
  class InvalidParameter < (defined?(ActionController::BadRequest) ? ActionController::BadRequest : StandardError)
    TYPE_WORDS = {
      string: "a string",
      integer: "an integer",
      id: "an id",
      decimal: "a decimal",
      float: "a number",
      boolean: "a boolean",
      date: "a date (YYYY-MM-DD)",
      time: "a time (ISO 8601)",
      enum: "one of the allowed values",
      file: "a file",
      hash: "an object",
      map: "an object",
      array: "an array",
      any: "a value",
      one_of: "one of the allowed types",
    }.freeze

    attr_reader :path, :code

    def self.for(code, path, type = nil)
      (UnprocessableParameter::CODES.include?(code) ? UnprocessableParameter : self).new(code, path, type)
    end

    def status
      :bad_request
    end

    def initialize(code, path, type = nil)
      @code = code
      @path = path.freeze
      super("#{path.empty? ? "params" : path.join(".")} #{reason(type)}")
    end

  private

    def reason(type)
      case code
      when :missing then "is required"
      when :blank then "can't be blank"
      when :invalid_type then "must be #{TYPE_WORDS.fetch(type)}"
      when :not_allowed then "is not an allowed value"
      when :too_long then "is too long"
      when :unknown then "is not a known parameter"
      else raise ArgumentError, "unknown error code #{code.inspect}"
      end
    end
  end

  # Raised for a well-formed value that breaks a rule a person can trip in a
  # form, such as a cap or an allowlist, so it answers 422 instead of 400. A
  # wrong type, a missing key or an unknown one stays a bad request.
  class UnprocessableParameter < InvalidParameter
    CODES = %i[too_long blank not_allowed].freeze

    def status
      :unprocessable_entity
    end
  end

  # Controllers without their own rescue_from answer through Rails' mapping,
  # which matches the exact class name, so a BadRequest subclass would be a 500.
  if defined?(ActionDispatch::ExceptionWrapper)
    ActionDispatch::ExceptionWrapper.rescue_responses.merge!(
      "ActiveTypedParams::InvalidParameter" => :bad_request,
      "ActiveTypedParams::UnprocessableParameter" => :unprocessable_entity,
    )
  end
end
