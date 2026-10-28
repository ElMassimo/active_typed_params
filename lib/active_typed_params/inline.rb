# frozen_string_literal: true

module ActiveTypedParams
  # Each distinct declaration compiles once per process, keyed by the literal
  # itself. A proc would be a new object on every request and grow the cache
  # without bound, so a declaration holding one is rejected before it is cached.
  class Inline
    def self.reject_procs(nodes, label)
      nodes.each do |node|
        if [node.in, node.default, node.condition&.last].any?(Proc)
          raise SchemaError, "#{label} cannot hold a proc at #{node.key.inspect}; declare a schema instead"
        end

        reject_procs(node.children, label) if node.children
        reject_procs([node.item], label) if node.item
      end
    end

    def initialize(context)
      @context = context
    end

    def require(*names, **pairs)
      run(true, names, pairs)
    end

    def optional(*names, **pairs)
      run(false, names, pairs)
    end

    # The keys that were sent, as a Hash even for one key, so an update does
    # not clear an attribute the request left out.
    def slice(*names, **pairs)
      run(false, names, pairs, unwrap: false)
    end

    # Type helpers describe a value for `require`, `optional` and `slice`, as
    # in `typed_params.optional(ids: typed_params.array(:id))`. They run on
    # every request, before the cache lookup, so they build the declaration
    # directly; its options are validated when the schema is first built.
    LITERAL_TYPES.each do |type|
      define_method(type) { |**options| describe(type, options) }
    end

    def text(**options)
      describe(:string, Inference.text_options.merge(options))
    end

    def enum(source, **options)
      describe(:enum, options, source:)
    end

    def array(item, **options)
      describe(:array, options, item: Declaration.from_literal(item))
    end

    def map(value, **options)
      describe(:map, options, item: Declaration.from_literal(value))
    end

    def hash(*fields, **options)
      options, pairs = options.partition { |key, _| Builder::OPTIONS[:hash].include?(key) }.map(&:to_h)
      list = pairs.empty? ? fields : [*fields, pairs]
      describe(:hash, options, children: list.empty? && options[:open] ? [] : Declaration.from_list(list).children)
    end

  private

    attr_reader :context

    def describe(type, options, **parts)
      required = options.key?(:optional) ? !options[:optional] : options[:required]
      Declaration.build(type, required:, options: options.except(*Builder::PRESENCE_OPTIONS), **parts)
    end

    def run(required, names, pairs, unwrap: true)
      schema = ActiveTypedParams.inline_schema([required, names, pairs]) { build(required, names, pairs) }
      request = context.request if context.respond_to?(:request, true)
      result = schema.call(context, context.params, request)
      (unwrap && schema.nodes.size == 1) ? result[schema.nodes.first.result_key] : result
    end

    def build(required, names, pairs)
      builder = Builder.new
      required ? builder.required(*names, **pairs) : builder.optional(*names, **pairs)
      label = "typed_params.#{required ? "require" : "optional"}"
      nodes = builder.nodes
      raise SchemaError, "#{label} declares no keys" if nodes.empty?

      Inline.reject_procs(nodes, label)
      Schema.new(name: :inline, nodes:, module_name: "Inline__#{Digest::SHA256.hexdigest(nodes.inspect)[0, 12]}")
    end
  end
end
