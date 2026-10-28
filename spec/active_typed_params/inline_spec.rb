# frozen_string_literal: true

require "spec_helper"

module ActiveTypedParamsSpec
  class Role; end
end

RSpec.describe ActiveTypedParams::Inline, :active_typed_params do
  let(:controller_class) { Class.new(ActiveTypedParamsSpec::FakeController) }

  def inline(params, request: ActiveTypedParamsSpec.json_request)
    controller_class.new(params, request:).send(:typed_params)
  end

  before do
    ActiveTypedParams.config.enum_adapters << ->(source) { {"admin" => :ADMIN, "member" => :MEMBER} if source == ActiveTypedParamsSpec::Role }
  end

  it "returns the value for one key and a hash for several, with the same literal as a schema" do
    expect(inline({email: "a@b.c", extra: 1}).require(:email)).to eq("a@b.c")
    expect(inline({page: 2}).optional(page: :integer)).to eq(2)
    expect(inline({}).optional(page: :integer)).to be_nil
    expect(inline({page: nil}).optional(page: :integer)).to be_nil
    expect(inline({email: "a", name: "n", role: "admin"}).require(:email, name: :string, role: ActiveTypedParamsSpec::Role))
      .to eq(email: "a", name: "n", role: :ADMIN)
    expect(inline({user: {email: "a", tags: %w[x]}}).require(user: [:email, tags: ActiveTypedParams::Declaration.build(:array, item: ActiveTypedParams::Declaration.build(:string))]))
      .to eq(email: "a", tags: %w[x])
    expect(inline({meta: {any: [1]}}).optional(meta: {})).to eq(any: [1])
  end

  it "describes values with type helpers, and returns a hash from slice even for one key" do
    typed = inline({ids: ["1", "2"], note: "a" * 600, recipients: [{email: "a"}], role: "admin"})

    expect(typed.optional(ids: typed.array(:id))).to eq([1, 2])
    expect(typed.optional(note: typed.string(max_length: nil))).to eq("a" * 600)
    expect(typed.optional(note: typed.text)).to eq("a" * 600)
    expect(typed.optional(note: :text)).to eq("a" * 600)
    expect(typed.require(recipients: typed.array(typed.hash(:email, name: typed.string(optional: true))))).to eq([{email: "a"}])
    expect(typed.optional(role: typed.enum(ActiveTypedParamsSpec::Role))).to eq(:ADMIN)
    expect(typed.slice(:note, :missing, note: typed.string(max_length: nil))).to eq(note: "a" * 600)
    expect(inline({}).slice(:billing_note)).to eq({})
    expect(inline({billing_note: nil}).slice(:billing_note)).to eq(billing_note: nil)
  end

  it "expects a string by default and fails fast like a schema would" do
    expect { inline({email: 1}).require(:email) }.to raise_error(ActiveTypedParams::InvalidParameter, "email must be a string")
    expect { inline({}).require(:email) }.to raise_error(ActiveTypedParams::InvalidParameter, "email is required")
    expect { inline({email: ""}).require(:email) }.to raise_error(ActiveTypedParams::InvalidParameter, "email can't be blank")
    expect { inline({user: {email: nil}}).require(user: [:email]) }.to raise_error(ActiveTypedParams::InvalidParameter, "user.email is required")
    expect { inline({page: "x"}).optional(page: :integer) }.to raise_error(ActiveTypedParams::InvalidParameter, "page must be an integer")
    expect { inline({}).require }.to raise_error(ActiveTypedParams::SchemaError, /declares no keys/)
  end

  it "coerces digit strings, ignores unknown keys and reports invalid ones with the controller" do
    expect(inline({page: "2"}, request: ActiveTypedParamsSpec.query_request).optional(page: :integer)).to eq(2)
    expect(inline({page: "2"}).optional(page: :integer)).to eq(2)
    expect { inline({page: "2.0"}).optional(page: :integer) }.to raise_error(ActiveTypedParams::InvalidParameter)

    unknown = ActiveTypedParamsSpec.notifications("unknown_parameters.typed_params") { inline({email: "a", extra: 1}).require(:email) }
    expect(unknown).to eq([])
    invalid = ActiveTypedParamsSpec.notifications("invalid_parameters.typed_params") do
      inline({email: 1}).require(:email)
    rescue ActiveTypedParams::InvalidParameter
      nil
    end
    expect(invalid).to eq([{path: "email", code: :invalid_type, controller: nil, action: "show", request: ActiveTypedParamsSpec.json_request}])
  end

  it "compiles each distinct literal once, keyed by the literal, and refuses a proc it could not key" do
    allow(ActiveTypedParams::Compiler).to receive(:new).and_call_original

    3.times do |i|
      expect(inline({email: "e#{i}"}).require(:email)).to eq("e#{i}")
      expect(inline({page: 2}).optional(page: ActiveTypedParams::Declaration.build(:integer, options: {in: 1..3}))).to eq(2)
    end
    expect(inline({email: "x"}).require(email: :string)).to eq("x")
    expect(ActiveTypedParams::Compiler).to have_received(:new).exactly(3).times

    limited = ActiveTypedParams::Declaration.build(:integer, options: {in: -> { 1..3 }})
    expect { inline({page: 2}).optional(page: limited) }.to raise_error(ActiveTypedParams::SchemaError, /cannot hold a proc at "page"/)
    expect { inline({u: {page: 2}}).optional(u: [page: limited]) }.to raise_error(ActiveTypedParams::SchemaError, /"page"/)
    expect(ActiveTypedParams.send(:inline_schemas).size).to eq(3)

    ActiveTypedParams.unload!
    inline({email: "x"}).require(:email)
    expect(ActiveTypedParams::Compiler).to have_received(:new).exactly(4).times
  end
end
