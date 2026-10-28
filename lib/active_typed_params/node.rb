# frozen_string_literal: true

module ActiveTypedParams
  # Marks a node without a `default:`, so that `default: nil` stays distinct.
  NO_DEFAULT = Object.new.freeze

  TYPES = %i[string integer id decimal float boolean date time enum file hash array map any one_of].freeze
  SCALAR_TYPES = (TYPES - %i[hash array map any one_of]).freeze
  # The JSON type a `one_of` picks each alternative by.
  JSON_TYPES = {
    string: :string, date: :string, time: :string, enum: :string,
    integer: :number, id: :number, decimal: :number, float: :number,
    boolean: :boolean, array: :array, hash: :object, map: :object
  }.freeze
  LITERAL_TYPES = (SCALAR_TYPES - [:enum] + [:any]).freeze
  # `text` is a string without the default cap, for free text of any length.
  LITERAL_NAMES = (LITERAL_TYPES + [:text, :direct_upload]).freeze

  Node = Data.define(
    :key, :type, :required, :allow_nil, :allow_blank, :default, :in, :max_length,
    :condition, :as, :json, :open, :bytes, :enum_map, :invalid, :children, :item, :map_key
  ) do
    def self.build(key:, type:, required:, **options)
      new(
        key: key&.to_s,
        type:,
        required:,
        allow_nil: options.fetch(:allow_nil, false),
        allow_blank: options.fetch(:allow_blank, false),
        default: options.fetch(:default, NO_DEFAULT),
        in: options.fetch(:in, nil),
        max_length: options.fetch(:max_length, nil),
        condition: options.fetch(:condition, nil),
        as: options.fetch(:as, nil),
        json: options.fetch(:json, false),
        open: options.fetch(:open, false),
        bytes: options.fetch(:bytes, nil),
        enum_map: options.fetch(:enum_map, nil),
        invalid: options.fetch(:invalid, :raise),
        children: options.fetch(:children, nil),
        item: options.fetch(:item, nil),
        map_key: options.fetch(:map_key, nil),
      )
    end

    def default?
      !default.equal?(NO_DEFAULT)
    end

    def result_key
      (as || key).to_sym
    end

    def hash?
      type == :hash
    end

    def array?
      type == :array
    end

    def map?
      type == :map
    end

    def child_keys
      children.map(&:key)
    end
  end
end
