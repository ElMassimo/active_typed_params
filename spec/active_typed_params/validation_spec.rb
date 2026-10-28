# frozen_string_literal: true

require "spec_helper"

RSpec.describe "typed_params validation", :active_typed_params do
  include ActiveTypedParamsSpec::Helpers

  let(:json) { ActiveTypedParamsSpec.json_request }
  let(:form) { ActiveTypedParamsSpec.form_request }
  let(:query) { ActiveTypedParamsSpec.query_request }

  describe "presence" do
    it "distinguishes omitted, null and blank for required keys" do
      expect(failure({}) { string :name }).to eq([:missing, ["name"]])
      expect(failure({name: nil}) { string :name }).to eq([:missing, ["name"]])
      expect(failure({name: ""}) { string :name }).to eq([:blank, ["name"]])
      expect(validate({name: ""}) { string :name, allow_blank: true }).to eq(name: "")
      expect(validate({name: nil}) { string :name, allow_nil: true }).to eq(name: nil)
      expect(validate({name: "Max"}) { string :name }).to eq(name: "Max")
    end

    it "distinguishes omitted, null and blank for optional keys" do
      expect(validate({}) { optional { string :name } }).to eq({})
      expect(validate({}) { optional { string :name, default: "anon" } }).to eq(name: "anon")
      expect(validate({name: nil}) { optional { string :name } }).to eq(name: nil)
      expect(validate({name: nil}) { optional { string :name, default: "anon" } }).to eq(name: nil)
      expect(failure({name: nil}) { optional { string :name, allow_nil: false } }).to eq([:invalid_type, ["name"]])
      expect(validate({name: ""}) { optional { string :name } }).to eq(name: "")
    end

    it "reads an empty string as null for every scalar but strings, as a cleared form input sends it" do
      schema = proc {
        optional {
          integer :count
          id :owner_id
          decimal :price
          boolean :active
          date :starts_on
          time :starts_at
          enum :mode, %w[a b]
          array(:ids) { id allow_nil: true }
        }
      }
      blank = {count: "", owner_id: "", price: "", active: "", starts_on: "", starts_at: "", mode: "", ids: ["1", ""]}

      expect(validate(blank, &schema)).to eq(count: nil, owner_id: nil, price: nil, active: nil, starts_on: nil, starts_at: nil, mode: nil, ids: [1, nil])
      expect(failure({count: ""}) { integer :count }).to eq([:missing, ["count"]])
      expect(failure({count: ""}) { integer :count, optional: true, allow_nil: false }).to eq([:invalid_type, ["count"]])
      expect(validate({mode: ""}) { enum :mode, {"" => :none, "a" => :a} }).to eq(mode: :none)
      expect(failure({ids: ["1", ""]}) { array :ids, :id }).to eq([:invalid_type, ["ids", 1]])
    end

    it "declares keys optional unless the schema, a block or the declaration says otherwise" do
      expect(validate({}, required: false) { string :name }).to eq({})
      expect(failure({}, required: false) { required(:name) }).to eq([:missing, ["name"]])
      expect(failure({}, required: false) { string :name, required: true }).to eq([:missing, ["name"]])
      expect(validate({}) { string :name, optional: true }).to eq({})
      expect(validate({user: {email: "a"}}, required: false) { required(user: [:email, nickname: string(optional: true)]) }).to eq(user: {email: "a"})
      expect(failure({user: {}}, required: false) { required(user: [:email]) }).to eq([:missing, ["user", "email"]])
    end
  end

  describe "strings" do
    it "rejects other JSON types, NUL bytes and oversized values" do
      expect(failure({name: 1}) { string :name }).to eq([:invalid_type, ["name"]])
      expect(failure({name: {"$ne" => 1}}) { string :name }).to eq([:invalid_type, ["name"]])
      expect(failure({name: ["a"]}) { string :name }).to eq([:invalid_type, ["name"]])
      expect(failure({name: true}) { string :name }).to eq([:invalid_type, ["name"]])
      expect(failure({name: "a\0b"}) { string :name }).to eq([:invalid_type, ["name"]])
      expect(failure({name: "a" * 513}) { string :name }).to eq([:too_long, ["name"]])
      expect(validate({name: "a" * 512}) { string :name }).to eq(name: "a" * 512)
      expect(failure({name: "abcde"}) { string :name, max_length: 4 }).to eq([:too_long, ["name"]])
      expect(validate({name: "a" * 600}) { string :name, max_length: 1000 }).to eq(name: "a" * 600)
    end

    it "applies allowlists" do
      expect(validate({mode: "a"}) { string :mode, in: %w[a b] }).to eq(mode: "a")
      expect(failure({mode: "c"}) { string :mode, in: %w[a b] }).to eq([:not_allowed, ["mode"]])
    end
  end

  describe "integers" do
    it "coerces digit strings in every request format" do
      expect(validate({n: 5}) { integer :n }).to eq(n: 5)
      expect(validate({n: -5}) { integer :n }).to eq(n: -5)
      expect(validate({n: "5"}) { integer :n }).to eq(n: 5)
      expect(validate({n: "-5"}) { integer :n }).to eq(n: -5)
      expect(validate({n: "5"}, request: form) { integer :n }).to eq(n: 5)
      expect(validate({n: "5"}, request: query) { integer :n }).to eq(n: 5)
      expect(validate({n: "5"}, request: nil) { integer :n }).to eq(n: 5)
    end

    it "accepts only exact integer formats within 64 bits" do
      expect(failure({n: 1.5}) { integer :n }).to eq([:invalid_type, ["n"]])
      expect(failure({n: 1.0}) { integer :n }).to eq([:invalid_type, ["n"]])
      expect(failure({n: true}) { integer :n }).to eq([:invalid_type, ["n"]])
      expect(failure({n: "1e3"}) { integer :n }).to eq([:invalid_type, ["n"]])
      expect(failure({n: "1.0"}) { integer :n }).to eq([:invalid_type, ["n"]])
      expect(failure({n: " 1"}) { integer :n }).to eq([:invalid_type, ["n"]])
      expect(failure({n: 2**63}) { integer :n }).to eq([:invalid_type, ["n"]])
      expect(failure({n: "9" * 30}) { integer :n }).to eq([:invalid_type, ["n"]])
      expect(validate({n: 2**63 - 1}) { integer :n }).to eq(n: 2**63 - 1)
      expect(validate({n: -2**63}) { integer :n }).to eq(n: -2**63)
    end

    it "applies ranges, sets and procs evaluated on the controller" do
      expect(validate({n: 10}) { integer :n, in: 1..10 }).to eq(n: 10)
      expect(failure({n: 11}) { integer :n, in: 1..10 }).to eq([:not_allowed, ["n"]])
      expect(failure({n: 3}) { integer :n, in: [1, 2] }).to eq([:not_allowed, ["n"]])
      expect(validate({n: 50}) { integer :n, in: -> { 1..max_page_size } }).to eq(n: 50)
      expect(failure({n: 51}) { integer :n, in: -> { 1..max_page_size } }).to eq([:not_allowed, ["n"]])
    end
  end

  describe "ids" do
    it "accepts positive integers that fit the column" do
      expect(validate({id: 1}) { id :id }).to eq(id: 1)
      expect(validate({id: 2**63 - 1}) { id :id }).to eq(id: 2**63 - 1)
      expect(validate({id: 2**31 - 1}) { id :id, bytes: 4 }).to eq(id: 2**31 - 1)
      expect(failure({id: 2**31}) { id :id, bytes: 4 }).to eq([:invalid_type, ["id"]])
      expect(failure({id: 2**63}) { id :id }).to eq([:invalid_type, ["id"]])
      expect(failure({id: 0}) { id :id }).to eq([:invalid_type, ["id"]])
      expect(failure({id: -1}) { id :id }).to eq([:invalid_type, ["id"]])
      expect(failure({id: 1.0}) { id :id }).to eq([:invalid_type, ["id"]])
      expect(validate({id: "7"}) { id :id }).to eq(id: 7)
      expect(failure({id: "x"}) { id :id }).to eq([:invalid_type, ["id"]])
      expect(validate({id: "7"}, request: form) { id :id }).to eq(id: 7)
      expect(validate({id: "07"}, request: form) { id :id }).to eq(id: 7)
    end
  end

  describe "decimals and floats" do
    it "converts numerics and numeric strings, rejecting non-finite and malformed values" do
      expect(validate({a: 1}) { decimal :a }).to eq(a: BigDecimal(1))
      expect(validate({a: 1.5}) { decimal :a }).to eq(a: BigDecimal("1.5"))
      expect(validate({a: "1.50"}) { decimal :a }).to eq(a: BigDecimal("1.5"))
      expect(validate({a: "1.50"}, request: form) { decimal :a }).to eq(a: BigDecimal("1.5"))
      expect(failure({a: "1e3"}) { decimal :a }).to eq([:invalid_type, ["a"]])
      expect(failure({a: "abc"}) { decimal :a }).to eq([:invalid_type, ["a"]])
      expect(failure({a: Float::INFINITY}) { decimal :a }).to eq([:invalid_type, ["a"]])
      expect(failure({a: true}) { decimal :a }).to eq([:invalid_type, ["a"]])
      expect(validate({a: BigDecimal("2.25")}) { decimal :a }).to eq(a: BigDecimal("2.25"))
      expect(failure({a: 11}) { decimal :a, in: 1..10 }).to eq([:not_allowed, ["a"]])

      expect(validate({f: 1}) { float :f }).to eq(f: 1.0)
      expect(validate({f: 2.5}) { float :f }).to eq(f: 2.5)
      expect(validate({f: "2.5"}) { float :f }).to eq(f: 2.5)
      expect(validate({f: "1e3"}) { float :f }).to eq(f: 1000.0)
      expect(failure({f: Float::NAN}) { float :f }).to eq([:invalid_type, ["f"]])
      expect(failure({f: "x"}) { float :f }).to eq([:invalid_type, ["f"]])
      expect(failure({f: "1e400"}) { float :f }).to eq([:invalid_type, ["f"]])
      expect(failure({f: 10**400}) { float :f }).to eq([:invalid_type, ["f"]])
    end
  end

  describe "booleans" do
    it "accepts booleans and the four string spellings" do
      expect(validate({b: true}) { boolean :b }).to eq(b: true)
      expect(validate({b: false}) { boolean :b }).to eq(b: false)
      expect(validate({b: "true"}) { boolean :b }).to eq(b: true)
      expect(validate({b: "false"}, request: form) { boolean :b }).to eq(b: false)
      expect(validate({b: "1"}, request: form) { boolean :b }).to eq(b: true)
      expect(validate({b: "0"}, request: form) { boolean :b }).to eq(b: false)
      expect(failure({b: "yes"}, request: form) { boolean :b }).to eq([:invalid_type, ["b"]])
      expect(failure({b: 1}) { boolean :b }).to eq([:invalid_type, ["b"]])
    end
  end

  describe "dates and times" do
    it "parses ISO 8601 strings only" do
      expect(validate({d: "2026-10-21"}) { date :d }).to eq(d: Date.new(2026, 10, 21))
      expect(failure({d: "2026-13-01"}) { date :d }).to eq([:invalid_type, ["d"]])
      expect(failure({d: "10/21/2026"}) { date :d }).to eq([:invalid_type, ["d"]])
      expect(failure({d: "2026-10-21T10:00:00Z"}) { date :d }).to eq([:invalid_type, ["d"]])
      expect(failure({d: 20261021}) { date :d }).to eq([:invalid_type, ["d"]])

      expect(validate({t: "2026-10-21T10:00:00Z"}) { time :t }).to eq(t: Time.utc(2026, 10, 21, 10))
      expect(failure({t: "soon"}) { time :t }).to eq([:invalid_type, ["t"]])
      expect(failure({t: "2026-10-21"}) { time :t }).to eq([:invalid_type, ["t"]])
      expect(failure({t: 1_700_000_000}) { time :t }).to eq([:invalid_type, ["t"]])
    end

    it "returns zone-aware times when Time.zone is set" do
      result = Time.use_zone("UTC") { validate({t: "2026-10-21T10:00:00-03:00"}) { time :t } }

      expect(result[:t]).to be_a(ActiveSupport::TimeWithZone)
      expect(result[:t]).to eq(Time.utc(2026, 10, 21, 13))
    end
  end

  describe "enums" do
    it "maps raw values through the adapter and rejects anything else" do
      expect(validate({m: "mail"}) { enum :m, %w[email mail] }).to eq(m: "mail")
      expect(failure({m: "fax"}) { enum :m, %w[email mail] }).to eq([:not_allowed, ["m"]])
      expect(failure({m: 1}) { enum :m, %w[email mail] }).to eq([:not_allowed, ["m"]])
      expect(failure({m: {}}) { enum :m, %w[email mail] }).to eq([:not_allowed, ["m"]])
      expect(validate({m: "x"}) { enum :m, {"x" => :X} }).to eq(m: :X)
      expect(validate({m: "none"}) { enum :m, {"none" => nil, "x" => :X} }).to eq(m: nil)
      expect(failure({m: "y"}) { enum :m, {"none" => nil, "x" => :X} }).to eq([:not_allowed, ["m"]])
      expect(validate({m: 2}) { enum :m, [1, 2] }).to eq(m: 2)
      expect(validate({m: "2"}, request: form) { enum :m, [1, 2] }).to eq(m: 2)
    end

    it "uses registered adapters for other classes" do
      klass = Class.new
      ActiveTypedParams.config.enum_adapters << ->(source) { {"up" => :UP, "down" => :DOWN} if source == klass }

      expect(validate({m: "up"}) { enum :m, klass }).to eq(m: :UP)
    end
  end

  describe "files" do
    it "accepts uploads only" do
      upload = Rack::Test::UploadedFile.new(__FILE__, "text/plain")

      expect(validate({f: upload}) { file :f }).to eq(f: upload)
      expect(failure({f: "data"}) { file :f }).to eq([:invalid_type, ["f"]])
    end
  end

  describe "any" do
    it "returns plain Ruby structures with symbol keys" do
      result = validate({blob: {a: [1, {b: "c"}], d: "e"}}) { any :blob }

      expect(result[:blob]).to eq(a: [1, {b: "c"}], d: "e")
      expect(result[:blob].class).to eq(Hash)
      expect(result[:blob][:a][1].class).to eq(Hash)
      expect(validate({blob: [1, "x"]}) { any :blob }).to eq(blob: [1, "x"])
      expect(validate({blob: "x"}) { any :blob }).to eq(blob: "x")
      expect(failure({blob: nil}) { optional { any :blob, allow_nil: false } }).to eq([:invalid_type, ["blob"]])
      expect(validate({blob: nil}) { optional { any :blob } }).to eq(blob: nil)
    end
  end

  describe "hashes" do
    it "validates nested keys with their path and rejects other shapes" do
      schema = proc {
        hash :delivery do
          string :street
          optional { id :address_id }
        end
      }

      expect(validate({delivery: {street: "s"}}, &schema)).to eq(delivery: {street: "s"})
      expect(validate({delivery: {street: "s", address_id: 3}}, &schema)).to eq(delivery: {street: "s", address_id: 3})
      expect(failure({delivery: {}}, &schema)).to eq([:missing, ["delivery", "street"]])
      expect(failure({delivery: {street: "s", address_id: "x"}}, &schema)).to eq([:invalid_type, ["delivery", "address_id"]])
      expect(failure({delivery: "s"}, &schema)).to eq([:invalid_type, ["delivery"]])
      expect(failure({delivery: ["s"]}, &schema)).to eq([:invalid_type, ["delivery"]])
      expect(failure({delivery: nil}, &schema)).to eq([:missing, ["delivery"]])
      expect(failure({}, &schema)).to eq([:missing, ["delivery"]])
      expect(validate({delivery: {}}) { hash(:delivery) { optional { string :street } } }).to eq(delivery: {})
    end

    it "keeps undeclared keys as plain values when open: true, still requiring an object" do
      schema = proc { hash(:meta, open: true) { optional { integer :version } } }

      result = validate({meta: {version: 2, theme: "dark", flags: {beta: [1]}}}, &schema)
      expect(result).to eq(meta: {version: 2, theme: "dark", flags: {beta: [1]}})
      expect(validate({meta: {}}, &schema)).to eq(meta: {})
      expect(failure({meta: {version: "x"}}, &schema)).to eq([:invalid_type, ["meta", "version"]])
      expect(failure({meta: "x"}, &schema)).to eq([:invalid_type, ["meta"]])
      expect(failure({meta: ["x"]}, &schema)).to eq([:invalid_type, ["meta"]])

      renamed = proc { hash(:meta, open: true) { optional { integer :count, as: :total } } }
      expect(validate({meta: {count: 1, total: {unexpected: true}}}, &renamed)).to eq(meta: {total: 1})
      expect(validate({meta: {total: {unexpected: true}}}, &renamed)).to eq(meta: {})
    end

    it "parses JSON strings when json: true" do
      schema = proc { hash(:sort, json: true) { string :id } }

      expect(validate({sort: '{"id":"name"}'}, &schema)).to eq(sort: {id: "name"})
      expect(validate({sort: {id: "name"}}, &schema)).to eq(sort: {id: "name"})
      expect(failure({sort: "{oops"}, &schema)).to eq([:invalid_type, ["sort"]])
      expect(failure({sort: "[]"}, &schema)).to eq([:invalid_type, ["sort"]])
      expect(failure({sort: '{"id":"n"}'}) { hash(:sort) { string :id } }).to eq([:invalid_type, ["sort"]])
    end

    it "still works after the controller accessed a nested key, which converts it to Parameters" do
      params = ActionController::Parameters.new(delivery: {street: "s"}, line_items: [{sku: "p"}])
      params[:delivery]
      params[:line_items]

      result = validate(params) {
        hash(:delivery) { string :street }
        array(:line_items) { hash { string :sku } }
      }

      expect(result).to eq(delivery: {street: "s"}, line_items: [{sku: "p"}])
    end
  end

  describe "arrays" do
    it "validates every item with its index in the path" do
      expect(validate({tags: []}) { array :tags, :string }).to eq(tags: [])
      expect(validate({tags: %w[a b]}) { array :tags, :string }).to eq(tags: %w[a b])
      expect(failure({tags: "a"}) { array :tags, :string }).to eq([:invalid_type, ["tags"]])
      expect(failure({tags: {a: 1}}) { array :tags, :string }).to eq([:invalid_type, ["tags"]])
      expect(failure({tags: ["a", 1]}) { array :tags, :string }).to eq([:invalid_type, ["tags", 1]])
      expect(failure({tags: ["a", nil]}) { array :tags, :string }).to eq([:invalid_type, ["tags", 1]])
      expect(validate({tags: ["a", ""]}) { array :tags, :string }).to eq(tags: ["a", ""])
      expect(failure({tags: ["a", ""]}) { array(:tags) { string allow_blank: false } }).to eq([:blank, ["tags", 1]])
      expect(validate({tags: ["a", nil]}) { array(:tags) { string allow_nil: true } }).to eq(tags: ["a", nil])
      expect(failure({tags: %w[a b c]}) { array :tags, :string, max_length: 2 }).to eq([:too_long, ["tags"]])
      expect(failure({ids: Array.new(1001, 1)}) { array :ids, :id }).to eq([:too_long, ["ids"]])
      expect(failure({prefs: Array.new(1001) { |i| [i.to_s, true] }.to_h}) { map :prefs, :boolean }).to eq([:too_long, ["prefs"]])
      expect(validate({ids: Array.new(1001, 1)}) { array :ids, :id, max_length: nil }).to eq(ids: Array.new(1001, 1))
      expect(validate({ids: [1, 2]}) { array :ids, :id, bytes: 4 }).to eq(ids: [1, 2])
      expect(failure({ids: [1, 2**31]}) { array :ids, :id, bytes: 4 }).to eq([:invalid_type, ["ids", 1]])
      expect(validate({ids: %w[1 2]}, request: query) { array :ids, :id }).to eq(ids: [1, 2])
    end

    it "validates arrays of objects and nested arrays with full paths" do
      schema = proc {
        array :line_items do
          hash do
            string :sku
            optional {
              array :engravings do
                hash do
                  float :x, required: true
                end
              end
            }
          end
        end
      }

      expect(validate({line_items: [{sku: "p", engravings: [{x: 1}]}]}, &schema)).to eq(line_items: [{sku: "p", engravings: [{x: 1.0}]}])
      expect(failure({line_items: [{sku: "p"}, {sku: 3}]}, &schema)).to eq([:invalid_type, ["line_items", 1, "sku"]])
      expect(failure({line_items: [{sku: "p", engravings: [{x: 1}, {x: "no"}]}]}, &schema)).to eq([:invalid_type, ["line_items", 0, "engravings", 1, "x"]])
      expect(failure({line_items: [{sku: "p", engravings: [{}]}]}, &schema)).to eq([:missing, ["line_items", 0, "engravings", 0, "x"]])
      expect(failure({line_items: ["p"]}, &schema)).to eq([:invalid_type, ["line_items", 0]])
    end

    it "parses JSON strings when json: true" do
      expect(validate({ids: "[1,2]"}) { array :ids, :integer, json: true }).to eq(ids: [1, 2])
      expect(failure({ids: "[1,"}) { array :ids, :integer, json: true }).to eq([:invalid_type, ["ids"]])
      expect(failure({ids: "{}"}) { array :ids, :integer, json: true }).to eq([:invalid_type, ["ids"]])
    end
  end

  describe "one_of" do
    it "picks the alternative by the value's JSON type, without converting between them" do
      schema = proc { optional(value: one_of(:string, :integer, array(one_of(:string, :boolean)))) }

      expect(validate({value: "a"}, &schema)).to eq(value: "a")
      expect(validate({value: 5}, &schema)).to eq(value: 5)
      expect(validate({value: ["a", true]}, &schema)).to eq(value: ["a", true])
      expect(validate({value: nil}, &schema)).to eq(value: nil)
      expect(failure({value: {a: 1}}, &schema)).to eq([:invalid_type, ["value"]])
      expect(failure({value: [["a"]]}, &schema)).to eq([:invalid_type, ["value", 0]])
      expect(failure({value: 1.5}, &schema)).to eq([:invalid_type, ["value"]])
      expect { ActiveTypedParams::Builder.run(proc { param(value: one_of(:string, :date)) }) }.to raise_error(ActiveTypedParams::SchemaError, /different JSON types/)
      expect { ActiveTypedParams::Builder.run(proc { param(value: one_of(:string, :any)) }) }.to raise_error(ActiveTypedParams::SchemaError, /cannot hold any/)
    end
  end

  describe "maps" do
    it "casts each key to the key type and validates each value, keeping the keys as data" do
      schema = proc { optional { map :prefs, [email: :boolean, sms: :boolean], keys: :id } }

      expect(validate({prefs: {"12" => {email: "true", sms: false}, "7" => {}}}, &schema)).to eq(prefs: {12 => {email: true, sms: false}, 7 => {}})
      expect(validate({prefs: {}}, &schema)).to eq(prefs: {})
      expect(failure({prefs: {"x" => {}}}, &schema)).to eq([:invalid_type, ["prefs", "x"]])
      expect(failure({prefs: {"12" => {email: "maybe"}}}, &schema)).to eq([:invalid_type, ["prefs", "12", "email"]])
      expect(failure({prefs: {"12" => nil}}, &schema)).to eq([:invalid_type, ["prefs", "12"]])
      expect(failure({prefs: [1]}, &schema)).to eq([:invalid_type, ["prefs"]])
      expect(validate({labels: {"a" => "x", "b" => nil}}) { param(labels: map(string(optional: true))) }).to eq(labels: {"a" => "x", "b" => nil})
      expect(failure({labels: {"a" => "b", "c" => "d"}}) { map :labels, :string, max_length: 1 }).to eq([:too_long, ["labels"]])
      expect { validate({}) { map :labels, :string, keys: :date } }.to raise_error(ActiveTypedParams::SchemaError, /keys/)
    end
  end

  describe "conditions, defaults and renaming" do
    it "treats keys whose condition is false as undeclared, without reporting them" do
      schema = proc {
        optional {
          array :roles, :string, allow_if: :admin?
          string :note, allow_unless: :admin?
          string :flag, allow_if: -> { admin? }
        }
      }
      disable = ->(controller) { controller.admin = false }

      reported = ActiveTypedParamsSpec.notifications("unknown_parameters.typed_params") do
        expect(validate({roles: ["a"], note: "n", flag: "f"}, unknown: :report, &schema)).to eq(roles: ["a"], flag: "f")
        expect(validate({roles: ["a"], note: "n", flag: "f"}, controller: disable, unknown: :report, &schema)).to eq(note: "n")
      end
      expect(reported).to eq([])
      expect(failure({roles: "a"}, &schema)).to eq([:invalid_type, ["roles"]])
    end

    it "applies defaults when the key is omitted, or null where null is not allowed, evaluating procs on the controller" do
      schema = proc {
        optional {
          integer :page, default: 1
          integer :size, default: -> { max_page_size }
          array :tags, :string, default: %w[a]
          string :mode, default: :fast, as: :speed
        }
      }

      expect(validate({}, &schema)).to eq(page: 1, size: 50, tags: ["a"], speed: :fast)
      expect(validate({page: 2, size: 3, tags: [], mode: "slow"}, &schema)).to eq(page: 2, size: 3, tags: [], speed: "slow")
      expect(validate({page: nil}, &schema)[:page]).to be_nil
      expect(validate({page: ""}) { optional { integer :page, default: 1, allow_nil: false } }).to eq(page: 1)
      expect(validate({page: nil}) { optional { integer :page, default: -> { max_page_size }, allow_nil: false } }).to eq(page: 50)
      expect(failure({page: "x"}, &schema)).to eq([:invalid_type, ["page"]])
      expect(validate({}, &schema)[:tags]).to be_frozen
    end
  end

  describe "root:" do
    it "validates the keys of one required hash and returns it, as require(:root).permit does" do
      schema = proc { optional { string :email, :name } }

      expect(validate({user: {email: "a"}, other: 1}, root: :user, unknown: :reject, &schema)).to eq(email: "a")
      expect(validate({user: {}}, root: :user, &schema)).to eq({})
      expect(failure({}, root: :user, &schema)).to eq([:missing, ["user"]])
      expect(failure({user: "a"}, root: :user, &schema)).to eq([:invalid_type, ["user"]])
      expect(failure({user: {email: 1}}, root: :user, &schema)).to eq([:invalid_type, ["user", "email"]])
      expect(failure({user: {junk: 1}}, root: :user, unknown: :reject, &schema)).to eq([:unknown, ["user", "junk"]])
      expect(failure({user: {}}, root: :user) { string :email }).to eq([:missing, ["user", "email"]])
    end
  end

  describe "source:" do
    it "validates what the proc returns on the controller, reading nothing for nil or an empty string" do
      source = -> { params.fetch(:contact, {}) }
      schema = proc { optional { string :name, :email } }

      expect(validate({contact: {name: "n"}, other: 1}, source:, unknown: :reject, &schema)).to eq(name: "n")
      expect(validate({}, source:, &schema)).to eq({})
      expect(validate({contact: nil}, source:, &schema)).to eq({})
      expect(validate({contact: ""}, source:, &schema)).to eq({})
      expect(failure({contact: "x"}, source:, &schema)).to eq([:invalid_type, []])
      expect(failure({contact: {name: 1}}, source:, &schema)).to eq([:invalid_type, ["name"]])
      expect(failure({contact: {junk: 1}}, source:, unknown: :reject, &schema)).to eq([:unknown, ["junk"]])
      expect { validate({contact: "x"}, source:, &schema) }.to raise_error(ActiveTypedParams::InvalidParameter, "params must be an object")
      expect { validate({}, source: :contact) { string :name } }.to raise_error(ActiveTypedParams::SchemaError, /proc/)
    end
  end

  describe "invalid: :drop" do
    it "omits a value of the wrong type, as strong parameters do, and still raises below the key" do
      schema = proc {
        optional {
          string :image, invalid: :drop
          integer :count, invalid: :drop, default: 1
          hash(:meta, invalid: :drop) { integer :size }
        }
      }

      expect(validate({image: "signed-id", count: 2}, &schema)).to eq(image: "signed-id", count: 2)
      expect(validate({image: {"id" => 1, "url" => "x"}, count: "many"}, &schema)).to eq(count: 1)
      expect(validate({image: nil}, &schema)).to eq(image: nil, count: 1)
      expect(validate({meta: "x"}, &schema)).to eq(count: 1)
      expect(failure({meta: {size: "big"}}, &schema)).to eq([:invalid_type, ["meta", "size"]])
      expect { validate({}) { string :image, invalid: :drop } }.to raise_error(ActiveTypedParams::SchemaError, /missing/)
    end

    it "reads a direct upload as a signed id, dropping the attachment object a form posts back, in every form" do
      schema = proc {
        optional {
          direct_upload :sku
          param(memo: :direct_upload, line_items: array([video: :direct_upload]))
        }
      }
      attachment = {"signed_id" => "signed-id", "url" => "/rails/active_storage/blobs/x"}

      expect(validate({sku: "signed-id", memo: nil, line_items: [{video: "other-id"}]}, &schema))
        .to eq(sku: "signed-id", memo: nil, line_items: [{video: "other-id"}])
      expect(validate({sku: attachment, memo: attachment, line_items: [{video: attachment}]}, &schema)).to eq(line_items: [{}])
    end
  end

  describe "unknown keys" do
    it "drops undeclared keys, reporting them with unknown: :report, never framework or route keys" do
      reported = ActiveTypedParamsSpec.notifications("unknown_parameters.typed_params") do
        result = validate({name: "a", junk: 1, controller: "x", action: "y", format: "json", authenticity_token: "t", _method: "put", id: "7", nested: {ok: 1, extra: 2}}, unknown: :report) {
          string :name
          optional { hash(:nested) { integer :ok } }
        }
        expect(result).to eq(name: "a", nested: {ok: 1})
      end

      expect(reported).to eq([
        {keys: ["nested.extra"], controller: nil, action: "show", request: ActiveTypedParamsSpec.json_request},
        {keys: ["junk"], controller: nil, action: "show", request: ActiveTypedParamsSpec.json_request},
      ])
    end

    it "rejects undeclared keys with unknown: :reject and reports nothing by default" do
      expect(failure({name: "a", junk: 1, id: "7", controller: "c"}, unknown: :reject) { string :name }).to eq([:unknown, ["junk"]])
      nested = failure({name: "a", nested: {extra: 1}}, unknown: :reject) {
        string :name
        hash(:nested) { optional { string :x } }
      }
      expect(nested).to eq([:unknown, ["nested", "extra"]])
      expect(validate({name: "a", id: "7", controller: "c"}, unknown: :reject) { string :name }).to eq(name: "a")

      reported = ActiveTypedParamsSpec.notifications("unknown_parameters.typed_params") do
        expect(validate({name: "a", junk: 1}) { string :name }).to eq(name: "a")
      end
      expect(reported).to eq([])
    end

    it "skips the key ParamsWrapper adds to a JSON body, and the root keys it copied when the schema reads it" do
      wrapping = ->(controller) { controller.define_singleton_method(:_wrapper_key) { "user" } }
      body = {name: "a", junk: 1, user: {name: "a", junk: 1}}

      expect(validate({name: "a", user: {name: "a"}}, controller: wrapping, unknown: :reject) { string :name }).to eq(name: "a")
      expect(failure(body, controller: wrapping, unknown: :reject) { hash(:user) { string :name } }).to eq([:unknown, ["user", "junk"]])
      expect(failure({name: "a", junk: 1}, unknown: :reject) { string :name }).to eq([:unknown, ["junk"]])
    end
  end

  describe "results and errors" do
    it "returns plain hashes in declaration order, built again on every call" do
      result = validate({b: "2", a: "1", nested: {y: "y", x: "x"}}) {
        string :a, :b
        hash :nested do
          string :x, :y
        end
      }

      expect(result.keys).to eq([:a, :b, :nested])
      expect(result[:nested].keys).to eq([:x, :y])
      expect(result).not_to be_frozen
      result[:extra] = true
      expect(result[:nested]).not_to be_frozen
    end

    it "raises a BadRequest naming the path, without echoing the value, and instruments it" do
      error = nil
      reported = ActiveTypedParamsSpec.notifications("invalid_parameters.typed_params") do
        validate({delivery: {address_id: "secret-probe"}}) { hash(:delivery) { id :address_id } }
      rescue ActiveTypedParams::InvalidParameter => error
      end

      expect(error).to be_a(ActionController::BadRequest)
      expect(error.message).to eq("delivery.address_id must be an id")
      expect(error.path).to eq(["delivery", "address_id"])
      expect(error.code).to eq(:invalid_type)
      expect(reported).to eq([{path: "delivery.address_id", code: :invalid_type, controller: nil, action: "show", request: ActiveTypedParamsSpec.json_request}])
      expect(failure({}) { string :name }).to eq([:missing, ["name"]])
    end

    it "answers 422 for a value that breaks a cap, presence or allowlist, and 400 for a malformed request" do
      raised = lambda do |params, **options, &schema|
        validate(params, **options, &schema)
        nil
      rescue ActiveTypedParams::InvalidParameter => error
        [error.class, error.status]
      end
      unprocessable = [ActiveTypedParams::UnprocessableParameter, :unprocessable_entity]
      bad_request = [ActiveTypedParams::InvalidParameter, :bad_request]

      expect(raised.call({name: "a" * 513}) { string :name }).to eq(unprocessable)
      expect(raised.call({name: ""}) { string :name }).to eq(unprocessable)
      expect(raised.call({mode: "c"}) { string :mode, in: %w[a b] }).to eq(unprocessable)
      expect(raised.call({name: 1}) { string :name }).to eq(bad_request)
      expect(raised.call({}) { string :name }).to eq(bad_request)
      expect(raised.call({name: "a", junk: 1}, unknown: :reject) { string :name }).to eq(bad_request)
      expect(ActiveTypedParams::UnprocessableParameter.new(:blank, ["name"])).to be_a(ActionController::BadRequest)
    end
  end
end
