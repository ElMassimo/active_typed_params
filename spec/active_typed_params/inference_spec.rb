# frozen_string_literal: true

require "spec_helper"
require "active_interaction"
require "store_model"

module ActiveTypedParamsSpec
  class Role; end

  class Account; end

  class CustomType < ActiveModel::Type::Value; end

  Column = Struct.new(:name, :type, :limit, :null, :array, keyword_init: true)

  class FakeModel
    include ActiveModel::Validations

    validates :bio, length: {maximum: 2000}
    validates :count, presence: true
    validates :tags, length: {minimum: 1}

    COLUMNS = [
      Column.new(name: "name", type: :string, null: false),
      Column.new(name: "nickname", type: :string, limit: 40, null: true),
      Column.new(name: "owner_id", type: :integer, limit: 8, null: false),
      Column.new(name: "parent_id", type: :integer, limit: 4, null: true),
      Column.new(name: "count", type: :integer, limit: 4, null: false),
      Column.new(name: "price", type: :decimal, null: false),
      Column.new(name: "ratio", type: :float, null: false),
      Column.new(name: "active", type: :boolean, null: false),
      Column.new(name: "born_on", type: :date, null: true),
      Column.new(name: "created_at", type: :datetime, null: false),
      Column.new(name: "tags", type: :string, null: true, array: true),
      Column.new(name: "prefs", type: :jsonb, null: false),
      Column.new(name: "status", type: :string, null: false),
      Column.new(name: "kind", type: :string, null: true),
      Column.new(name: "address", type: :inet, null: true),
      Column.new(name: "notes", type: :text, null: true),
      Column.new(name: "bio", type: :string, limit: 100, null: true),
      Column.new(name: "mood", type: :enum, null: true),
    ].freeze

    Attachment = Struct.new(:macro)

    def self.attribute_aliases
      {"title" => "name"}
    end

    def self.reflect_on_attachment(name)
      {"avatar" => Attachment.new(:has_one_attached), "photos" => Attachment.new(:has_many_attached)}[name.to_s]
    end

    def self.columns_hash
      COLUMNS.index_by(&:name)
    end

    def self.defined_enums
      {"status" => {"draft" => 0, "live" => 1}}
    end

    def self.attribute_types
      {"kind" => CustomType.new}
    end
  end
end

RSpec.describe ActiveTypedParams::Inference, :active_typed_params do
  def build(&block)
    ActiveTypedParams::Builder.run(block)
  end

  def summarize(nodes)
    nodes.map { |node| [node.key, node.type, node.required, node.allow_nil] }
  end

  before do
    ActiveTypedParams.config.enum_adapters << ->(source) { {"admin" => :ADMIN} if source == ActiveTypedParamsSpec::Role }
    ActiveTypedParams.config.type_inferrers << lambda { |type|
      ActiveTypedParams::Declaration.build(:enum, source: %w[a b]) if type.is_a?(ActiveTypedParamsSpec::CustomType)
    }
    ActiveTypedParams.config.ignored_filters = [:status_code]
  end

  describe "inputs_from" do
    let(:interaction) do
      Class.new(ActiveInteraction::Base) {
        integer :status_code, default: nil
        object :user, class: Object
        record :account, class: ActiveTypedParamsSpec::Account
        interface :notifier, methods: [:call]
        object :role, class: ActiveTypedParamsSpec::Role, default: nil
        string :email
        string :name, default: "anon"
        integer :count, default: nil
        boolean :flag
        date :starts_on
        time :starts_at
        date_time :ends_at
        float :ratio
        decimal :amount
        symbol :kind
        file :upload
        hash :address do
          string :street
          integer :zip, default: nil
        end
        hash :meta, strip: false, default: nil
        hash :empty_meta
        array :tags do
          string
        end
        array :things
        array :users do
          object class: Object
        end
      }
    end

    # Schema blocks run on the builder, so the interaction is captured as a local.
    it "declares one parameter per request-borne filter, all optional and nullable so the interaction reports presence" do
      klass = interaction
      nodes = build { inputs_from klass }

      expect(summarize(nodes)).to eq([
        ["role", :enum, false, true],
        ["email", :string, false, true],
        ["name", :string, false, true],
        ["count", :integer, false, true],
        ["flag", :boolean, false, true],
        ["starts_on", :date, false, true],
        ["starts_at", :time, false, true],
        ["ends_at", :string, false, true],
        ["ratio", :float, false, true],
        ["amount", :decimal, false, true],
        ["kind", :string, false, true],
        ["upload", :file, false, true],
        ["address", :hash, false, true],
        ["meta", :hash, false, true],
        ["empty_meta", :hash, false, true],
        ["tags", :array, false, true],
        ["things", :array, false, true],
      ])
      by_key = nodes.index_by(&:key)
      expect(by_key["role"].enum_map).to eq("admin" => :ADMIN)
      expect(summarize(by_key["address"].children)).to eq([["street", :string, false, true], ["zip", :integer, false, true]])
      expect(by_key["empty_meta"].children).to eq([])
      expect(by_key["empty_meta"].open).to be(false)
      expect(by_key["meta"]).to have_attributes(children: [], open: true)
      expect(by_key["tags"].item).to have_attributes(type: :string, required: true, allow_nil: true)
      expect(by_key["things"].item).to have_attributes(type: :any, required: true, allow_nil: true)
      expect(nodes.map(&:default?)).to all(be(false))
    end

    it "restricts the filters with only: and except:, and rejects names that are not filters" do
      klass = interaction

      expect(build { inputs_from klass, only: %i[email flag] }.map(&:key)).to eq(%w[email flag])
      expect(build { inputs_from klass, except: [:email] }.map(&:key)).not_to include("email")
      expect(build { inputs_from klass, except: [:status_code] }.map(&:key)).not_to include("status_code")
      expect { build { inputs_from klass, only: [:nope] } }.to raise_error(ActiveTypedParams::SchemaError, /nope/)
    end

    it "takes per-key overrides that add options or flip presence while the type stays inferred" do
      klass = interaction

      nodes = build {
        inputs_from klass, only: [:name], email: {required: true, max_length: 10}, flag: {allow_if: :admin?}, count: {default: 3}, address: {required: true}
      }
      by_key = nodes.index_by(&:key)
      expect(summarize(nodes)).to eq([
        ["email", :string, true, false],
        ["name", :string, false, true],
        ["count", :integer, false, true],
        ["flag", :boolean, false, true],
        ["address", :hash, true, false],
      ])
      expect(summarize(by_key["address"].children)).to eq([["street", :string, false, true], ["zip", :integer, false, true]])
      expect(by_key["email"].max_length).to eq(10)
      expect(by_key["flag"].condition).to eq([:if, :admin?])
      expect(by_key["count"].default).to eq(3)
      expect { build { inputs_from klass, nope: {default: 1} } }.to raise_error(ActiveTypedParams::SchemaError, /nope/)
      expect(build { inputs_from klass, only: [:email], tags: array(:string) }.last.item.type).to eq(:string)
      address = build { inputs_from klass, only: [:address], address: {street: {max_length: 10}, zip: {required: true}} }.first
      expect(address.children.map { |child| [child.key, child.max_length, child.required] }).to eq([["street", 10, false], ["zip", nil, true]])
      expect { build { inputs_from klass, flag: {allow_nil: true, strip: true} } }.to raise_error(ActiveTypedParams::SchemaError, /strip/)
    end

    it "keeps inputs optional inside a required block and lets a declaration replace an inferred one in place" do
      klass = interaction

      nodes = build {
        required { inputs_from klass, only: %i[count address] }
      }
      expect(summarize(nodes)).to eq([["count", :integer, false, true], ["address", :hash, false, true]])
      expect(summarize(nodes.last.children)).to eq([["street", :string, false, true], ["zip", :integer, false, true]])

      nodes = build {
        inputs_from klass, only: %i[email flag]
        string :email, max_length: 10
      }
      expect(nodes.map(&:key)).to eq(%w[email flag])
      expect(nodes.first.max_length).to eq(10)
    end
  end

  describe "inputs_from rules for the inputs a request may set" do
    let(:interaction) do
      Class.new(ActiveInteraction::Base) {
        def self.name = "Signup"

        string :ip_address, from_params: false
        object :user, class: Object
        string :bio, default: nil
        string :note, default: nil
        date_time :verify_at
        date :born_on, format: "%m/%d/%Y"
        validates :bio, length: {maximum: 2000}
      }
    end

    it "skips from_params: false inputs and inputs it cannot infer, raising when either is named" do
      klass = interaction

      expect(build { inputs_from klass }.map(&:key)).to eq(%w[bio note verify_at born_on])
      expect { build { inputs_from klass, only: %i[ip_address] } }.to raise_error(ActiveTypedParams::SchemaError, /ip_address/)
      expect { build { inputs_from klass, only: %i[user] } }.to raise_error(ActiveTypedParams::SchemaError, /user/)
      expect { build { inputs_from klass, user: {optional: true} } }.to raise_error(ActiveTypedParams::SchemaError, /user/)
    end

    it "leaves parsing and length checks to the interaction" do
      klass = interaction
      by_key = build { inputs_from klass }.index_by(&:key)

      expect(by_key["verify_at"].type).to eq(:string)
      expect(by_key["born_on"].type).to eq(:string)
      expect(by_key["bio"].max_length).to eq(65_535)
      expect(by_key["note"].max_length).to eq(512)
    end

    it "takes string caps from the columns of the model named with model:" do
      klass = Class.new(ActiveInteraction::Base) {
        string :name
        string :nickname
        string :notes
        string :bio, default: nil
        string :missing, default: nil
        integer :count, default: nil
      }

      by_key = build { inputs_from klass, model: ActiveTypedParamsSpec::FakeModel }.index_by(&:key)

      expect(by_key.transform_values(&:max_length)).to eq("name" => 512, "nickname" => 40, "notes" => 65_535, "bio" => 65_535, "missing" => 512, "count" => nil)
      signup = interaction
      expect(build { inputs_from signup, only: :bio, model: ActiveTypedParamsSpec::FakeModel }.first.max_length).to eq(65_535)
    end

    it "infers custom filters through the configured filter inferrers" do
      klass = Class.new(ActiveInteraction::Base) { interface :image, methods: [:url] }
      ActiveTypedParams.config.filter_inferrers << lambda { |filter|
        ActiveTypedParams::Declaration.build(:string, options: {invalid: :drop}) if filter.class.slug == :interface
      }

      expect(build { inputs_from klass }.first).to have_attributes(key: "image", type: :string, invalid: :drop)
    end
  end

  describe "attributes_from" do
    let(:preferences) do
      Class.new {
        include ActiveModel::Model
        include ActiveModel::Attributes
        include ActiveModel::Validations

        attribute :theme, :string
        attribute :size, :integer
        attribute :blurb, :string
        validates :blurb, length: {maximum: 5000}
      }
    end

    it "declares StoreModel attributes as hashes of their attributes, or arrays of them" do
      address = Class.new {
        include StoreModel::Model

        attribute :street, :string
        attribute :zip, :integer
        attribute :tags, ActiveModel::Type::Value.new
      }
      klass = Class.new {
        include ActiveModel::Model
        include ActiveModel::Attributes

        attribute :address, address.to_type
        attribute :addresses, address.to_array_type
      }
      address_node, addresses_node = build { attributes_from klass }

      expect(address_node).to have_attributes(type: :hash, allow_nil: true)
      expect(summarize(address_node.children)).to eq([["street", :string, false, true], ["zip", :integer, false, true], ["tags", :any, false, true]])
      expect(addresses_node).to have_attributes(type: :array)
      expect(addresses_node.item.child_keys).to eq(%w[street zip tags])
    end

    it "reads every attribute of an ActiveModel class, or those outside except:" do
      klass = preferences

      expect(summarize(build { attributes_from klass })).to eq([["theme", :string, false, true], ["size", :integer, false, true], ["blurb", :string, false, true]])
      expect(build { attributes_from klass, except: :size }.map(&:key)).to eq(%w[theme blurb])
      expect(build { attributes_from klass, :size }.map(&:key)).to eq(%w[size])
      expect(build { attributes_from klass }.last.max_length).to eq(65_535)
      expect(summarize(build { required { attributes_from klass, :theme } })).to eq([["theme", :string, true, true]])
      expect { build { attributes_from ActiveTypedParamsSpec::FakeModel, except: :name } }.to raise_error(ActiveTypedParams::SchemaError, /except/)
    end

    it "resolves aliases, attachments, text and enum columns, and what the model validates itself" do
      by_key = build {
        attributes_from ActiveTypedParamsSpec::FakeModel, :title, :avatar, :photos, :notes, :bio, :mood, :count
      }.index_by(&:key)

      expect(by_key["title"]).to have_attributes(type: :string, allow_nil: false)
      expect(by_key["avatar"]).to have_attributes(type: :string, invalid: :drop, allow_nil: true)
      expect(by_key["photos"]).to have_attributes(type: :array, invalid: :drop)
      expect(by_key["notes"].max_length).to eq(65_535)
      expect(by_key["bio"].max_length).to eq(65_535)
      expect(by_key["mood"].type).to eq(:string)
      expect(by_key["count"].allow_nil).to be(true)
    end

    it "infers types from the columns, nullability from NOT NULL, and presence from placement" do
      nodes = build {
        required { attributes_from ActiveTypedParamsSpec::FakeModel, :name, :owner_id, :count, :price, :ratio, :active, :created_at, :prefs, :status }
        attributes_from ActiveTypedParamsSpec::FakeModel, :nickname, :parent_id, :born_on, :tags, :kind
      }
      by_key = nodes.index_by(&:key)

      expect(summarize(nodes)).to eq([
        ["name", :string, true, false],
        ["owner_id", :id, true, false],
        ["count", :integer, true, true],
        ["price", :decimal, true, false],
        ["ratio", :float, true, false],
        ["active", :boolean, true, false],
        ["created_at", :time, true, false],
        ["prefs", :any, true, false],
        ["status", :string, true, false],
        ["nickname", :string, false, true],
        ["parent_id", :id, false, true],
        ["born_on", :date, false, true],
        ["tags", :array, false, true],
        ["kind", :enum, false, true],
      ])
      expect(by_key["name"].max_length).to eq(512)
      expect(by_key["nickname"].max_length).to eq(40)
      expect(by_key["owner_id"].bytes).to eq(8)
      expect(by_key["parent_id"].bytes).to eq(4)
      expect(by_key["status"].in).to eq(Set["draft", "live"])
      expect(by_key["tags"].item.type).to eq(:string)
      expect(by_key["tags"].max_length).to eq(1000)
      expect(by_key["kind"].enum_map).to eq("a" => "a", "b" => "b")
    end

    it "infers the attribute named by the key with attribute_from, at any depth" do
      nodes = build {
        required(
          :title,
          nickname: attribute_from(ActiveTypedParamsSpec::FakeModel),
          profile: [count: attribute_from(ActiveTypedParamsSpec::FakeModel)],
        )
      }

      expect(summarize(nodes)).to eq([["title", :string, true, false], ["nickname", :string, true, true], ["profile", :hash, true, false]])
      expect(nodes[1].max_length).to eq(40)
      expect(summarize(nodes[2].children)).to eq([["count", :integer, true, true]])
      expect { build { param(nope: attribute_from(ActiveTypedParamsSpec::FakeModel)) } }.to raise_error(ActiveTypedParams::SchemaError, /no column "nope"/)
      expect { build { param(tags: array(attribute_from(ActiveTypedParamsSpec::FakeModel))) } }.to raise_error(ActiveTypedParams::SchemaError, /cannot describe an array item/)
    end

    it "takes per-key overrides and counts them as attributes" do
      nodes = build { attributes_from ActiveTypedParamsSpec::FakeModel, :name, nickname: {allow_unless: :admin?}, count: {required: true, in: 1..9} }

      expect(summarize(nodes)).to eq([["name", :string, false, false], ["nickname", :string, false, true], ["count", :integer, true, false]])
      expect(nodes[1].condition).to eq([:unless, :admin?])
      expect(nodes[2].in).to eq(1..9)
    end

    it "rejects unknown attributes, unsupported column types and empty lists" do
      expect { build { attributes_from ActiveTypedParamsSpec::FakeModel, :missing } }.to raise_error(ActiveTypedParams::SchemaError, /missing/)
      expect { build { attributes_from ActiveTypedParamsSpec::FakeModel, :address } }.to raise_error(ActiveTypedParams::SchemaError, /inet/)
      expect { build { attributes_from ActiveTypedParamsSpec::FakeModel } }.to raise_error(ActiveTypedParams::SchemaError, /at least one/)
    end
  end
end
