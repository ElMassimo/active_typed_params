# frozen_string_literal: true

module ActiveTypedParams
  # Generates one straight-line Ruby method for a schema. Nested hashes are
  # inlined, arrays become loops, and allowlists, enum maps, procs and
  # non-literal defaults become constants on the module the method is defined in.
  class Compiler
    IDENTIFIER = /\A[a-z_][a-zA-Z0-9_]*[?!]?\z/
    RUNTIME = "ActiveTypedParams::Runtime"
    BLANK_AS_NIL = (SCALAR_TYPES - [:string]).freeze
    JSON_TESTS = {
      string: ->(value) { "#{value}.is_a?(String)" },
      number: ->(value) { "#{value}.is_a?(Integer) || #{value}.is_a?(Float)" },
      boolean: ->(value) { "#{value} == true || #{value} == false" },
      array: ->(value) { "#{value}.is_a?(Array)" },
      object: ->(value) { "#{RUNTIME}.unwrap_hash(#{value})" },
    }.freeze

    attr_reader :constants

    def initialize(schema)
      @schema = schema
      @constants = {}
      @counters = Hash.new(0)
      @lines = []
      @indent = 0
    end

    def source
      @source ||= generate
    end

  private

    attr_reader :schema

    # The magic comment keeps key lookups and literals from allocating per request.
    def generate
      emit "# frozen_string_literal: true"
      emit "def #{schema.name}(params = #{params_default}, request = #{request_default})"
      indented do
        emit "#{schema.memo_ivar} ||= begin" if schema.memoize?
        indented(schema.memoize? ? 1 : 0) do
          emit "h0 = #{RUNTIME}.#{schema.params_source ? "source_hash" : "raw"}(params)"
          emit "r0 = {}"
          emit "n0 = 0" if counting?
          schema.nodes.each { |node| compile_key(node, 0, []) }
          if schema.root
            emit "r0[#{schema.root.inspect}]"
          else
            compile_unknown_check("h0", schema.nodes, [], root: schema.params_source.nil?)
            emit "r0"
          end
        end
        emit "end" if schema.memoize?
      end
      emit "rescue ActiveTypedParams::InvalidParameter => error"
      indented do
        emit "#{RUNTIME}.report_invalid(error, self)"
        emit "raise"
      end
      emit "end"
      @lines.join("\n") << "\n"
    end

    def params_default
      schema.params_source ? "instance_exec(&#{constant("SOURCE", schema.params_source)})" : "self.params"
    end

    def request_default
      schema.request_available? ? "self.request" : "nil"
    end

    def compile_key(node, depth, path)
      key = node.key.inspect
      key_path = [*path, node.key]
      hash = "h#{depth}"
      result = "r#{depth}[#{node.result_key.inspect}]"
      value = "v#{depth}"

      with_condition(node) do
        emit "if #{hash}.key?(#{key})"
        indented do
          emit "n#{depth} += 1" if counting?
          emit "#{value} = #{hash}[#{key}]"
          with_drop(node, key_path, result) do
            emit "if #{nil_test(node, value)}"
            indented do
              if node.allow_nil
                emit "#{result} = nil"
              elsif node.default?
                emit "#{result} = #{default_expression(node.default)}"
              else
                emit fail_call(node.required ? :missing : :invalid_type, key_path, node.type)
              end
            end
            emit "else"
            indented { compile_value(node, value, depth, key_path, result) }
            emit "end"
          end
        end
        if node.required
          emit "else"
          indented { emit fail_call(:missing, key_path) }
        elsif node.default?
          emit "else"
          indented { emit "#{result} = #{default_expression(node.default)}" }
        end
        emit "end"
      end
    end

    def with_drop(node, path, result)
      return yield unless node.invalid == :drop

      emit "begin"
      indented { yield }
      emit "rescue ActiveTypedParams::InvalidParameter => error"
      indented do
        emit "raise unless error.code == :invalid_type && error.path == #{path_literal(path)}"
        emit "#{result} = #{default_expression(node.default)}" if node.default?
      end
      emit "end"
    end

    # Forms send an empty string for a cleared number, date, select or file
    # input, which ActiveModel and ActiveInteraction both read as nil.
    def nil_test(node, value)
      blank_is_nil = BLANK_AS_NIL.include?(node.type) && !(node.type == :enum && node.enum_map.key?(""))
      blank_is_nil ? "#{value}.nil? || #{value} == \"\"" : "#{value}.nil?"
    end

    def with_condition(node)
      if node.condition
        kind, predicate = node.condition
        test = predicate_expression(predicate)
        emit "if #{kind == :if ? test : "!#{test}"}"
        indented { yield }
        emit "end"
      else
        yield
      end
    end

    def predicate_expression(predicate)
      if predicate.is_a?(Proc)
        "instance_exec(&#{constant("PROC", predicate)})"
      elsif IDENTIFIER.match?(predicate.to_s)
        predicate.to_s
      else
        "__send__(#{predicate.to_sym.inspect})"
      end
    end

    def compile_value(node, value, depth, path, target)
      case node.type
      when :string then compile_string(node, value, path)
      when :integer then compile_integer(node, value, path)
      when :id then compile_id(node, value, path)
      when :decimal, :float, :boolean
        emit "#{value} = #{RUNTIME}.#{node.type}(#{value})"
        emit "#{fail_call(:invalid_type, path, node.type)} if #{value}.nil?"
        compile_allowed(node, value, path)
      when :date, :time
        emit "#{value} = #{RUNTIME}.#{node.type}(#{value})"
        emit "#{fail_call(:invalid_type, path, node.type)} if #{value}.nil?"
        compile_allowed(node, value, path)
      when :enum
        emit "#{value} = #{constant("ENUM", node.enum_map)}.fetch(#{value}) { #{fail_call(:not_allowed, path)} }"
      when :file
        emit "#{fail_call(:invalid_type, path, :file)} unless #{RUNTIME}.file?(#{value})"
      when :any
        emit "#{value} = #{RUNTIME}.plain(#{value})"
      when :hash
        compile_hash(node, value, depth, path, target)
        return
      when :array
        compile_array(node, value, depth, path, target)
        return
      when :map
        compile_map(node, value, depth, path, target)
        return
      when :one_of
        compile_one_of(node, value, depth, path, target)
        return
      end
      emit "#{target} = #{value}"
    end

    def compile_string(node, value, path)
      emit "#{fail_call(:invalid_type, path, :string)} unless #{value}.is_a?(String) && !#{value}.include?(\"\\0\")"
      emit "#{fail_call(:blank, path)} if #{value}.empty?" if node.required && !node.allow_blank
      emit "#{fail_call(:too_long, path)} if #{value}.length > #{node.max_length}" if node.max_length
      compile_allowed(node, value, path)
    end

    def compile_integer(node, value, path)
      emit "#{value} = #{RUNTIME}.integer(#{value}) if #{value}.is_a?(String)"
      emit "#{fail_call(:invalid_type, path, :integer)} unless #{value}.is_a?(Integer) && #{value}.bit_length < 64"
      compile_allowed(node, value, path)
    end

    def compile_id(node, value, path)
      emit "#{value} = #{RUNTIME}.integer(#{value}) if #{value}.is_a?(String)"
      limit = 2**(node.bytes * 8 - 1)
      emit "#{fail_call(:invalid_type, path, :id)} unless #{value}.is_a?(Integer) && #{value} > 0 && #{value} < #{limit}"
    end

    def compile_allowed(node, value, path)
      return if node.in.nil?

      test = case node.in
      when Proc then "#{RUNTIME}.allowed?(instance_exec(&#{constant("PROC", node.in)}), #{value})"
      when Range then "#{constant("RANGE", node.in)}.cover?(#{value})"
      else "#{constant("SET", node.in)}.include?(#{value})"
      end
      emit "#{fail_call(:not_allowed, path)} unless #{test}"
    end

    def compile_hash(node, value, depth, path, target)
      inner = depth + 1
      emit "#{value} = #{RUNTIME}.parse_json(#{value}, #{path_literal(path)}, :hash) if #{value}.is_a?(String)" if node.json
      emit "h#{inner} = #{RUNTIME}.unwrap_hash(#{value}) || #{fail_call(:invalid_type, path, :hash)}"
      emit "r#{inner} = {}"
      emit "n#{inner} = 0" if counting?
      node.children.each { |child| compile_key(child, inner, path) }
      if node.open
        declared = constant("KEYS", Set.new(node.children.flat_map { |child| [child.key, child.result_key.to_s] }).freeze)
        emit "h#{inner}.each { |k#{inner}, x#{inner}| r#{inner}[k#{inner}.to_sym] = #{RUNTIME}.plain(x#{inner}) unless #{declared}.include?(k#{inner}) }"
      else
        compile_unknown_check("h#{inner}", node.children, path, root: false)
      end
      emit "#{target} = r#{inner}"
    end

    def compile_array(node, value, depth, path, target)
      inner = depth + 1
      item = "e#{inner}"
      index = :"i#{inner}"
      item_path = [*path, index]
      emit "#{value} = #{RUNTIME}.parse_json(#{value}, #{path_literal(path)}, :array) if #{value}.is_a?(String)" if node.json
      emit "#{fail_call(:invalid_type, path, :array)} unless #{value}.is_a?(Array)"
      emit "#{fail_call(:too_long, path)} if #{value}.length > #{node.max_length}" if node.max_length
      emit "a#{inner} = Array.new(#{value}.length)"
      emit "#{value}.each_with_index do |#{item}, #{index}|"
      indented do
        emit "if #{nil_test(node.item, item)}"
        indented do
          if node.item.allow_nil
            emit "a#{inner}[#{index}] = nil"
          else
            emit fail_call(:invalid_type, item_path, node.item.type)
          end
        end
        emit "else"
        indented { compile_value(node.item, item, inner, item_path, "a#{inner}[#{index}]") }
        emit "end"
      end
      emit "end"
      emit "#{target} = a#{inner}"
    end

    def compile_one_of(node, value, depth, path, target)
      node.children.each_with_index do |alternative, index|
        emit "#{index.zero? ? "if" : "elsif"} #{JSON_TESTS.fetch(JSON_TYPES.fetch(alternative.type)).call(value)}"
        indented { compile_value(alternative, value, depth, path, target) }
      end
      emit "else"
      indented { emit fail_call(:invalid_type, path, :one_of) }
      emit "end"
    end

    # Each key is cast in place by the key node, so an error names the raw key.
    def compile_map(node, value, depth, path, target)
      inner = depth + 1
      raw_key = "q#{inner}"
      key = "k#{inner}"
      item = "e#{inner}"
      key_path = [*path, raw_key.to_sym]
      emit "#{value} = #{RUNTIME}.parse_json(#{value}, #{path_literal(path)}, :map) if #{value}.is_a?(String)" if node.json
      emit "h#{inner} = #{RUNTIME}.unwrap_hash(#{value}) || #{fail_call(:invalid_type, path, :map)}"
      emit "#{fail_call(:too_long, path)} if h#{inner}.size > #{node.max_length}" if node.max_length
      emit "r#{inner} = {}"
      emit "h#{inner}.each do |#{raw_key}, #{item}|"
      indented do
        emit "#{raw_key} = #{raw_key}.to_s"
        emit "#{key} = #{raw_key}"
        compile_value(node.map_key, key, inner, key_path, key)
        emit "if #{nil_test(node.item, item)}"
        indented do
          if node.item.allow_nil
            emit "r#{inner}[#{key}] = nil"
          else
            emit fail_call(:invalid_type, key_path, node.item.type)
          end
        end
        emit "else"
        indented { compile_value(node.item, item, inner, key_path, "r#{inner}[#{key}]") }
        emit "end"
      end
      emit "end"
      emit "#{target} = r#{inner}"
    end

    # A hash whose every key was matched holds nothing unknown, so the check
    # and its allocations are skipped on the common path.
    def compile_unknown_check(hash, nodes, path, root:)
      return unless counting?

      declared = constant("KEYS", Set.new(nodes.map(&:key)).freeze)
      request = root ? "request" : "nil"
      emit "#{RUNTIME}.check_unknown(#{hash}, #{declared}, #{schema.unknown_mode.inspect}, #{path_expression(path)}, self, #{request}) if #{hash}.size > n#{hash[1..]}"
    end

    def counting?
      schema.unknown_mode != :ignore
    end

    # A path inside an array carries index locals, so it is built when used;
    # a static one is a constant.
    def path_expression(path)
      path.any?(Symbol) ? path_literal(path) : constant("PATH", path.freeze)
    end

    def default_expression(default)
      case default
      when Proc then "instance_exec(&#{constant("PROC", default)})"
      when Integer, Float, String, Symbol, true, false, nil then default.inspect
      else constant("DEFAULT", default)
      end
    end

    def fail_call(code, path, type = nil)
      arguments = [code.inspect, path_literal(path), type&.inspect].compact.join(", ")
      "#{RUNTIME}.fail(#{arguments})"
    end

    def path_literal(path)
      "[#{path.map { |segment| segment.is_a?(Symbol) ? segment.to_s : segment.inspect }.join(", ")}]"
    end

    def constant(prefix, value)
      @counters[prefix] += 1
      name = "#{prefix}_#{@counters[prefix]}"
      @constants[name] = value
      name
    end

    def emit(line)
      @lines << ("  " * @indent) + line
    end

    def indented(levels = 1)
      @indent += levels
      yield
    ensure
      @indent -= levels
    end
  end
end
