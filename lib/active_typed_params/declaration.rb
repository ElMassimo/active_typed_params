# frozen_string_literal: true

module ActiveTypedParams
  # A declaration without a name: what a type method returns when called
  # without one, what a literal resolves to, and what inference produces.
  # `required` is nil when the declaration inherits its presence.
  #
  # Inline reads look their schema up by the declarations they are given on
  # every request, so unlike a Data, the hash is computed once when built.
  class Declaration
    attr_reader :type, :required, :options, :source, :children, :item, :block, :hash

    def self.build(type, required: nil, options: {}, source: nil, children: nil, item: nil, block: nil)
      new(type, required, options, source, children, item, block)
    end

    def initialize(type, required, options, source, children, item, block)
      @type = type
      @required = required
      @options = options
      @source = source
      @children = children
      @item = item
      @block = block
      @hash = [type, required, options, source, children, item, block].hash
      freeze
    end

    def eql?(other)
      equal?(other) || (other.instance_of?(Declaration) && hash == other.hash && type == other.type &&
        required == other.required && options == other.options && source == other.source &&
        children == other.children && item == other.item && block == other.block)
    end
    alias_method :==, :eql?

    def with(type: self.type, required: self.required, options: self.options, source: self.source, children: self.children, item: self.item, block: self.block)
      Declaration.new(type, required, options, source, children, item, block)
    end

    # A signed blob id replaces the file and null removes it; the attachment
    # object a form posts back for an unchanged file is dropped.
    def self.direct_upload(**options)
      build(:string, options: {invalid: :drop, **options})
    end

    def self.from_literal(value)
      case value
      when Declaration then value
      when Symbol
        raise SchemaError, "#{value.inspect} is not a type usable in a literal" unless LITERAL_NAMES.include?(value)

        case value
        when :text then build(:string, options: Inference.text_options)
        when :direct_upload then direct_upload
        else build(value)
        end
      when Array then from_list(value)
      when Hash then value.empty? ? build(:hash, options: {open: true}, children: []) : from_list([value])
      when Class, Module
        raise SchemaError, "no enum adapter handles #{value.inspect}" unless EnumAdapter.lookup(value)

        build(:enum, source: value)
      else
        raise SchemaError, "#{value.inspect} is not a type symbol, a declaration, a list, {} or an enum class"
      end
    end

    def self.from_list(list)
      raise SchemaError, "an empty list declares no keys; use {} for a hash of anything" if list.empty?

      pairs = list.last.is_a?(Hash) ? list.last : {}
      symbols = pairs.empty? ? list : list[0...-1]
      children = symbols.map { |name|
        raise SchemaError, "#{name.inspect} in a hash literal must be a symbol or key: type pair" unless name.is_a?(Symbol)

        [name, build(:string)]
      }
      children += pairs.map { |name, value| [name, from_literal(value)] }
      build(:hash, children:)
    end

    def optional(allow_nil: false)
      with(required: false, options: allow_nil ? options.merge(allow_nil: true) : options)
    end

    def merge_options(extra)
      with(options: options.merge(extra))
    end
  end
end
