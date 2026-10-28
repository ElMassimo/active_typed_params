# frozen_string_literal: true

# Opt-in benchmark for the compiled typed_params methods. Production runs
# YJIT, so compare revisions with it enabled:
#
#   RUBY_YJIT_ENABLE=1 RUN_TYPED_PARAMS_BENCHMARKS=1 bundle exec rspec spec/performance/typed_params_performance_spec.rb
#
# It needs no database: it loads ActionPack and ActiveInteraction alone.
require "spec_helper"
require "active_interaction"
require "memory_profiler"

module ActiveTypedParamsSpec
  BenchmarkCase = Struct.new(:name, :payload, :controller, :permit, :interaction, keyword_init: true)

  # ActiveInteraction only validates on `run`, which needs an execute method.
  class BenchmarkInteraction < ActiveInteraction::Base
    def execute
      inputs
    end
  end
end

RSpec.describe "typed_params performance", :active_typed_params, if: ENV["RUN_TYPED_PARAMS_BENCHMARKS"] do
  let(:iterations) { Integer(ENV.fetch("TYPED_PARAMS_BENCHMARK_ITERATIONS", "20000")) }

  let(:login) do
    ActiveTypedParamsSpec::BenchmarkCase.new(
      name: "login (2 keys)",
      payload: {user: {email: "max@example.com", password: "hunter22"}, controller: "sessions", action: "create"},
      controller: Class.new(ActiveTypedParamsSpec::FakeController) {
        typed_params(:p) {
          required(user: [:email, :password])
        }
      },
      permit: ->(params) { params.permit(user: [:email, :password]) },
      interaction: Class.new(ActiveTypedParamsSpec::BenchmarkInteraction) {
        hash :user do
          string :email, :password
        end
      },
    )
  end

  let(:search) do
    ActiveTypedParamsSpec::BenchmarkCase.new(
      name: "search (pagination, sort, 3 filters)",
      payload: {
        controller: "search", action: "search",
        page: 2, page_size: 25,
        sort_option: {id: "created_at", direction: "DESC"},
        search_filters: [{id: "status", value: "purchased"}, {id: "amount", value: {min: 10, max: 50}}, {id: "email", value: "a@b.c"}]
      },
      controller: Class.new(ActiveTypedParamsSpec::FakeController) {
        typed_params(:p, unknown: :ignore) {
          optional {
            integer :page, in: 1..(2**31 - 1), default: 1
            integer :page_size, in: 1..100
            hash :sort_option do
              string :id
              string :direction, in: %w[ASC DESC]
            end
            array :search_filters do
              hash do
                string :id
                any :value
              end
            end
          }
        }
      },
      permit: ->(params) { params.permit(:page, :page_size, sort_option: [:id, :direction], search_filters: [:id, value: {}]) },
      interaction: Class.new(ActiveTypedParamsSpec::BenchmarkInteraction) {
        integer :page, default: 1
        integer :page_size, default: nil
        hash :sort_option, default: nil do
          string :id, :direction
        end
        array :search_filters, default: nil do
          hash strip: false
        end
      },
    )
  end

  let(:checkout) do
    ActiveTypedParamsSpec::BenchmarkCase.new(
      name: "checkout (40 keys, 3 levels)",
      payload: {
        controller: "orders", action: "create",
        total: 50, payment_method: "card", express_shipping: false, coupon_ids: [1, 2, 3],
        preferences: {currency: "USD", locale: "en", theme: "dark", timezone: "America/Chicago", referrer: "newsletter", subscribe: true, interests: %w[coffee kitchen]},
        shipping: {
          ship_on: "2026-12-24", carrier: "ups", address_type: "Home", address_id: 42,
          email: "ana@example.com", phone: "+15555550123", instructions: "", save_address: true,
          address: {name: "Ana", street: "1 Main St", city: "Austin", state: "TX", zip: "78701"}
        },
        cart: {
          channel: "web", campaign: "spring", notes: "Leave at the door", store_id: 7, customer: {id: 12},
          packaging: {
            box: "medium", filler: "paper", label: "Fragile", note: "Thanks!",
            line_items: [
              {sku: "MUG-1", name: "Mug", size: "M", color: "white", variant: "matte", engravings: [{key: "logo", x: 0.1, y: 0.2, rotation: 0, scale: 1}, {key: "initials", x: 0.5, y: 0.5, rotation: 15, scale: 1.2}]},
              {sku: "TEE-2", name: "T-shirt", size: "L", color: "black", variant: "cotton", engravings: []},
            ]
          }
        }
      },
      controller: Class.new(ActiveTypedParamsSpec::FakeController) {
        typed_params(:p) {
          optional {
            decimal :total
            string :payment_method
            boolean :express_shipping
            array :coupon_ids, :id, bytes: 4
            hash :preferences do
              optional {
                string :currency, :locale, :theme, :timezone, :referrer
                boolean :subscribe
                array :interests, :string
              }
            end
            hash :shipping do
              optional {
                date :ship_on
                enum :carrier, %w[ups fedex usps dhl]
                string :address_type, in: ["Home", "Office"], allow_nil: true
                id :address_id, allow_nil: true
                string :email, :phone, :instructions
                boolean :save_address
                hash :address do
                  optional { string :name, :street, :city, :state, :zip }
                end
              }
            end
            hash :cart do
              optional {
                string :channel, :campaign, allow_blank: true
                string :notes, max_length: 2000, allow_blank: true
                id :store_id, bytes: 4
                hash :customer do
                  id :id, bytes: 4
                end
                hash :packaging do
                  optional {
                    string :box, :filler, :label, :note
                    array :line_items do
                      hash do
                        optional {
                          string :sku, :name, :size, :color, :variant
                          array :engravings do
                            hash do
                              string :key
                              float :x, :y, :rotation, :scale
                            end
                          end
                        }
                      end
                    end
                  }
                end
              }
            end
          }
        }
      },
      permit: lambda { |params|
        params.permit(
          :total, :payment_method, :express_shipping, coupon_ids: [],
          preferences: [:currency, :locale, :theme, :timezone, :referrer, :subscribe, interests: []],
          shipping: [
            :ship_on, :carrier, :address_type, :address_id, :email, :phone,
            :instructions, :save_address, address: [:name, :street, :city, :state, :zip]
          ],
          cart: [
            :channel, :campaign, :notes, :store_id, customer: [:id],
                                                    packaging: [
                                                      :box, :filler, :label, :note,
                                                      line_items: [:sku, :name, :size, :color, :variant, engravings: [:key, :x, :y, :rotation, :scale]]
                                                    ]
          ]
        )
      },
      interaction: Class.new(ActiveTypedParamsSpec::BenchmarkInteraction) {
        decimal :total, default: nil
        string :payment_method, default: nil
        boolean :express_shipping, default: nil
        array :coupon_ids, default: nil do
          integer
        end
        hash :preferences, default: nil do
          string :currency, :locale, :theme, :timezone, :referrer, default: nil
          boolean :subscribe, default: nil
          array :interests, default: nil do
            string
          end
        end
        hash :shipping, default: nil do
          date :ship_on, default: nil
          string :carrier, :address_type, :email, :phone, :instructions, default: nil
          integer :address_id, default: nil
          boolean :save_address, default: nil
          hash :address, default: nil do
            string :name, :street, :city, :state, :zip, default: nil
          end
        end
        hash :cart, default: nil do
          string :channel, :campaign, :notes, default: nil
          integer :store_id, default: nil
          hash :customer, default: nil do
            integer :id, default: nil
          end
          hash :packaging, default: nil do
            string :box, :filler, :label, :note, default: nil
            array :line_items, default: nil do
              hash do
                string :sku, :name, :size, :color, :variant, default: nil
                array :engravings, default: nil do
                  hash do
                    string :key, default: nil
                    float :x, :y, :rotation, :scale, default: nil
                  end
                end
              end
            end
          end
        end
      },
    )
  end

  def variants(benchmark_case)
    params = ActionController::Parameters.new(benchmark_case.payload)
    compiled = benchmark_case.controller
    compiled.new(params).send(:p)
    interaction = benchmark_case.interaction
    permit = benchmark_case.permit

    {
      "compiled" => -> { compiled.new(params).send(:p) },
      "params.permit" => -> { permit.call(params) },
      "ActiveInteraction" => -> { interaction.run(params) },
    }
  end

  def measure(callable)
    callable.call
    seconds = Benchmark.realtime { iterations.times { callable.call } }
    allocations = MemoryProfiler.report { callable.call }.total_allocated
    {ns: seconds / iterations * 1e9, allocations:}
  end

  def report(name, results)
    lines = results.map { |variant, result| format("  %-18s %10.0f ns/op %8d allocations", variant, result[:ns], result[:allocations]) }
    RSpec.configuration.reporter.message("\n#{name} (#{iterations} iterations, YJIT #{RubyVM::YJIT.enabled? ? "on" : "off"})\n#{lines.join("\n")}")
  end

  [:login, :search, :checkout].each do |name|
    it "validates #{name} parameters within the targets" do
      benchmark_case = send(name)
      results = variants(benchmark_case).transform_values { |callable| measure(callable) }
      report(benchmark_case.name, results)

      expect(results["compiled"][:ns]).to be < results["params.permit"][:ns]
      expect(results["compiled"][:ns]).to be < results["ActiveInteraction"][:ns] / 4
      expect(results["compiled"][:allocations]).to be < results["params.permit"][:allocations]
    end
  end

  it "builds and compiles the checkout schema in a few milliseconds, once" do
    schema = ActiveTypedParams.schema(checkout.controller, :p)
    block = schema.instance_variable_get(:@block)

    build = Array.new(10) { Benchmark.realtime { ActiveTypedParams::Builder.run(block) } }.min
    compile = Array.new(10) { Benchmark.realtime { ActiveTypedParams::Compiler.new(schema).source } }.min
    RSpec.configuration.reporter.message(
      format("\nbuild: %.2f ms; compile: %.2f ms; %d generated lines", build * 1000, compile * 1000, schema.source.lines.size),
    )

    expect(compile).to be < 0.005
  end
end
