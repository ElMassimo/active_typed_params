<h1 align="center">
Active Typed Params
<p align="center">
  <a href="https://github.com/ElMassimo/active_typed_params/actions/workflows/ci.yml">
    <img alt="Build Status" src="https://github.com/ElMassimo/active_typed_params/actions/workflows/ci.yml/badge.svg"/>
  </a>
  <a href="https://rubygems.org/gems/active_typed_params">
    <img alt="Gem Version" src="https://img.shields.io/gem/v/active_typed_params.svg?colorB=e9573f"/>
  </a>
  <a href="https://github.com/ElMassimo/active_typed_params/blob/main/LICENSE.txt">
    <img alt="License" src="https://img.shields.io/badge/license-MIT-428F7E.svg"/>
  </a>
</p>
</h1>

[strong parameters]: https://api.rubyonrails.org/classes/ActionController/StrongParameters.html
[ActiveInteraction]: https://github.com/AaronLasseigne/active_interaction
[StoreModel]: https://github.com/DmitryTsepelev/store_model
[benchmarks]: #benchmarks-
[inference]: #inference-
[inline]: #inline-reads-%EF%B8%8F
[errors]: #errors-
[config]: #configuration-%EF%B8%8F

Typed [strong parameters] for Rails controllers, compiled into plain Ruby methods.

```ruby
typed_params(:contact_params) {
  required(:name)
  param(:email, :relationship, event_ids: array(:id))
}
```

## Why? 🤔

[Strong parameters] tell Rails which keys a request can set, but not what they should contain.

If a request sends a hash where a string is expected, strong parameters silently drop it. A number passes through as an `Integer`. Either can cause a `NoMethodError` later, returning a `500` instead of a validation error.

Manual type checks are repetitive, and [ActiveInteraction] only validates inputs once the controller calls it.

`typed_params` declares keys and types next to the action that reads them. Parameters of the wrong type are rejected with a `400` that names the parameter, before the action passes them to a model or interaction.

Each declaration is compiled into a single Ruby method, which makes it [5 to 10 times faster][benchmarks] than `params.permit`.

## Features ⚡️

- Reads like a permit list: `required(:email, tags: array(:string))`
- Numbers, booleans, dates, ids, enums, files, nested hashes, arrays, maps, and values of several types
- [Infers types][inference] from interaction inputs and model columns
- Default length limits for strings, arrays and maps, with a higher limit for text columns
- [Errors][errors] name the parameter but never echo the value: `delivery.address_id must be an id`
- A `400` for a malformed request, and a `422` for validation errors such as blank or out-of-range values
- Up to 10x faster than `params.permit`, with fewer allocations

## Installation 💿

Add this line to your application's Gemfile:

```ruby
gem "active_typed_params"
```

And then run:

```
bundle install
```

In a Rails app, `typed_params` is available in every controller.

Outside of Rails, or in a controller that doesn't inherit from `ActionController::Base` or `ActionController::API`, include `ActiveTypedParams::Controller`.

## Usage 🚀

Declare a schema in the controller, and call the method it defines:

```ruby
class ContactsController < ApplicationController
  def create
    contact = current_user.contacts.create!(contact_params)
    ...
  end

private

  typed_params(:contact_params) {
    required(:name)
    param(:email, :relationship, event_ids: array(:id))
  }
end
```

The method returns a plain `Hash` with symbol keys, including only the keys the request sent:

```ruby
# POST /contacts { "name": "Ana", "relationship": "friend", "event_ids": ["12", "34"] }
contact_params
# => { name: "Ana", relationship: "friend", event_ids: [12, 34] }
```

A request that sends `{ "name": { "$ne": "" } }` is rejected before the model is called, with a `400` and `name must be a string`.

> **Note**
>
> Keys are optional and accept `null` by default.

## Types 🏷

A bare symbol is a string, and `key: type` declares anything else:

| Type | Accepts | Returns |
| --- | --- | --- |
| `:string` | A string of up to 512 characters | `String` |
| `:text` | A string of up to [`text_max_length`][config] characters | `String` |
| `:integer` | `5` or `"5"` | `Integer` |
| `:id` | A positive integer, or its string | `Integer` |
| `:decimal` | `1.5` or `"1.5"` | `BigDecimal` |
| `:float` | `1.5`, `"1.5"` or `"1e3"` | `Float` |
| `:boolean` | `true`, `false`, `"true"`, `"false"`, `"1"` or `"0"` | `true` or `false` |
| `:date` | `"2026-06-05"` | `Date` |
| `:time` | An ISO 8601 time | `Time`, in `Time.zone` |
| `:file` | An uploaded file | The file |
| `:direct_upload` | A signed blob id, or `null` to remove the file; the attachment object a form posts back for an unchanged file is dropped | `String` |
| `:any` | Anything | The value, with symbol keys |
| `enum(%w[draft live])` | One of the values | The value |
| `[:name, zip: :string]` | A hash with those keys | `Hash` |
| `{}` | A hash of anything | `Hash` |

Forms send an empty string for a cleared input, so `""` reads as `nil` for every type but strings.

> **Warning**
>
> `{}`, `open: true` and `:any` accept keys you didn't declare, just like `permit(key: {})`.
>
> Use them for values stored as a whole, such as a JSON column, and never pass them to `update` or `assign_attributes` as the attributes themselves. You can [list them in a spec](#inspecting-schemas-) to check for unintended additions.

### Options

To set options on a key, use the method form:

```ruby
typed_params(:search_params) {
  string :term, max_length: 100
  integer :page, in: 1..500, default: 1
  string :sort, in: %w[name created_at], as: :order
  boolean :archived, allow_if: :admin?
}
```

or a descriptor inside a literal:

```ruby
param(note: string(max_length: 2_500), page: integer(in: 1..500))
```

- `max_length`: the most characters in a string (512 by default), or items in an array or map (1,000 by default); `nil` removes the cap
- `in`: an `Array`, `Set` or `Range` of allowed values
- `default`: the value when the key is omitted, or when it's `null` and `null` isn't allowed
- `allow_nil`, `allow_blank`: accept `null` or an empty string
- `allow_if`, `allow_unless`: a method on the controller; when the key isn't allowed, it's ignored as if it wasn't declared
- `as`: a different key for the result
- `invalid: :drop`: treat a value of the wrong type as omitted, the way `permit` would
- `json: true`: accept a hash or array as a JSON string, useful in query strings

### Required Keys

`required` keys must be present, can't be `null`, and strings can't be blank:

```ruby
typed_params(:login_params) {
  required(:email, :password)
  param(remember_me: :boolean)
}
```

You can also wrap several declarations in a block, or make every key required:

```ruby
typed_params(:address_params, required: true) {
  param(:street, :city, :zip)
  optional { string :apartment }
}
```

### Hashes, Arrays and Maps

A list declares a nested hash, and `array` declares a list of values:

```ruby
typed_params(:order_params) {
  param(
    delivery: [:name, :email, date: :date],
    place_ids: array(id(bytes: 4)),
    recipients: array([:name, :email]),
  )

  hash :address do
    required(:street, :city)
    string :zip, max_length: 10
  end
}
```

A `map` is a hash keyed by data, such as ids, so its keys stay strings:

```ruby
param(opt_outs: map([email: :boolean, sms: :boolean]))
# => { opt_outs: { "12" => { email: true, sms: false } } }
```

### Several Types

When a value can take more than one shape, `one_of` picks the type by the value's JSON type, without converting between them:

```ruby
param(value: one_of(:string, :integer, array(:string)))
```

A string goes to `:string`, a number to `:integer`, and an array to `array(:string)`. Anything else, such as a hash, is a `400`.

Each alternative needs a different JSON type, so `one_of(:string, :date)` raises when the schema is declared.

> **Note**
>
> Query strings only carry strings, so `one_of` is meant for JSON bodies and `json: true` values.

### Enums

`enum` accepts one of a list of values, or the keys of a hash, and returns the value they map to:

```ruby
typed_params(:post_params) {
  enum :status, %w[draft published]
  enum :visibility, {"public" => 0, "private" => 1}
  param(kind: enum(%w[article video]))
}
```

A value outside the list returns a `422` validation error.

To pass your own enum classes, register an [enum adapter](#enum_adapters).

## Inference 🔮

`typed_params` can infer types from a model or an [ActiveInteraction].

### From an interaction

`inputs_from` declares a key for each input that can come from a request:

```ruby
typed_params(:order_params) {
  inputs_from UpdateOrder, model: Order
}
```

- Every input is optional and accepts `null`, so the interaction can report a missing value as a form error
- Records and objects are skipped, along with inputs declared with `from_params: false`
- `only:` and `except:` pick the inputs
- `model:` caps strings by the columns of the same name

### From a model

`attributes_from` declares the attributes you name, using the database columns:

```ruby
typed_params(:role_params, root: :role) {
  attributes_from Role, :name, :permissions, :description
}
```

String limits, text columns, enums, array columns, `NOT NULL` constraints, [StoreModel] attributes, and attachments are all taken into account.

To infer a single attribute inside a literal, use `attribute_from`:

```ruby
param(
  :notes,
  shipping_address: attribute_from(Order),
  preferences: attribute_from(Order),
)
```

### Overrides

Both `inputs_from` and `attributes_from` accept per-key overrides to add options or replace the type:

```ruby
inputs_from UpdateUserAccess, super_admin: {allow_if: :super_admin?}
inputs_from UpdateContact, event_ids: array(:id)
```

## Inline Reads ✍️

For one or two keys, you can read them inside the action:

```ruby
def index
  page = typed_params.optional(page: :integer) || 1
  ids = typed_params.optional(ids: typed_params.array(:id)) || []
  email = typed_params.require(:email)
end
```

`require` and `optional` return the value for a single key, and a hash for several. `slice` always returns a hash containing only keys present in the request, so updates leave omitted attributes unchanged.

Each distinct declaration is compiled once and cached, so an inline read costs a little more than a named schema: about 1.4 µs for `typed_params.require(:email)`.

> **Note**
>
> Prefer a named schema for actions that read several keys.

## Schema Options 🔧

### `root`

Reads the keys of one required hash, like `params.require(:contact).permit(...)`, and returns the inner hash:

```ruby
typed_params(:contact_params, root: :contact) {
  param(:name, :email)
}
```

### `source`

Reads the hash a proc returns instead of all the `params`:

```ruby
typed_params(:address_params, source: -> { params.require(:order).require(:shipping_address) }) {
  param(:street, :city, notes: string(max_length: 2_500))
}
```

### `memoize`

Keeps the result for the rest of the request, for a schema read more than once.

### `required`

Makes every key required unless explicitly declared optional.

### `unknown`

Keys a schema doesn't declare are ignored by default. Use `unknown: :report` to publish them as an `unknown_parameters.typed_params` event, or `unknown: :reject` to answer `400`.

## Sharing Schemas 🧱

A fragment defines keys shared by several schemas. You can define it alongside the model:

```ruby
class Address
  PARAMS = ActiveTypedParams.fragment {
    param(:street, :city, :zip, notes: :text)
  }
end
```

`use` merges it into a schema:

```ruby
typed_params(:order_params) {
  attributes_from Order, :notes, :amount
  param(shipping_address: hash { use Address::PARAMS })
}
```

`use` also takes the name of a schema in the same controller or one of its ancestors, as in `use :pagination`.

To validate params outside of a controller, define a schema and call `validate`:

```ruby
REQUEST_PARAMS = ActiveTypedParams.define(:search_request) {
  param(:term, page: :integer)
}

REQUEST_PARAMS.validate(params)
```

## Errors 🚨

| Problem | Error | Status |
| --- | --- | --- |
| Wrong type, missing required key, unknown key with `unknown: :reject` | `ActiveTypedParams::InvalidParameter` | `400` |
| Too long, blank, or not one of the allowed values | `ActiveTypedParams::UnprocessableParameter` | `422` |

Messages name the parameter and never echo the value, such as `delivery.address_id must be an id`.

Both are `ActionController::BadRequest` subclasses, so existing rescues keep working, and Rails answers with the right status in controllers without a `rescue_from`.

Each error has a `path`, such as `["delivery", "address_id"]`, and a `code`, which you can use to render the error next to its field:

```ruby
rescue_from ActiveTypedParams::InvalidParameter do |error|
  render json: {errors: {error.path.join(".") => error.message}}, status: error.status
end
```

### Instrumentation

Every rejected parameter publishes an `invalid_parameters.typed_params` event with the `path`, `code`, `controller`, `action` and `request`.

To log `400` errors by endpoint and parameter path without including `422` validation errors:

```ruby
ActiveSupport::Notifications.subscribe("invalid_parameters.typed_params") do |*, payload|
  next if ActiveTypedParams::UnprocessableParameter::CODES.include?(payload[:code])

  Rails.logger.warn("Invalid parameter #{payload[:path]} (#{payload[:code]}) in #{payload[:controller]}##{payload[:action]}")
end
```

> **Note**
>
> Handle exceptions in subscribers; otherwise, they replace the original parameter error.

## Configuration ⚙️

You can configure the library in an initializer:

```ruby
ActiveTypedParams.configure do |config|
  config.text_max_length = 30_000
end
```

### `text_max_length`

_Default:_ `65_535`

The length limit for `:text` and for inferred strings whose length is validated by the model or interaction.

### `ignored_filters`

_Default:_ `[]`

Interaction inputs that `inputs_from` never declares, for inputs that controllers set from the request context, such as `ip_address`.

### `enum_adapters`

_Default:_ `[]`

Procs that receive the class given to an enum and return a `Hash` from request value to returned value, or `nil` when they don't handle it.

```ruby
config.enum_adapters << lambda { |source|
  source.values.to_h { |value| [value.key, value] } if source.is_a?(Class) && source < ApplicationEnum
}
```

Once an adapter handles a class, it can be used as a type, as in `param(role: Role)`, and `inputs_from` declares interaction inputs of that class as enums.

### `type_inferrers` and `filter_inferrers`

_Default:_ `[]`

Procs that receive a model attribute type or an interaction filter and return a declaration, for custom types inference doesn't know about.

```ruby
config.type_inferrers << lambda { |type|
  ActiveTypedParams::Declaration.build(:array, item: ActiveTypedParams::Declaration.build(:string)) if type.is_a?(TagListType)
}
```

### `file_classes`

_Default:_ `[ActionDispatch::Http::UploadedFile, Rack::Test::UploadedFile]`

The classes that `:file` accepts.

## Inspecting Schemas 🔍

`describe` prints what a request can set, which is useful in a snapshot spec:

```ruby
puts ActiveTypedParams.schema(ContactsController, :contact_params).describe
```

```
name: string
email: string?
relationship: string?
event_ids: array(id)?
```

`ActiveTypedParams.all_schemas` lists every schema in the app, which you can use to review the keys that accept anything:

```ruby
it "accepts undeclared keys only where they were reviewed" do
  Rails.application.eager_load!

  open_paths = lambda { |nodes, path = []|
    nodes.flat_map { |node|
      key = [*path, node.key || "[]"]
      own = (node.open || node.type == :any) ? [key.join(".")] : []
      own + open_paths.call([*node.children, *node.item], key)
    }
  }
  found = ActiveTypedParams.all_schemas.flat_map { |schema|
    open_paths.call(schema.nodes).map { |path| "#{schema.owner}##{schema.name} #{path}" }
  }

  expect(found).to match_array([
    "OrdersController#order_params preferences",
  ])
end
```

## Design 📐

Each schema is compiled into one straight-line Ruby method: nested hashes are inlined, arrays become loops, and allowlists become constants. This avoids allocating intermediate validation objects.

With eager loading, every schema is compiled at boot rather than during a request. In development, schemas are compiled on first use and recompiled after code reloading.

### Benchmarks 📊

Time per call on Ruby 4.0 with YJIT, 20,000 iterations, using params like the ones Rails passes to a controller:

| Request | `typed_params` | `params.permit` | ActiveInteraction |
| --- | --- | --- | --- |
| Login (2 keys) | 0.6 µs, 6 allocations | 5.7 µs, 48 | 10 µs, 65 |
| Search (pagination, sort, 3 filters) | 3.4 µs, 13 | 32 µs, 190 | 37 µs, 221 |
| Checkout (40 keys, 3 levels) | 17 µs, 27 | 168 µs, 845 | 183 µs, 978 |

You can run them with:

```
RUBY_YJIT_ENABLE=1 RUN_TYPED_PARAMS_BENCHMARKS=1 bundle exec rspec spec/performance
```

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
