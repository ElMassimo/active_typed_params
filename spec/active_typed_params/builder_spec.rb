# frozen_string_literal: true

require "spec_helper"

RSpec.describe ActiveTypedParams::Builder, :active_typed_params do
  def build(required: false, &block)
    described_class.run(block, required:)
  end

  def summarize(nodes)
    nodes.map { |node| [node.key, node.type, node.required, node.allow_nil] }
  end

  describe "the literal form" do
    it "declares bare symbols as strings and key: type pairs as that type, optional and nullable by default" do
      nodes = build {
        param(:email, count: :integer, active: :boolean)
      }

      expect(summarize(nodes)).to eq([["email", :string, false, true], ["count", :integer, false, true], ["active", :boolean, false, true]])
      expect(nodes.first.max_length).to eq(512)
    end

    it "takes the presence from required and optional, as arguments or blocks, and from the schema option" do
      nodes = build {
        required(:email, password: :string)
        optional(:nickname)
        required { string :token }
        param(:note)
      }
      expect(summarize(nodes)).to eq([
        ["email", :string, true, false],
        ["password", :string, true, false],
        ["nickname", :string, false, true],
        ["token", :string, true, false],
        ["note", :string, false, true],
      ])

      nodes = build(required: true) {
        param(:email)
        optional(:nickname)
        string :bio, optional: true
        string :legal, required: true
      }
      expect(summarize(nodes)).to eq([["email", :string, true, false], ["nickname", :string, false, true], ["bio", :string, false, true], ["legal", :string, true, false]])
    end

    it "resolves descriptors, enum classes, lists, open hashes and arrays" do
      nodes = build {
        optional(
          message: string(max_length: 5000),
          address_id: id(bytes: 4),
          method: %w[email mail].then { |values| enum(values) },
          delivery: [:street, zip: :string, days: array(:integer)],
          meta: {},
          line_items: array([:sku, engravings: array(key: string(required: true), x: :float)]),
          ids: array(id(bytes: 4)),
          card: hash(id: :string, json: true),
        )
      }
      by_key = nodes.index_by(&:key)

      expect(by_key["message"]).to have_attributes(type: :string, max_length: 5000, required: false, allow_nil: true)
      expect(by_key["address_id"]).to have_attributes(type: :id, bytes: 4)
      expect(by_key["method"].enum_map).to eq("email" => "email", "mail" => "mail")
      expect(summarize(by_key["delivery"].children)).to eq([["street", :string, false, true], ["zip", :string, false, true], ["days", :array, false, true]])
      expect(by_key["delivery"].children.last.item).to have_attributes(type: :integer, key: nil)
      expect(by_key["meta"]).to have_attributes(type: :hash, open: true, children: [])
      line_items = by_key["line_items"].item
      expect(summarize(line_items.children)).to eq([["sku", :string, false, true], ["engravings", :array, false, true]])
      expect(summarize(line_items.children.last.item.children)).to eq([["key", :string, true, false], ["x", :float, false, true]])
      expect(by_key["ids"].item).to have_attributes(type: :id, bytes: 4)
      expect(by_key["card"]).to have_attributes(json: true)
      expect(by_key["card"].children.map(&:key)).to eq(["id"])
    end

    it "lets nested keys inherit the presence of their declaration, in lists and in blocks alike" do
      nodes = build {
        required(delivery: [:street, address: [:zip]], card: hash { string :id }, line_items: array(hash { string :sku }))
        optional(contact: [:email], tags: array(:string))
      }
      by_key = nodes.index_by(&:key)

      expect(summarize(by_key["delivery"].children)).to eq([["street", :string, true, false], ["address", :hash, true, false]])
      expect(summarize(by_key["delivery"].children.last.children)).to eq([["zip", :string, true, false]])
      expect(summarize(by_key["card"].children)).to eq([["id", :string, true, false]])
      expect(summarize(by_key["line_items"].item.children)).to eq([["sku", :string, true, false]])
      expect(summarize(by_key["contact"].children)).to eq([["email", :string, false, true]])
      expect(by_key["tags"].item).to have_attributes(required: true, allow_nil: false)
    end

    it "applies optional: on an item to nil items and to the keys of an item hash, and required(…) inside an item block to its keys" do
      nodes = build {
        required(
          tags: array(string(optional: true)),
          line_items: array(hash(sku: :string, optional: true)),
          strict: array([:sku]),
        )
        param(
          engravings: array(hash { required(:key, x: :float) }),
          mixed: array(hash {
            required(:key)
            param(:note)
          }),
        )
      }
      by_key = nodes.index_by(&:key)

      expect(by_key["tags"].item).to have_attributes(required: true, allow_nil: true)
      expect(summarize(by_key["line_items"].item.children)).to eq([["sku", :string, false, true]])
      expect(summarize(by_key["strict"].item.children)).to eq([["sku", :string, true, false]])
      expect(summarize(by_key["engravings"].item.children)).to eq([["key", :string, true, false], ["x", :float, true, false]])
      expect(summarize(by_key["mixed"].item.children)).to eq([["key", :string, true, false], ["note", :string, false, true]])
    end

    it "reads hash fields given inline as a list, and still names a hash with a lone symbol" do
      inline = build(required: true) {
        array(:invites) { hash(:name, :email, role: enum(%w[admin member]), allow_nil: true) }
        optional(card: hash(id: :id), meta: hash(:version, :source, open: true))
        hash :settings, open: true
      }
      listed = build(required: true) {
        array(:invites) { hash(:name, :email, role: enum(%w[admin member]), allow_nil: true) }
        optional(card: hash(id: :id), meta: hash(:version, :source, open: true))
        hash :settings, open: true
      }

      expect(inline).to eq(listed)
      by_key = inline.index_by(&:key)
      expect(by_key["invites"].item).to have_attributes(allow_nil: true)
      expect(summarize(by_key["invites"].item.children)).to eq([["name", :string, true, false], ["email", :string, true, false], ["role", :enum, true, false]])
      expect(summarize(by_key["card"].children)).to eq([["id", :id, false, true]])
      expect(by_key["meta"]).to have_attributes(open: true, children: [have_attributes(key: "version"), have_attributes(key: "source")])
      expect(by_key["settings"]).to have_attributes(open: true, children: [])
    end

    it "declares text as a string with the text cap instead of the default one, in every form" do
      nodes = build {
        text :bio
        text :summary, max_length: 5000
        param(notes: :text, tags: array(:text), body: text(optional: true))
      }

      expect(nodes.map { |node| [node.key, node.type, node.max_length] }).to eq([
        ["bio", :string, 65_535], ["summary", :string, 5000], ["notes", :string, 65_535], ["tags", :array, 1000], ["body", :string, 65_535]
      ])
      expect(nodes[3].item.max_length).to eq(65_535)

      ActiveTypedParams.config.text_max_length = 30_000
      expect(build { text :bio }.first.max_length).to eq(30_000)
    end

    it "names arrays even when the name is also a type, as long as an item type follows" do
      nodes = build {
        array :id, :integer
        array :time, :string
        array :date do
          string
        end
        array :file, key: :string
      }

      expect(nodes.map(&:key)).to eq(%w[id time date file])
      expect(nodes.map { |node| node.item.type }).to eq(%i[integer string string hash])
      expect(build { param(ids: array(:id)) }.first.item.type).to eq(:id)
    end
  end

  describe "the method form" do
    it "declares the same nodes as the literal form" do
      literal = build { required(:email, delivery: [:street, zip: string(max_length: 10)], tags: array(:string)) }
      methods = build {
        required {
          string :email
          hash :delivery do
            string :street
            string :zip, max_length: 10
          end
          array :tags, :string
        }
      }

      expect(methods).to eq(literal)
    end

    it "keeps declaration order and replaces a redeclared key in place" do
      nodes = build {
        string :a, max_length: 10
        integer :c
        string :a, max_length: 20
      }

      expect(nodes.map(&:key)).to eq(%w[a c])
      expect(nodes.map(&:max_length)).to eq([20, nil])
    end

    it "records type-specific options on the node" do
      nodes = build {
        integer :count, in: [1, 2, 3], default: 1, as: :total
        id :small, bytes: 4
        string :mode, in: %w[a b], allow_blank: true, allow_if: :admin?
        decimal :amount, in: 1..10, allow_unless: :admin?
        enum :method, %w[email mail]
        enum :mapped, {"x" => :X}
        hash :address, json: true, allow_nil: false do
          string :street
        end
        array :tags, :string, max_length: 5
        array :line_items do
          hash do
            string :sku
          end
        end
        array :nullable_tags do
          string(allow_nil: true)
        end
        any :blob
      }
      by_key = nodes.index_by(&:key)

      expect(by_key["count"]).to have_attributes(type: :integer, in: Set[1, 2, 3], default: 1, as: :total)
      expect(by_key["count"].result_key).to eq(:total)
      expect(by_key["small"]).to have_attributes(bytes: 4)
      expect(by_key["mode"]).to have_attributes(in: Set["a", "b"], allow_blank: true, condition: [:if, :admin?])
      expect(by_key["amount"]).to have_attributes(in: 1..10, condition: [:unless, :admin?])
      expect(by_key["method"].enum_map).to eq("email" => "email", "mail" => "mail")
      expect(by_key["mapped"].enum_map).to eq("x" => :X)
      expect(by_key["address"]).to have_attributes(json: true, allow_nil: false)
      expect(by_key["address"].children.map(&:key)).to eq(["street"])
      expect(by_key["tags"]).to have_attributes(max_length: 5)
      expect(by_key["tags"].item).to have_attributes(key: nil, type: :string, max_length: 512, allow_nil: false)
      expect(by_key["line_items"].item.type).to eq(:hash)
      expect(by_key["line_items"].item.children.map(&:key)).to eq(["sku"])
      expect(by_key["nullable_tags"].item.allow_nil).to be(true)
      expect(by_key["blob"].type).to eq(:any)
    end

    it "freezes non-proc defaults and keeps procs as given" do
      callable = -> { [] }
      nodes = build {
        array :tags, :string, default: ["a"]
        hash :meta, default: {"a" => [1]} do
          string :x
        end
        integer :count, default: callable
      }

      expect(nodes[0].default).to be_frozen
      expect(nodes[1].default["a"]).to be_frozen
      expect(nodes[2].default).to equal(callable)
    end

    it "merges a defined schema with use, keeping each key's presence inside a required or optional block" do
      ActiveTypedParams.define(:pagination) {
        required(:page)
        integer :page_size
        hash :sort do
          string :field
        end
      }

      merged = build { use :pagination }
      expect(summarize(merged)).to eq([["page", :string, true, false], ["page_size", :integer, false, true], ["sort", :hash, false, true]])
      expect(summarize(merged.last.children)).to eq([["field", :string, false, true]])
      expect(build { optional { use :pagination } }).to eq(merged)
      expect(build { required { use :pagination } }).to eq(merged)
    end
  end

  describe "schema errors" do
    it "rejects a nameless declaration that no key receives" do
      expect { build { hash(:key, :name, :email) } }.to raise_error(ActiveTypedParams::SchemaError, /nameless hash/)
      expect { build { string(max_length: 5) } }.to raise_error(ActiveTypedParams::SchemaError, /nameless string/)
      expect { build { optional { array(hash(:a, :b)) } } }.to raise_error(ActiveTypedParams::SchemaError, /nameless array/)
      expect(build { param(key: hash(:name, :email)) }.first.child_keys).to eq(%w[name email])
    end

    {
      "an unknown type option" => proc { integer :x, allow_blank: true },
      "a default on a required declaration" => proc { required { string :x, default: "a" } },
      "both allow_if and allow_unless" => proc { string :x, allow_if: :a?, allow_unless: :b? },
      "both required and optional" => proc { string :x, required: true, optional: true },
      "an unsupported id size" => proc { id :x, bytes: 2 },
      "an unsupported allowlist" => proc { string :x, in: "ab" },
      "a hash without a block" => proc { hash :x },
      "a hash with a list" => proc { hash(:x, [:y]) },
      "a hash with both a block and inline fields" => proc { hash(:x, z: :string) { string :y } },
      "an array without an item" => proc { array :x },
      "an array with both an item type and a block" => proc { array(:x, :string) { string } },
      "an array with two item types" => proc { array :x, :string, :integer },
      "an array block that declares instead of returning an item" => proc { array(:x) { string :y } },
      "an item with a default" => proc { array(:x) { string(default: "a") } },
      "an item with a condition" => proc { array :x, string(allow_if: :admin?) },
      "a literal with an unknown type" => proc { param(x: :strings) },
      "a literal with a type given as a string" => proc { param(x: "string") },
      "a literal with a structural type symbol" => proc { param(x: :hash) },
      "a list with a non-symbol" => proc { param(x: ["a"]) },
      "an empty list" => proc { param(x: []) },
      "an undefined schema" => proc { use :missing },
      "an enum without an adapter" => proc { enum :x, Object.new },
      "an enum without a source" => proc { enum :status },
      "an enum without a source but with options" => proc { enum :status, in: %w[a b] },
    }.each do |description, block|
      it "rejects #{description}" do
        expect { build(&block) }.to raise_error(ActiveTypedParams::SchemaError)
      end
    end
  end
end
