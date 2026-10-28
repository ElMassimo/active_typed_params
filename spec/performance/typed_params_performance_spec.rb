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
      name: "save_draft (40 keys, 3 levels)",
      payload: {
        controller: "orders", action: "save_draft",
        amount: 50, payment_method: "card", gift_wrap: false, store_ids: [1, 2, 3],
        design_metadata: {design_name: "v3", background_color: "#fff", mask_name: "mask-1", mask_color: "#000", tagline: "Enjoy", is_custom_tagline: true, design_search_terms: %w[coffee brunch]},
        delivery: {
          delivery_date: "2026-12-24", delivery_method: "email", recipient_type: "Contact", recipient_id: 42,
          recipient_email: "friend@example.com", recipient_phone_number: "+15555550123", same_email_reason: "", save_delivery_information: true,
          recipient_mailing_address: {name: "Friend", street: "1 Main St", city: "Austin", state: "TX", zip: "78701"}
        },
        greeting: {
          from: "Max", to: "Friend", message: "Happy holidays!", category_id: 7, card: {id: 12},
          greeting_card_customization: {
            sender: "Max", recipient: "Friend", title: "Cheers", note: "See you soon",
            story_slides: [
              {photo: "blob-1", text: "One", frame: "classic", color_filter: "warm", stickers: [{key: "star", x: 0.1, y: 0.2, rotation: 0, scale: 1}, {key: "heart", x: 0.5, y: 0.5, rotation: 15, scale: 1.2}]},
              {photo: "blob-2", text: "Two", frame: "classic", color_filter: "cool", stickers: []},
            ]
          }
        }
      },
      controller: Class.new(ActiveTypedParamsSpec::FakeController) {
        typed_params(:p) {
          optional {
            decimal :amount
            string :payment_method
            boolean :gift_wrap
            array :store_ids, :id, bytes: 4
            hash :design_metadata do
              optional {
                string :design_name, :background_color, :mask_name, :mask_color, :tagline
                boolean :is_custom_tagline
                array :design_search_terms, :string
              }
            end
            hash :delivery do
              optional {
                date :delivery_date
                enum :delivery_method, %w[email mail text print]
                string :recipient_type, in: ["User", "Contact"], allow_nil: true
                id :recipient_id, allow_nil: true
                string :recipient_email, :recipient_phone_number, :same_email_reason
                boolean :save_delivery_information
                hash :recipient_mailing_address do
                  optional { string :name, :street, :city, :state, :zip }
                end
              }
            end
            hash :greeting do
              optional {
                string :from, :to, allow_blank: true
                string :message, max_length: 2000, allow_blank: true
                id :category_id, bytes: 4
                hash :card do
                  id :id, bytes: 4
                end
                hash :greeting_card_customization do
                  optional {
                    string :sender, :recipient, :title, :note
                    array :story_slides do
                      hash do
                        optional {
                          string :photo, :video, :text, :frame, :color_filter
                          array :stickers do
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
          :amount, :payment_method, :gift_wrap, store_ids: [],
          design_metadata: [:design_name, :background_color, :mask_name, :mask_color, :tagline, :is_custom_tagline, design_search_terms: []],
          delivery: [
            :delivery_date, :delivery_method, :recipient_type, :recipient_id, :recipient_email, :recipient_phone_number,
            :same_email_reason, :save_delivery_information, recipient_mailing_address: [:name, :street, :city, :state, :zip]
          ],
          greeting: [
            :from, :to, :message, :category_id, card: [:id],
                                                greeting_card_customization: [
                                                  :sender, :recipient, :title, :note,
                                                  story_slides: [:photo, :video, :text, :frame, :color_filter, stickers: [:key, :x, :y, :rotation, :scale]]
                                                ]
          ]
        )
      },
      interaction: Class.new(ActiveTypedParamsSpec::BenchmarkInteraction) {
        decimal :amount, default: nil
        string :payment_method, default: nil
        boolean :gift_wrap, default: nil
        array :store_ids, default: nil do
          integer
        end
        hash :design_metadata, default: nil do
          string :design_name, :background_color, :mask_name, :mask_color, :tagline, default: nil
          boolean :is_custom_tagline, default: nil
          array :design_search_terms, default: nil do
            string
          end
        end
        hash :delivery, default: nil do
          date :delivery_date, default: nil
          string :delivery_method, :recipient_type, :recipient_email, :recipient_phone_number, :same_email_reason, default: nil
          integer :recipient_id, default: nil
          boolean :save_delivery_information, default: nil
          hash :recipient_mailing_address, default: nil do
            string :name, :street, :city, :state, :zip, default: nil
          end
        end
        hash :greeting, default: nil do
          string :from, :to, :message, default: nil
          integer :category_id, default: nil
          hash :card, default: nil do
            integer :id, default: nil
          end
          hash :greeting_card_customization, default: nil do
            string :sender, :recipient, :title, :note, default: nil
            array :story_slides, default: nil do
              hash do
                string :photo, :video, :text, :frame, :color_filter, default: nil
                array :stickers, default: nil do
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

  it "builds and compiles the save_draft schema in a few milliseconds, once" do
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
