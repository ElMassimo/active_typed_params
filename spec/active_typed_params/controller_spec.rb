# frozen_string_literal: true

require "spec_helper"

RSpec.describe ActiveTypedParams::Controller, :active_typed_params do
  let(:controller_class) do
    Class.new(ActiveTypedParamsSpec::FakeController) {
      typed_params(:user_params) {
        required(:email)
        param(count: :integer)
      }
    }
  end

  it "defines a private stub that compiles on first use and replaces itself with the generated method" do
    schema = ActiveTypedParams.schema(controller_class, :user_params)
    expect(controller_class.private_method_defined?(:user_params)).to be(true)
    expect(controller_class.instance_method(:user_params).owner).not_to eq(controller_class)
    expect(schema).not_to be_installed

    first = controller_class.new({email: "a", count: "2", extra: 1})
    result = first.send(:user_params)

    expect(result).to eq(email: "a", count: 2)
    expect(first.send(:user_params)).to eq(result)
    expect(first.send(:user_params)).not_to equal(result)
    expect(controller_class.new({email: "b"}).send(:user_params)).to eq(email: "b")
    expect(controller_class.private_method_defined?(:user_params)).to be(true)
    expect(controller_class.instance_method(:user_params).owner).to equal(schema.compiled_module)
    expect(schema.compiled_module.name).to eq("active_typed_params/#{schema.module_name}")
    expect(schema).to be_installed
    expect(ActiveTypedParams.source(controller_class, :user_params)).to start_with("# frozen_string_literal: true\ndef user_params(params = self.params, request = self.request)\n")
  end

  it "lets a subclass or the declaring class override the method and call super, before or after compilation" do
    subclass = Class.new(controller_class) {
      define_method(:user_params) { super().merge(role: "admin") }
    }
    same_class = Class.new(ActiveTypedParamsSpec::FakeController) {
      typed_params(:own_params) { required(:email) }
      define_method(:own_params) { super().merge(role: "owner") }
    }

    expect(subclass.new({email: "a"}).send(:user_params)).to eq(email: "a", role: "admin")
    expect(controller_class.new({email: "a"}).send(:user_params)).to eq(email: "a")
    expect(same_class.new({email: "a"}).send(:own_params)).to eq(email: "a", role: "owner")
    ActiveTypedParams.compile_all!
    expect(same_class.new({email: "b"}).send(:own_params)).to eq(email: "b", role: "owner")
  end

  it "never shares a compiled module between schemas whose procs capture different values" do
    paginated = ->(max) { Class.new(ActiveTypedParamsSpec::FakeController) { typed_params(:p) { optional { integer :size, in: -> { 1..max } } } } }
    small, large = paginated.call(10), paginated.call(100)

    expect(small.new({size: 5}).send(:p)).to eq(size: 5)
    expect(large.new({size: 50}).send(:p)).to eq(size: 50)
    expect { small.new({size: 50}).send(:p) }.to raise_error(ActiveTypedParams::InvalidParameter)
    expect(small.instance_method(:p).owner).not_to equal(large.instance_method(:p).owner)
  end

  it "compiles exactly once when several threads hit the stub at the same time" do
    allow(ActiveTypedParams::Compiler).to receive(:new).and_call_original
    results = Array.new(8) { |i| Thread.new { controller_class.new({email: "e#{i}"}).send(:user_params) } }.map(&:value)

    expect(results.map { |result| result.fetch(:email) }).to eq((0..7).map { |i| "e#{i}" })
    expect(ActiveTypedParams::Compiler).to have_received(:new).once
  end

  it "keeps the first result per instance with memoize: true" do
    klass = Class.new(ActiveTypedParamsSpec::FakeController) { typed_params(:memo_params, memoize: true) { required(:email) } }
    instance = klass.new({email: "a"})

    first = instance.send(:memo_params)
    expect(instance.send(:memo_params)).to equal(first)
    expect(klass.new({email: "b"}).send(:memo_params)).to eq(email: "b")
    expect { klass.new({}).send(:memo_params) }.to raise_error(ActiveTypedParams::InvalidParameter)
  end

  it "compiles a schema declared in a concern's included block once per includer, and lets a subclass redeclare it" do
    concern = Module.new do
      extend ActiveSupport::Concern

      included do
        typed_params(:page_params) { param(page: :integer, mode: enum(%w[fast slow])) }
      end
    end
    first = Class.new(ActiveTypedParamsSpec::FakeController) { include concern }
    second = Class.new(ActiveTypedParamsSpec::FakeController) { include concern }
    redeclared = Class.new(first) { typed_params(:page_params) { param(page: :integer, mode: enum(%w[fast slow])) } }

    expect(first.new({page: "2"}).send(:page_params)).to eq(page: 2)
    expect(second.new({page: "3", mode: "slow"}).send(:page_params)).to eq(page: 3, mode: "slow")
    expect(redeclared.new({page: "4"}).send(:page_params)).to eq(page: 4)
    expect(first.instance_method(:page_params).owner).not_to equal(second.instance_method(:page_params).owner)
    expect(redeclared.instance_method(:page_params).owner).to equal(ActiveTypedParams.schema(redeclared, :page_params).compiled_module)
  end

  it "validates params with a definition outside a controller, with or without a context" do
    definition = ActiveTypedParams.define(:search_request, unknown: :ignore) {
      param(:term, page: integer(default: 1), size: integer(in: -> { 1..max_page_size }))
    }
    context = ActiveTypedParamsSpec::FakeController.new({})

    expect(definition).to equal(ActiveTypedParams.definition(:search_request))
    expect(definition.validate({term: "shoes", page: "2", extra: 1})).to eq(term: "shoes", page: 2)
    expect(definition.validate({term: "shoes"}, request: ActiveTypedParamsSpec.json_request)).to eq(term: "shoes", page: 1)
    expect(definition.validate({size: 7}, context:)).to eq(page: 1, size: 7)
    expect { definition.validate({page: "x"}) }.to raise_error(ActiveTypedParams::InvalidParameter, "page must be an integer")
    reported = ActiveTypedParamsSpec.notifications("invalid_parameters.typed_params") do
      definition.validate({size: 99}, context:)
    rescue ActiveTypedParams::InvalidParameter
      nil
    end
    expect(reported).to eq([{path: "size", code: :not_allowed, controller: "ActiveTypedParamsSpec::FakeController", action: "show", request: ActiveTypedParamsSpec.json_request}])

    expect { ActiveTypedParams.define(:bad_request, strict: true) { param(:term) } }.to raise_error(ActiveTypedParams::SchemaError, /strict/)

    memoized = ActiveTypedParams.define(:memoized_request, memoize: true) { param(:term) }
    expect(memoized.validate({term: "a"})).to eq(term: "a")
    expect(memoized.validate({term: "b"})).to eq(term: "b")
  end

  it "merges a fragment with use and describes a schema's keys for snapshots" do
    address = ActiveTypedParams.fragment { param(:street, zip: :integer) }
    klass = Class.new(ActiveTypedParamsSpec::FakeController) {
      typed_params(:order_params) {
        required(:email)
        hash(:shipping) { use address }
        param(notes: :text, title: string(max_length: 80), raw: string(max_length: nil), items: array([:sku, quantity: :integer]), prefs: map(:boolean, keys: :id))
        param(meta: {}, ids: array(:id, max_length: 50), log: array(:any, max_length: nil))
      }
    }

    expect(klass.new({email: "a", shipping: {street: "s", zip: "1"}}).send(:order_params)).to eq(email: "a", shipping: {street: "s", zip: 1})
    expect(ActiveTypedParams.schema(klass, :order_params).describe).to eq(<<~TEXT.chomp)
      email: string
      shipping: hash?
        street: string?
        zip: integer?
      notes: text?
      title: string(80)?
      raw: string(uncapped)?
      items: array(hash)?
        sku: string?
        quantity: integer?
      prefs: map(id => boolean)?
      meta: hash(open)?
      ids: array(id, 50)?
      log: array(any, uncapped)?
    TEXT
    expect(ActiveTypedParams.schemas.map(&:name)).not_to include(:fragment)
  end

  it "merges a schema from the same controller, an ancestor or another controller with use" do
    base = Class.new(ActiveTypedParamsSpec::FakeController) {
      typed_params(:pricing_params) { param(:coupon, amount: :decimal) }
    }
    child = Class.new(base) {
      typed_params(:draft_params) {
        use :pricing_params
        param(:message)
      }
    }
    other = Class.new(ActiveTypedParamsSpec::FakeController) {
      typed_params(:item_params, root: :item) { param(:name) }
    }
    elsewhere = Class.new(ActiveTypedParamsSpec::FakeController) {
      typed_params(:list_params) { use other, :item_params }
    }

    expect(child.new({coupon: "x", amount: "2", message: "hi"}).send(:draft_params)).to eq(coupon: "x", amount: 2, message: "hi")
    expect(elsewhere.new({name: "n"}).send(:list_params)).to eq(name: "n")
  end

  it "compiles every registered schema with compile_all! and forgets them on unload!" do
    other = Class.new(ActiveTypedParamsSpec::FakeController) { typed_params(:other_params) { string :x } }
    schemas = [ActiveTypedParams.schema(controller_class, :user_params), ActiveTypedParams.schema(other, :other_params)]

    ActiveTypedParams.compile_all!

    expect(schemas).to all(be_installed)
    expect(ActiveTypedParams.schemas).to include(*schemas)
    ActiveTypedParams.unload!
    expect(ActiveTypedParams.schemas).to eq([])
    expect { ActiveTypedParams.schema(other, :other_params) }.to raise_error(ActiveTypedParams::SchemaError)
  end

  it "validates schema options when declared" do
    expect { Class.new(ActiveTypedParamsSpec::FakeController) { typed_params(:p, strict: true) { string :x } } }
      .to raise_error(ActiveTypedParams::SchemaError, /strict/)
    expect { Class.new(ActiveTypedParamsSpec::FakeController) { typed_params(:p, unknown: :explode) { string :x } } }
      .to raise_error(ActiveTypedParams::SchemaError, /unknown/)
    expect { Class.new(ActiveTypedParamsSpec::FakeController) { typed_params(:p) } }
      .to raise_error(ActiveTypedParams::SchemaError, /block/)
  end

  it "reports a schema that fails to build at install time, naming the declaration" do
    klass = Class.new(ActiveTypedParamsSpec::FakeController) { typed_params(:p) { integer :x, allow_blank: true } }

    expect { klass.new({}).send(:p) }.to raise_error(ActiveTypedParams::SchemaError, /integer \[:x\]/)
  end
end
