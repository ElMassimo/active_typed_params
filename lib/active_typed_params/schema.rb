# frozen_string_literal: true

module ActiveTypedParams
  class Schema
    OPTIONS = %i[unknown required memoize root source].freeze
    UNKNOWN_MODES = %i[ignore report reject].freeze
    MUTEX = Mutex.new

    attr_reader :owner, :name, :options, :compiled_module

    def initialize(name:, owner: nil, options: {}, block: nil, nodes: nil, module_name: nil)
      raise SchemaError, "typed_params #{name.inspect} needs a block" if block.nil? && nodes.nil?

      unknown = options.keys - OPTIONS
      raise SchemaError, "typed_params #{name.inspect} does not accept #{unknown.inspect}" if unknown.any?
      unless UNKNOWN_MODES.include?(options.fetch(:unknown, :ignore))
        raise SchemaError, "typed_params #{name.inspect} unknown: must be one of #{UNKNOWN_MODES.inspect}"
      end

      raise SchemaError, "typed_params #{name.inspect} source: must be a proc" if options.key?(:source) && !options[:source].is_a?(Proc)

      @owner = owner
      @name = name.to_sym
      @options = options.freeze
      @block = block
      @nodes = nodes&.freeze
      @module_name = module_name
    end

    # With `root:`, the block declares the keys of that required hash, as
    # `params.require(:root).permit(...)` does, and the result is the inner hash.
    def nodes
      @nodes ||= begin
        nodes = Builder.run(@block, required: options.fetch(:required, false), owner:)
        root ? [Node.build(key: root, type: :hash, required: true, children: nodes)] : nodes
      end
    end

    def root
      options[:root]&.to_sym
    end

    # A proc run on the controller for the params to validate, such as
    # `-> { params.fetch(:contact, {}) }`, instead of all of `params`.
    def params_source
      options[:source]
    end

    def unknown_mode
      options.fetch(:unknown, :ignore)
    end

    # One line per key with its type, nested keys indented and `?` marking an
    # optional key, so a snapshot shows what a request can set.
    def describe
      Schema.describe_nodes(nodes, 0).join("\n")
    end

    def self.describe_nodes(nodes, depth)
      nodes.flat_map { |node| ["#{"  " * depth}#{node.key}: #{describe_type(node)}#{"?" unless node.required}", *describe_children(node, depth + 1)] }
    end

    def self.describe_type(node)
      case node.type
      when :array then "array(#{describe_type(node.item)}#{describe_cap(node.max_length)})"
      when :map then "map(#{node.map_key.type} => #{describe_type(node.item)}#{describe_cap(node.max_length)})"
      when :hash then node.open ? "hash(open)" : "hash"
      when :one_of then "one_of(#{node.children.map { |alternative| describe_type(alternative) }.join(", ")})"
      when :string then describe_string(node.max_length)
      else node.type.to_s
      end
    end

    def self.describe_cap(max_length)
      case max_length
      when Builder::DEFAULT_COLLECTION_MAX_LENGTH then ""
      when nil then ", uncapped"
      else ", #{max_length}"
      end
    end

    def self.describe_string(max_length)
      case max_length
      when Builder::DEFAULT_STRING_MAX_LENGTH then "string"
      when ActiveTypedParams.config.text_max_length then "text"
      when nil then "string(uncapped)"
      else "string(#{max_length})"
      end
    end

    def self.describe_children(node, depth)
      holder = (node.array? || node.map?) ? node.item : node
      holder.hash? ? describe_nodes(holder.children, depth) : []
    end

    def memoize?
      options.fetch(:memoize, false)
    end

    def memo_ivar
      "@__typed_params_#{name}"
    end

    # Validates params outside a controller, as a definition owned by a plain
    # object does. Procs and conditions run on the context, which also names
    # the report.
    def validate(params, context: nil, request: nil)
      call(context || Object.new, params, request)
    end

    def source
      (@compiler || Compiler.new(self)).source
    end

    def installed?
      @installed
    end

    # Defines the real method on a module included in the owner after the stub
    # module, so it takes precedence over the stub while an override on the
    # owner or a subclass still reaches it with `super`.
    def install!
      return if @installed

      MUTEX.synchronize do
        return if @installed

        @compiled_module = compile
        @method = @compiled_module.instance_method(name)
        owner&.include(@compiled_module)
        @compiler = nil
        @installed = true
      end
    end

    # Runs the installed method on any object, bypassing an override on a
    # controller; a definition validates whatever params it is given.
    def call(context, *arguments)
      install!
      @method.bind_call(context, *arguments)
    end

    def request_available?
      return @request_available if defined?(@request_available)

      @request_available = case owner
      when nil then false
      when Class then owner.method_defined?(:request) || owner.private_method_defined?(:request)
      else true
      end
    end

    def module_name
      @module_name ||= begin
        base = owner.nil? ? "Definition" : (owner.name || "Anonymous_#{owner.object_id}")
        "#{base.gsub("::", "_")}__#{name}"
      end
    end

  private

    def compiler
      @compiler ||= Compiler.new(self)
    end

    def compile
      generated = compiler.source
      Module.new.tap do |mod|
        mod.set_temporary_name("active_typed_params/#{module_name}")
        compiler.constants.each { |constant, value| mod.const_set(constant, value) }
        mod.module_eval(generated, "active_typed_params/#{module_name}", 1)
        mod.send(:private, name)
      end
    end
  end
end
