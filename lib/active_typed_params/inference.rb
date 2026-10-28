# frozen_string_literal: true

module ActiveTypedParams
  # Declares parameters from an ActiveInteraction's filters or a model's
  # columns, so the expected values are written once.
  module Inference
    ID_BYTES = [4, 8].freeze

  module_function

    # Filters whose values arrive in requests. Records and plain objects are
    # passed by the controller, so they are skipped, as is a filter declared
    # with `from_params: false`; an object filter whose class an enum adapter
    # handles becomes an enum.
    #
    # Every input is optional and accepts null, at any depth, because the
    # interaction reports a missing or null input as a form error and fills in
    # the default for a null one; rejecting either here would preempt that. For
    # the same reason a string the interaction validates the length of is not
    # capped, and a date or time the filter parses itself stays a string.
    def from_filter(filter, interaction = nil)
      return if filter.options[:from_params] == false

      declaration = from_custom_filter(filter) || from_builtin_filter(filter, interaction)
      declaration&.optional(allow_nil: true)
    end

    def from_builtin_filter(filter, interaction)
      case filter.class.slug
      when :string, :symbol then uncapped(Declaration.build(:string), interaction, filter.name)
      when :integer, :float, :decimal, :boolean, :file then Declaration.build(filter.class.slug)
      when :date, :time then Declaration.build(filter.options.key?(:format) ? :string : filter.class.slug)
      when :date_time then Declaration.build(:string)
      when :hash then from_hash_filter(filter)
      when :array then from_array_filter(filter)
      when :object then from_object_filter(filter)
      end
    end

    def from_custom_filter(filter)
      ActiveTypedParams.config.filter_inferrers.lazy.map { |inferrer| inferrer.call(filter) }.find(&:itself)
    end

    def from_hash_filter(filter)
      children = filter.filters.filter_map { |name, child| [name, from_filter(child)] if from_filter(child) }
      options = filter.options.fetch(:strip, true) ? {} : {open: true}
      Declaration.build(:hash, children:, options:)
    end

    def from_array_filter(filter)
      item_filter = filter.filters[:"0"]
      item = item_filter ? from_filter(item_filter) : Declaration.build(:any).optional(allow_nil: true)
      Declaration.build(:array, item:) if item
    end

    def from_object_filter(filter)
      klass = Object.const_get(filter.options.fetch(:class, filter.name).to_s.camelize)
      Declaration.build(:enum, source: klass) if EnumAdapter.lookup(klass)
    end

    # Presence follows the schema. Nullability follows the column, unless the
    # model validates presence and so reports a null itself; likewise a
    # string the model validates the length of is not capped here.
    def from_attribute(model, name)
      name = name.to_s
      attribute = model.respond_to?(:attribute_aliases) ? model.attribute_aliases.fetch(name, name) : name
      attachment = from_attachment(model, attribute)
      return attachment if attachment
      return from_attribute_container(model, attribute) unless model.respond_to?(:columns_hash)

      column = model.columns_hash[attribute] || raise(SchemaError, "#{model} has no column #{name.inspect}")
      declaration = from_attribute_type(model, attribute) || from_column(model, attribute, column)
      uncapped(declaration, model, attribute).merge_options(allow_nil: column.null || validates?(model, attribute, :presence))
    end

    # StoreModel and ActiveModel::Attributes classes declare types but no columns.
    def from_attribute_container(model, name)
      type = model.attribute_types[name] || raise(SchemaError, "#{model} has no attribute #{name.inspect}")
      uncapped(from_type(type), model, name).merge_options(allow_nil: true)
    end

    def from_attachment(model, name)
      reflection = model.reflect_on_attachment(name) if model.respond_to?(:reflect_on_attachment)
      return if reflection.nil?

      if reflection.macro == :has_many_attached
        Declaration.build(:array, item: Declaration.build(:string), options: {invalid: :drop, allow_nil: true})
      else
        Declaration.direct_upload(allow_nil: true)
      end
    end

    def from_attribute_type(model, name)
      type = model.attribute_types[name]
      return Declaration.build(:any) if defined?(ActiveRecord::Type::Serialized) && type.is_a?(ActiveRecord::Type::Serialized)

      type && from_type(type, custom_only: true)
    end

    def from_type(type, custom_only: false)
      custom = ActiveTypedParams.config.type_inferrers.lazy.map { |inferrer| inferrer.call(type) }.find(&:itself) || from_store_model(type)
      return custom if custom || custom_only

      case type.type
      when :string then Declaration.build(:string)
      when :text then Declaration.build(:string, options: text_options)
      when :integer, :float, :decimal, :boolean, :date then Declaration.build(type.type)
      when :datetime, :time then Declaration.build(:time)
      else Declaration.build(:any)
      end
    end

    # A StoreModel attribute is a hash of its model's attributes, or an array
    # of them. StoreModel keeps the model class private.
    def from_store_model(type)
      return unless defined?(StoreModel::Types::One)

      case type
      when StoreModel::Types::One then store_model_hash(type.instance_variable_get(:@model_klass))
      when StoreModel::Types::Many then Declaration.build(:array, item: store_model_hash(type.instance_variable_get(:@model_klass)))
      end
    end

    def store_model_hash(model)
      children = model.attribute_types.map { |name, type| [name, from_type(type).optional(allow_nil: true)] }
      Declaration.build(:hash, children:)
    end

    def from_column(model, name, column)
      element = from_scalar_column(model, name, column)
      (column.respond_to?(:array) && column.array) ? Declaration.build(:array, item: element) : element
    end

    def from_scalar_column(model, name, column)
      enum = model.defined_enums[name] if model.respond_to?(:defined_enums)
      return Declaration.build(:string, options: {in: enum.keys}) if enum

      case column.type
      when :string then Declaration.build(:string, options: {max_length: column.limit}.compact)
      when :text then Declaration.build(:string, options: text_options)
      when :enum then Declaration.build(:string)
      when :integer
        if name.end_with?("_id")
          Declaration.build(:id, options: {bytes: ID_BYTES.include?(column.limit) ? column.limit : 8})
        else
          Declaration.build(:integer)
        end
      when :decimal, :float, :boolean, :date then Declaration.build(column.type)
      when :datetime, :timestamp, :timestamptz, :time then Declaration.build(:time)
      when :json, :jsonb then Declaration.build(:any)
      else raise SchemaError, "cannot infer a parameter type for the #{column.type.inspect} column #{name.inspect}"
      end
    end

    def text_options
      {max_length: ActiveTypedParams.config.text_max_length}
    end

    # A length validator on an array counts its items, so only a string is left
    # for the owner to cap.
    def uncapped(declaration, owner, name)
      return declaration unless declaration.type == :string && validates?(owner, name, :length)

      declaration.merge_options(text_options)
    end

    # The cap the model's attribute of the same name would get, or none when
    # the model has no such attribute or no parameter type for it.
    def model_cap(model, name)
      from_attribute(model, name).options.slice(:max_length)
    rescue SchemaError
      {}
    end

    def validates?(owner, name, kind)
      owner.respond_to?(:validators_on) && owner.validators_on(name.to_sym).any? { |validator| validator.kind == kind }
    end

    # `key: {option: value}` pairs add options to an inferred key, such as a
    # condition or a presence flip, while its type still comes from the
    # source; options named like a child of an inferred hash adjust that
    # child. Unlike in `param`, a Hash here never declares nested keys:
    # `key: type`, such as `key: hash(...)`, replaces the inferred type in place.
    module BuilderMethods
      # `model:` names the record the inputs are saved to, so string inputs take
      # the caps of its columns of the same name.
      def inputs_from(interaction, only: nil, except: nil, model: nil, **overrides)
        filters = interaction.filters
        available = filters.keys - ActiveTypedParams.config.ignored_filters.map(&:to_sym)
        names = only ? restrict(available, only, "only") : available
        names -= restrict(filters.keys, except, "except") if except
        named = (Array(only).map(&:to_sym) | overrides.keys.map(&:to_sym))
        names = filters.keys & (names | restrict(available, overrides.keys, "inputs_from"))
        names.each do |name|
          declaration = Inference.from_filter(filters[name], interaction)
          raise SchemaError, "#{interaction}'s #{name.inspect} input cannot come from a request" if declaration.nil? && named.include?(name)

          if model && declaration&.type == :string && !declaration.options.key?(:max_length)
            declaration = declaration.merge_options(Inference.model_cap(model, name))
          end

          apply_declaration(name, override(declaration, overrides[name])) if declaration
        end
      end

      # Infers the attribute named by the key it is given to, as in
      # `address: attribute_from(User)`.
      def attribute_from(model)
        described(Declaration.build(:attribute, source: model))
      end

      # Lists the attributes of a model; a StoreModel or ActiveModel class
      # without names declares every attribute but those in `except:`.
      def attributes_from(model, *names, except: nil, **overrides)
        if names.empty? && !model.respond_to?(:columns_hash)
          names = model.attribute_types.keys.map(&:to_sym)
          names -= restrict(names, except, "except") if except
        elsif except
          raise SchemaError, "attributes_from #{model} takes except: only without names, for a StoreModel or ActiveModel class"
        end
        names |= overrides.keys
        raise SchemaError, "attributes_from #{model} needs at least one attribute" if names.empty?

        names.each { |name| apply_declaration(name, override(Inference.from_attribute(model, name), overrides[name])) }
      end

    private

      def restrict(names, subset, option)
        subset = Array(subset).map(&:to_sym)
        unknown = subset - names
        raise SchemaError, "#{option}: names filters that do not exist: #{unknown.inspect}" if unknown.any?

        names & subset
      end

      def override(declaration, options)
        return declaration if options.nil?
        unless options.is_a?(Hash)
          consume(options)
          return Declaration.from_literal(options)
        end

        declaration, options = override_children(declaration, options)
        required = presence_option(options)
        declaration = declaration.with(required:, options: declaration.options.except(:allow_nil)) unless required.nil?
        declaration.merge_options(options.except(*Builder::PRESENCE_OPTIONS))
      end

      def override_children(declaration, options)
        return [declaration, options] unless declaration.type == :hash && declaration.children&.any?

        child_names = declaration.children.map { |name, _| name.to_sym }
        nested, options = options.partition { |key, _| child_names.include?(key.to_sym) }.map(&:to_h)
        return [declaration, options] if nested.empty?

        children = declaration.children.map { |name, child| [name, nested.key?(name.to_sym) ? override(child, nested[name.to_sym]) : child] }
        [declaration.with(children:), options]
      end
    end
  end

  Builder.include Inference::BuilderMethods
end
