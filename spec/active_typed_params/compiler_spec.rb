# frozen_string_literal: true

require "spec_helper"

# The generated source for three representative schemas is kept under
# spec/fixtures, so codegen changes show up in review.
# Regenerate with UPDATE_SNAPSHOTS=1.
RSpec.describe ActiveTypedParams::Compiler, :active_typed_params do
  let(:fixtures) { File.expand_path("../fixtures", __dir__) }

  let(:login_controller) do
    Class.new(ActiveTypedParamsSpec::FakeController) {
      typed_params(:login_params) {
        required(user: [:email, :password])
      }
    }
  end

  let(:search_controller) do
    ActiveTypedParams.define(:pagination) {
      integer :page, in: 1..(2**31 - 1), default: 1
      integer :page_size, in: -> { 1..max_page_size }
    }

    Class.new(ActiveTypedParamsSpec::FakeController) {
      typed_params(:search_params, unknown: :ignore) {
        use :pagination
        param(
          sort_option: hash(:id, direction: string(in: %w[ASC DESC]), json: true),
          search_filters: array([:id, value: :any], json: true),
        )
      }
    }
  end

  let(:orders_controller) do
    Class.new(ActiveTypedParamsSpec::FakeController) {
      typed_params(:order_params, unknown: :report) {
        param(
          :payment_method,
          amount: :decimal,
          gift_wrap: :boolean,
          store_ids: array(id(bytes: 4)),
          delivery: [
            :recipient_email,
            :recipient_phone_number,
            :same_email_reason,
            delivery_date: :date,
            delivery_method: enum(%w[email mail text print]),
            recipient_type: string(in: ["User", "Contact"]),
            recipient_id: :id,
            save_delivery_information: :boolean,
            recipient_mailing_address: [:name, :street, :city, :state, :zip],
          ],
          greeting: [
            from: string(allow_blank: true),
            to: string(allow_blank: true),
            message: string(max_length: 2000, allow_blank: true),
            category_id: id(bytes: 4),
            card: [id: id(bytes: 4, required: true)],
            greeting_card_customization: [
              :sender,
              :recipient,
              :title,
              :note,
              story_slides: array([
                :photo,
                :video,
                :text,
                :frame,
                :color_filter,
                stickers: array(
                  key: string(required: true),
                  x: float(required: true),
                  y: float(required: true),
                  rotation: float(required: true),
                  scale: float(required: true),
                ),
              ]),
            ],
          ],
        )
      }
    }
  end

  def expect_snapshot(fixture, controller, name)
    source = ActiveTypedParams.source(controller, name)
    path = File.join(fixtures, "#{fixture}.rb")

    if ENV["UPDATE_SNAPSHOTS"]
      FileUtils.mkdir_p(fixtures)
      File.write(path, source)
    end

    expect(source).to eq(File.read(path))
  end

  it "generates the snapshotted source for a login form" do
    expect_snapshot("login", login_controller, :login_params)
  end

  it "generates the snapshotted source for a search request" do
    expect_snapshot("search", search_controller, :search_params)
  end

  it "generates the snapshotted source for an order draft" do
    expect_snapshot("order", orders_controller, :order_params)
  end

  it "defines allowlists, enum maps, procs and declared keys as constants on the compiled module" do
    schema = ActiveTypedParams.schema(search_controller, :search_params)
    schema.install!
    constants = schema.compiled_module.constants.sort

    expect(constants).to eq(%i[PROC_1 RANGE_1 SET_1])

    schema = ActiveTypedParams.schema(orders_controller, :order_params)
    schema.install!
    constants = schema.compiled_module.constants

    expect(constants).to include(:ENUM_1, :SET_1, :KEYS_1)
    expect(constants.count { |constant| constant.start_with?("KEYS_") }).to eq(8)
  end

  it "compiles the order schema in under 5ms once the nodes are built" do
    schema = ActiveTypedParams.schema(orders_controller, :order_params)
    schema.nodes

    elapsed = Array.new(5) { Benchmark.realtime { described_class.new(schema).source } }.min

    expect(elapsed).to be < 0.005
  end
end
