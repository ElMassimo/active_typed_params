# frozen_string_literal: true

module ActiveTypedParams
  class Builder
    PRESENCE_OPTIONS = %i[required optional].freeze
    COMMON_OPTIONS = (%i[allow_nil default allow_if allow_unless as invalid] + PRESENCE_OPTIONS).freeze
    OPTIONS = {
      string: COMMON_OPTIONS + %i[allow_blank in max_length],
      integer: COMMON_OPTIONS + %i[in],
      id: COMMON_OPTIONS + %i[bytes],
      decimal: COMMON_OPTIONS + %i[in],
      float: COMMON_OPTIONS + %i[in],
      boolean: COMMON_OPTIONS,
      date: COMMON_OPTIONS + %i[in],
      time: COMMON_OPTIONS + %i[in],
      enum: COMMON_OPTIONS,
      file: COMMON_OPTIONS,
      any: COMMON_OPTIONS,
      hash: COMMON_OPTIONS + %i[json open],
      array: COMMON_OPTIONS + %i[json max_length],
      map: COMMON_OPTIONS + %i[json max_length keys],
      one_of: COMMON_OPTIONS,
    }.freeze
    ITEM_UNSUPPORTED_OPTIONS = %i[default allow_if allow_unless as invalid].freeze
    INVALID_MODES = %i[raise drop].freeze
    MAP_KEY_TYPES = %i[string id integer].freeze
    DEFAULT_STRING_MAX_LENGTH = 512
    DEFAULT_COLLECTION_MAX_LENGTH = 1_000
    ID_BYTES = [4, 8].freeze

    # Shared by the builders of one schema: the owner `use` looks schemas up
    # on, and the nameless declarations not yet given to a key.
    Scope = Struct.new(:owner, :described) do
      def initialize(owner = nil)
        super(owner, {}.compare_by_identity)
      end
    end

    def self.run(block, required: false, owner: nil)
      builder = new(required:, scope: Scope.new(owner))
      builder.instance_exec(&block)
      builder.send(:check_described)
      builder.nodes
    end

    def initialize(required: false, scope: Scope.new)
      @nodes = {}
      @required = required
      @scope = scope
    end

    def nodes
      @nodes.values.freeze
    end

    def required(*names, **pairs, &block)
      with_presence(true) do
        param(*names, **pairs)
        instance_exec(&block) if block
      end
    end

    def optional(*names, **pairs, &block)
      with_presence(false) do
        param(*names, **pairs)
        instance_exec(&block) if block
      end
    end

    def param(*names, **pairs)
      consume(pairs)
      names.each { |name| string(name) }
      pairs.each { |name, value| apply_declaration(name, Declaration.from_literal(value)) }
    end

    (SCALAR_TYPES - [:enum] + [:any]).each do |type|
      define_method(type) do |*names, **options|
        names.empty? ? describe(type, options) : declare(type, names, options)
      end
    end

    def text(*names, **options)
      string(*names, max_length: ActiveTypedParams.config.text_max_length, **options)
    end

    def direct_upload(*names, **options)
      string(*names, invalid: :drop, **options)
    end

    def enum(*args, **options)
      if args.empty? || (args.size == 1 && args.first.is_a?(Symbol))
        raise SchemaError, "enum #{args.first.inspect} needs its values or class, as in `enum :status, Status`"
      end

      *names, source = args
      raise SchemaError, "no enum adapter handles #{source.inspect}" unless EnumAdapter.lookup(source)

      names.empty? ? describe(:enum, options, source:) : declare(:enum, names, options, enum_map: EnumAdapter.resolve(source))
    end

    # Without a block, several symbols or a `key: type` pair are the fields of
    # a nameless hash, as in `hash(:name, role: Role)`. A lone symbol names the
    # hash, and a field named like a hash option needs a `{}` literal.
    def hash(*args, **rest, &block)
      consume([args, rest])
      raise SchemaError, "hash #{args.inspect} takes its fields as arguments; declare a named list as `key: [...]`" if args.any?(Array)

      options, fields = rest.partition { |key, _| OPTIONS[:hash].include?(key) }.map(&:to_h)
      if block.nil? && (args.size > 1 || fields.any?)
        return describe(:hash, options, children: Declaration.from_list(fields.any? ? [*args, fields] : args).children)
      end
      raise SchemaError, "hash #{args.inspect} declares one key at a time" if args.size > 1
      raise SchemaError, "hash #{args.inspect} needs a block or open: true" if block.nil? && !rest[:open]

      args.empty? ? describe(:hash, rest, children: [], block:) : declare(:hash, args, rest, children: block ? children_from(block) : [])
    end

    # A lone type symbol, declaration or list describes an array; anything
    # else names one, so a key named like a type needs an explicit item type.
    def array(*positional, **rest, &block)
      consume([positional, rest])
      options, extras = rest.partition { |key, _| OPTIONS[:array].include?(key) }.map(&:to_h)
      nameless = positional.empty? || (positional.size == 1 && block.nil? && extras.empty? && item_literal?(positional.first))
      name = positional.shift unless nameless
      label = name ? name.inspect : "literal"
      raise SchemaError, "array #{label} needs a symbol name" unless name.nil? || name.is_a?(Symbol)
      raise SchemaError, "array #{label} takes one item type" if positional.size > 1

      item = array_item(label, positional.first, extras, block)
      name ? declare(:array, [name], options, item: item_node(item)) : describe(:array, options, item:)
    end

    # A hash keyed by data rather than names, such as preferences by requester
    # id: `map(:prefs, [email: :boolean], keys: :id)`, or nameless as a value.
    # Keys are cast to `keys:` (string, id or integer) and stay as data, so
    # they are not symbolized.
    def map(*positional, **options)
      consume([positional, options])
      raise SchemaError, "map takes a value type, after a name when it declares a key" unless [1, 2].include?(positional.size)

      *names, value = positional
      raise SchemaError, "map #{names.first.inspect} needs a symbol name" unless names.all?(Symbol)

      item = Declaration.from_literal(value)
      names.empty? ? describe(:map, options, item:) : declare(:map, names, options, item: item_node(item))
    end

    # A value of one of several types, picked by its JSON type without
    # converting between them, as in `one_of(:string, array(:string))`.
    def one_of(*alternatives, **options)
      consume([alternatives, options])
      alternatives = alternatives.map { |alternative| Declaration.from_literal(alternative) }
      json_types = alternatives.map { |alternative| JSON_TYPES.fetch(alternative.type) { raise SchemaError, "one_of cannot hold #{alternative.type}" } }
      raise SchemaError, "one_of needs two or more alternatives of different JSON types, got #{json_types.inspect}" if json_types.size < 2 || json_types.uniq.size < json_types.size

      describe(:one_of, options, children: alternatives.map { |alternative| [nil, alternative] })
    end

    # Merges the keys of another schema: a fragment, one declared with
    # typed_params on this controller or an ancestor, one on `owner`, or a
    # global definition.
    def use(*owner, name)
      schema = name.is_a?(Schema) ? name : ActiveTypedParams.find_schema(owner.first || @scope.owner, name)
      nodes = schema.root ? schema.nodes.first.children : schema.nodes
      nodes.each { |node| @nodes[node.key] = node }
    end

  private

    def with_presence(required)
      previous = @required
      @required = required
      yield
    ensure
      @required = previous
    end

    def describe(type, options, **node_options)
      required = presence_option(options)
      described(Declaration.build(type, required:, options: options.except(*PRESENCE_OPTIONS), **node_options))
    end

    def described(declaration)
      @scope.described[declaration] = true
      declaration
    end

    def consume(value)
      case value
      when Declaration
        @scope.described.delete(value)
        value.children&.each { |_, child| consume(child) }
        consume(value.item)
      when Hash then value.each_value { |child| consume(child) }
      when Array then value.each { |child| consume(child) }
      end
    end

    # A nameless declaration that no key received, such as `hash(:a, :b)` on
    # its own line, would otherwise vanish without declaring anything.
    def check_described
      declaration = @scope.described.keys.first
      return if declaration.nil?

      raise SchemaError, "a nameless #{declaration.type} was declared but given to no key; " \
        "pass it as a value, as in `key: #{declaration.type}(…)`, or name it, as in `#{declaration.type}(:key, …)`"
    end

    def child_builder
      Builder.new(required: @required, scope: @scope)
    end

    def declare(type, names, options, **node_options)
      raise SchemaError, "unknown type #{type.inspect}" unless TYPES.include?(type)

      explicit = presence_option(options)
      required = explicit.nil? ? @required : explicit
      options = validate_options(type, names, options.except(*PRESENCE_OPTIONS), required:)
      names.each do |name|
        node = Node.build(key: name, type:, required:, **options, **node_options)
        @nodes[node.key] = node
      end
    end

    def presence_option(options)
      if options.key?(:required) && options.key?(:optional)
        raise SchemaError, "required: and optional: cannot both be given"
      elsif options.key?(:required)
        options[:required]
      elsif options.key?(:optional)
        !options[:optional]
      end
    end

    def apply_declaration(name, declaration)
      declaration = Inference.from_attribute(declaration.source, name) if declaration.type == :attribute
      required = declaration.required.nil? ? @required : declaration.required
      with_presence(required) do
        case declaration.type
        when :hash then declare(:hash, [name], declaration.options, children: children_nodes(declaration))
        when :array then declare(:array, [name], declaration.options, item: item_node(declaration.item))
        when :map then declare(:map, [name], declaration.options, item: item_node(declaration.item))
        when :one_of then declare(:one_of, [name], declaration.options, children: declaration.children.map { |_, alternative| item_node(alternative) })
        when :enum then enum(name, declaration.source, **declaration.options)
        else declare(declaration.type, [name], declaration.options)
        end
      end
    end

    def children_from(block)
      child_builder.tap { |builder| builder.instance_exec(&block) }.nodes
    end

    # A block given to a nameless `hash` runs here, once the presence of the
    # declaration it belongs to is known.
    def children_nodes(declaration)
      return children_from(declaration.block) if declaration.block

      children = declaration.children || []
      return children if children.empty? || children.first.is_a?(Node)

      builder = child_builder
      children.each { |child_name, child| builder.send(:apply_declaration, child_name, child) }
      builder.nodes
    end

    def item_literal?(value)
      value.is_a?(Declaration) || value.is_a?(Array) || (value.is_a?(Symbol) && LITERAL_NAMES.include?(value))
    end

    def array_item(label, type, extras, block)
      if block
        raise SchemaError, "array #{label} takes either a block or an item type" if type || extras.any?

        item_from_block(label, block)
      elsif type.is_a?(Declaration)
        raise SchemaError, "array #{label} item options belong on the item declaration" if extras.any?

        type
      elsif type
        Declaration.from_literal(type).merge_options(extras)
      elsif extras.any?
        Declaration.from_list([extras])
      else
        raise SchemaError, "array #{label} needs an item type, key: type pairs or a block"
      end
    end

    def item_from_block(label, block)
      builder = child_builder
      item = builder.instance_exec(&block)
      consume(item)
      unless item.is_a?(Declaration) && builder.nodes.empty?
        raise SchemaError, "array #{label} block must return an item type, such as `hash do … end` or `string(allow_nil: true)`"
      end

      item
    end

    # An item is always present or nil, so it is built as required; `optional:`
    # on the item makes nil items valid, and the keys of an item hash take the
    # item's presence or the array's.
    def item_node(item)
      return item if item.is_a?(Node)
      raise SchemaError, "attribute_from reads the attribute named by its key, so it cannot describe an array item" if item.type == :attribute

      unsupported = item.options.keys & ITEM_UNSUPPORTED_OPTIONS
      raise SchemaError, "array items do not take #{unsupported.inspect}" if unsupported.any?

      options = item.options.dup
      options[:allow_nil] = true if item.required == false && !options.key?(:allow_nil)
      options[:allow_blank] = true if item.type == :string && !options.key?(:allow_blank)
      children_presence = item.required.nil? ? @required : item.required
      parts = case item.type
      when :hash then {children: with_presence(children_presence) { children_nodes(item) }}
      when :array, :map then {item: item_node(item.item)}
      when :one_of then {children: item.children.map { |_, alternative| item_node(alternative) }}
      when :enum then {enum_map: EnumAdapter.resolve(item.source)}
      else {}
      end
      Node.build(key: nil, type: item.type, required: true, **validate_options(item.type, [nil], options, required: true), **parts)
    end

    def map_key(label, type)
      raise SchemaError, "#{label} keys: must be one of #{MAP_KEY_TYPES.inspect}" unless MAP_KEY_TYPES.include?(type)

      Node.build(key: nil, type:, required: true, max_length: (DEFAULT_STRING_MAX_LENGTH if type == :string), bytes: (8 if type == :id))
    end

    def validate_options(type, names, options, required:)
      label = "#{type} #{names.map { |name| name || "item" }.inspect}"
      unknown = options.keys - OPTIONS.fetch(type)
      raise SchemaError, "#{label} does not accept #{unknown.inspect}" if unknown.any?
      raise SchemaError, "#{label} is required, so default: would never apply" if required && options.key?(:default)
      raise SchemaError, "#{label} takes allow_if: or allow_unless:, not both" if options.key?(:allow_if) && options.key?(:allow_unless)
      raise SchemaError, "#{label} invalid: must be one of #{INVALID_MODES.inspect}" unless INVALID_MODES.include?(options.fetch(:invalid, :raise))
      raise SchemaError, "#{label} is required, so invalid: :drop would leave it missing" if required && options[:invalid] == :drop
      raise SchemaError, "#{label} bytes: must be 4 or 8" if type == :id && !ID_BYTES.include?(options.fetch(:bytes, 8))
      if options.key?(:in) && !options[:in].is_a?(Array) && !options[:in].is_a?(Set) && !options[:in].is_a?(Range) && !options[:in].is_a?(Proc)
        raise SchemaError, "#{label} in: must be an Array, Set, Range or Proc"
      end

      options = options.dup
      options[:condition] = [:if, options.delete(:allow_if)] if options.key?(:allow_if)
      options[:condition] = [:unless, options.delete(:allow_unless)] if options.key?(:allow_unless)
      # Optional keys accept null unless told otherwise; strings, arrays and maps are capped unless told otherwise.
      options[:allow_nil] = true if !required && !options.key?(:allow_nil)
      options[:max_length] = DEFAULT_STRING_MAX_LENGTH if type == :string && !options.key?(:max_length)
      options[:max_length] = DEFAULT_COLLECTION_MAX_LENGTH if (type == :array || type == :map) && !options.key?(:max_length)
      options[:bytes] = options.fetch(:bytes, 8) if type == :id
      options[:map_key] = map_key(label, options.delete(:keys) || :string) if type == :map
      options[:default] = Runtime.deep_freeze(options[:default]) if options.key?(:default) && !options[:default].is_a?(Proc)
      options[:in] = options[:in].to_set.freeze if options[:in].is_a?(Array)
      options
    end
  end
end
