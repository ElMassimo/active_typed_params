# frozen_string_literal: true

module ActiveTypedParams
  # Adds `typed_params` to a controller (or a concern). The declared method is
  # a stub until its first call, which compiles the schema and replaces it.
  module Controller
    def self.included(base)
      base.extend(ClassMethods)
    end

    def typed_params
      Inline.new(self)
    end
    private :typed_params

    module ClassMethods
      def typed_params(name, **options, &block)
        schema = Schema.new(owner: self, name:, options:, block:)
        ActiveTypedParams.register(schema)
        stub = Module.new
        stub.define_method(name) { schema.call(self) }
        stub.send(:private, name)
        include stub

        schema
      end
    end
  end
end
