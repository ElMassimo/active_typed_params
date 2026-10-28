# frozen_string_literal: true

require "spec_helper"

module ActiveTypedParamsSpec
  class SchemaGenerator
    SCALARS = %i[string integer id decimal float boolean date time enum].freeze
    ENUM_VALUES = %w[email mail text].freeze

    attr_reader :random

    def initialize(random)
      @random = random
    end

    def nodes(depth: 0, count: random.rand(1..4))
      Array.new(count) { |index| node("k#{index}", depth) }
    end

    def node(key, depth)
      type = pick(depth < 3 ? [*SCALARS, :hash, :array, :map, :any] : SCALARS)
      required = chance(0.5)
      options = {}
      options[:allow_nil] = true if chance(0.3)
      options[:as] = :"#{key}_renamed" if chance(0.1)
      options[:condition] = [pick(%i[if unless]), pick([:admin?, -> { admin? }])] if chance(0.15)
      options[:default] = default_for(type) if !required && chance(0.3)
      options[:invalid] = :drop if !required && chance(0.15)
      scalar_options!(type, options)
      case type
      when :hash
        options[:children] = nodes(depth: depth + 1, count: random.rand(0..3))
        options[:json] = true if chance(0.2)
        options[:open] = true if chance(0.2)
      when :array, :map
        item_type = pick(depth < 3 ? [*SCALARS, :hash] : SCALARS)
        item_options = {allow_nil: chance(0.3)}
        scalar_options!(item_type, item_options)
        item_options[:children] = nodes(depth: depth + 1, count: random.rand(0..2)) if item_type == :hash
        options[:item] = ActiveTypedParams::Node.build(key: nil, type: item_type, required: true, **item_options)
        options[:max_length] = random.rand(1..3) if chance(0.3)
        options[:json] = true if chance(0.2)
        options[:map_key] = map_key if type == :map
      end
      ActiveTypedParams::Node.build(key:, type:, required:, **options)
    end

    def scalar_options!(type, options)
      case type
      when :string
        options[:allow_blank] = true if chance(0.3)
        options[:max_length] = random.rand(1..6) if chance(0.3)
        options[:in] = Set["a", "b"] if chance(0.2)
      when :integer, :id
        options[:in] = pick([1..5, Set[1, 2], -> { 1..max_page_size }]) if type == :integer && chance(0.3)
        options[:bytes] = pick([4, 8]) if type == :id
      when :enum
        options[:enum_map] = ActiveTypedParams::EnumAdapter.resolve(ENUM_VALUES.to_h { |value| [value, value] }.merge("none" => nil))
      end
    end

    def map_key
      type = pick(%i[string id integer])
      ActiveTypedParams::Node.build(key: nil, type:, required: true, max_length: (512 if type == :string), bytes: (8 if type == :id))
    end

    def default_for(type)
      case type
      when :string then pick(["d", -> { "proc" }])
      when :integer, :id then pick([1, -> { max_page_size }])
      when :hash then {"k0" => "x"}
      when :array then ["x"]
      else "d"
      end
    end

    def payload(nodes)
      hash = {}
      nodes.each do |node|
        next if chance(0.2)

        hash[node.key] = chance(0.1) ? nil : value_for(node)
      end
      hash["extra"] = pick([1, "x", {"deep" => 1}]) if chance(0.2)
      hash
    end

    def value_for(node)
      return wrong_value if chance(0.15)

      case node.type
      when :string then pick(["", "a", "b", "hello", "a" * 7, "nul\0"])
      when :integer then pick([0, 1, 3, -2, "4", "x", "", 2**63, 1.5])
      when :id then pick([1, 7, 0, -1, "9", "", 2**31, 2**40, "x"])
      when :decimal then pick([1, 2.5, "3.25", "x", "", BigDecimal(4)])
      when :float then pick([1, 2.5, "3.25", "1e2", "x", ""])
      when :boolean then pick([true, false, "true", "0", "yes", ""])
      when :date then pick(["2026-10-21", "2026-99-01", "soon", ""])
      when :time then pick(["2026-10-21T10:00:00Z", "2026-10-21", "soon", ""])
      when :enum then pick([*ENUM_VALUES, "none", "fax", "", 1])
      when :any then pick([1, "x", {"a" => [1]}, [1, {"b" => 2}]])
      when :hash
        value = payload(node.children)
        (node.json && chance(0.5)) ? JSON.generate(value) : value
      when :array
        items = Array.new(random.rand(0..4)) { chance(0.1) ? nil : value_for(node.item) }
        (node.json && chance(0.5)) ? JSON.generate(items) : items
      when :map
        entries = Array.new(random.rand(0..3)) { [pick(%w[a 1 7 x 0]), chance(0.1) ? nil : value_for(node.item)] }.to_h
        (node.json && chance(0.5)) ? JSON.generate(entries) : entries
      end
    end

    def wrong_value
      pick([{"$ne" => 1}, [1], "str", 42, true, 1.5])
    end

    def pick(values)
      values[random.rand(values.size)]
    end

    def chance(probability)
      random.rand < probability
    end
  end
end

RSpec.describe "typed_params fuzzing", :active_typed_params do
  let(:seed) { Integer(ENV.fetch("FUZZ_SEED", "20261021")) }
  let(:iterations) { Integer(ENV.fetch("FUZZ_ITERATIONS", "2000")) }
  let(:context) { ActiveTypedParamsSpec::FakeController.new({}) }
  let(:current) { {} }

  it "returns only declared, well-typed values, or rejects with a declared path" do
    random = Random.new(seed)
    generator = ActiveTypedParamsSpec::SchemaGenerator.new(random)
    requests = [ActiveTypedParamsSpec.json_request, ActiveTypedParamsSpec.form_request]
    outcomes = Hash.new(0)

    iterations.times do |iteration|
      nodes = generator.nodes
      payload = generator.payload(nodes)
      case_details = "iteration #{iteration} (seed #{seed}) for #{payload.inspect}\nnodes: #{nodes.inspect}"
      result = nil
      current[:request] = generator.pick(requests)
      reported = ActiveTypedParamsSpec.notifications("unknown_parameters.typed_params") do
        result = ActiveTypedParamsSpec.run(params: payload, request: current[:request], nodes:, options: {unknown: :report})
      rescue ActiveTypedParams::InvalidParameter => error
        result = error
      rescue => error
        raise "#{case_details}\nraised #{error.class}: #{error.message}"
      end

      if result.is_a?(ActiveTypedParams::InvalidParameter)
        outcomes[:rejected] += 1
        expect(declared_path?(nodes, result.path)).to be(true), "#{case_details}\nrejected undeclared path #{result.path.inspect}"
      else
        outcomes[:accepted] += 1
        problems = []
        check_hash(nodes, payload, result, [], problems)
        expect(problems).to be_empty, "#{case_details}\nresult: #{result.inspect}\n#{problems.join("\n")}"
        expect(reported.flat_map { |report| report[:keys] }).to match_array(extra_paths(nodes, payload, [])), case_details
      end
    end

    expect(outcomes.values_at(:accepted, :rejected)).to all(be > iterations / 10)
  end

  def enabled?(node)
    return true if node.condition.nil?

    kind, predicate = node.condition
    outcome = predicate.is_a?(Proc) ? context.instance_exec(&predicate) : context.public_send(predicate)
    kind == :if ? outcome : !outcome
  end

  def check_hash(nodes, input, result, path, problems, open: false)
    dropped = nodes.select { |node| enabled?(node) && node.invalid == :drop && input.key?(node.key) && dropped?(node, input[node.key]) }
    expected_keys = nodes.select { |node| enabled?(node) && ((input.key?(node.key) && !dropped.include?(node)) || node.default?) }.map(&:result_key)
    expected_keys |= (input.keys - nodes.map(&:key)).map(&:to_sym) if open
    problems << "#{path.inspect} returned #{result.keys.inspect}, expected #{expected_keys.inspect}" unless result.keys.sort == expected_keys.sort
    nodes.each do |node|
      next unless enabled?(node) && input.key?(node.key) && result.key?(node.result_key)

      if !node.allow_nil && node.default? && blank?(node, input[node.key])
        problems << "#{[*path, node.key].inspect} ignored its default for a blank value" unless result[node.result_key] == evaluated_default(node)
        next
      end

      if dropped.include?(node)
        problems << "#{[*path, node.key].inspect} kept a dropped value" unless result[node.result_key] == evaluated_default(node)
        next
      end

      check_value(node, input[node.key], result[node.result_key], [*path, node.key], problems)
    end
  end

  def check_value(node, raw, value, path, problems)
    if value.nil?
      nil_allowed = blank?(node, raw) ? node.allow_nil : node.type == :enum && node.enum_map[raw].nil?
      problems << "#{path.inspect} returned nil for #{raw.inspect}" unless nil_allowed
      return
    end

    raw = JSON.parse(raw) if node.json && raw.is_a?(String)
    valid = case node.type
    when :string then value == raw && (node.max_length.nil? || value.length <= node.max_length) && (node.in.nil? || node.in.include?(value))
    when :integer then value.is_a?(Integer) && value.bit_length < 64 && (node.in.nil? || Array(node.in.is_a?(Proc) ? context.instance_exec(&node.in) : node.in).include?(value))
    when :id then value.is_a?(Integer) && value.positive? && value.bit_length < node.bytes * 8
    when :decimal then value.is_a?(BigDecimal)
    when :float then value.is_a?(Float) && value.finite?
    when :boolean then value == true || value == false
    when :date then value.is_a?(Date)
    when :time then value.is_a?(Time) || value.is_a?(ActiveSupport::TimeWithZone)
    when :enum then node.enum_map.key?(raw) && node.enum_map[raw] == value
    when :any then value == ActiveTypedParams::Runtime.plain(raw)
    when :hash
      check_hash(node.children, raw, value, path, problems, open: node.open) if value.is_a?(Hash)
      value.is_a?(Hash)
    when :array
      valid_array = value.is_a?(Array) && value.size == raw.size && (node.max_length.nil? || value.size <= node.max_length)
      value.each_with_index { |item, index| check_value(node.item, raw[index], item, [*path, index], problems) } if valid_array
      valid_array
    when :map
      cast = raw.keys.index_with { |key| map_key_value(node.map_key, key) }
      valid_map = value.is_a?(Hash) && cast.values.none?(&:nil?) && value.keys.sort_by(&:to_s) == cast.values.sort_by(&:to_s) &&
        (node.max_length.nil? || value.size <= node.max_length)
      raw.each { |key, item| check_value(node.item, item, value[cast[key]], [*path, key], problems) } if valid_map
      valid_map
    end
    problems << "#{path.inspect} returned #{value.inspect} for #{raw.inspect}" unless valid
  end

  # A dropped key must be one the same declaration rejects at its own path.
  def dropped?(node, raw)
    strict = node.with(invalid: :raise, required: false, condition: nil, default: ActiveTypedParams::NO_DEFAULT)
    ActiveTypedParamsSpec.run(params: {node.key => raw}, request: current[:request], nodes: [strict], options: {unknown: :ignore})
    false
  rescue ActiveTypedParams::InvalidParameter => error
    error.code == :invalid_type && error.path == [node.key]
  end

  def map_key_value(key_node, raw)
    raw = raw.to_s
    case key_node.type
    when :string then raw unless raw.empty?
    when :integer then Integer(raw, 10) if raw.match?(/\A-?\d+\z/)
    when :id then Integer(raw, 10) if raw.match?(/\A\d+\z/) && Integer(raw, 10).positive?
    end
  end

  def evaluated_default(node)
    node.default.is_a?(Proc) ? context.instance_exec(&node.default) : node.default
  end

  def blank?(node, raw)
    raw.nil? || (raw == "" && ActiveTypedParams::Compiler::BLANK_AS_NIL.include?(node.type) && !(node.type == :enum && node.enum_map.key?("")))
  end

  def extra_paths(nodes, input, path, open: false)
    paths = open ? [] : (input.keys - nodes.map(&:key)).map { |key| [*path, key].join(".") }
    nodes.each do |node|
      next unless enabled?(node) && !blank?(node, input[node.key])
      next if node.invalid == :drop && dropped?(node, input[node.key])

      raw = node.json && input[node.key].is_a?(String) ? JSON.parse(input[node.key]) : input[node.key]
      if node.hash?
        paths.concat(extra_paths(node.children, raw, [*path, node.key], open: node.open))
      elsif node.array? && node.item.hash?
        raw.each_with_index { |item, index| paths.concat(extra_paths(node.item.children, item, [*path, node.key, index])) if item }
      elsif node.map? && node.item.hash?
        raw.each { |key, item| paths.concat(extra_paths(node.item.children, item, [*path, node.key, key])) if item }
      end
    end
    paths
  end

  def declared_path?(nodes, path)
    node = nil
    path.each do |segment|
      node = if node&.map? then node.item
      elsif segment.is_a?(Integer) then (node.item if node&.array?)
      else nodes&.find { |candidate| candidate.key == segment }
      end
      return false if node.nil?

      nodes = node.children
    end
    !node.nil?
  end
end
