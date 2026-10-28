# frozen_string_literal: true

module ActiveTypedParams
  module EnumAdapter
  module_function

    def resolve(source)
      map = lookup(source)
      raise SchemaError, "no enum adapter handles #{source.inspect}" unless map

      map.each_with_object({}) { |(raw, cast), result|
        result[raw] = cast
        result[raw.to_s] = cast
      }.freeze
    end

    def lookup(source)
      ActiveTypedParams.config.enum_adapters.lazy.map { |adapter| adapter.call(source) }.find(&:itself) || builtin(source)
    end

    def builtin(source)
      case source
      when Array, Set then source.to_h { |value| [value, value] }
      when Hash then source
      end
    end
  end
end
