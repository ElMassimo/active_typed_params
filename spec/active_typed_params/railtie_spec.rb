# frozen_string_literal: true

require "spec_helper"
require "open3"

# Boots a Rails app in its own process, so that it leaves no state behind.
RSpec.describe "ActiveTypedParams::Railtie" do
  def boot(eager_load:)
    script = <<~RUBY
      require "rails"
      require "action_controller/railtie"
      require "active_typed_params"

      class App < Rails::Application
        config.eager_load = #{eager_load}
        config.logger = Logger.new(nil)
        config.secret_key_base = "test"

        # Runs during boot, as loading the app's controllers would.
        config.to_prepare do
          Object.const_set(:ContactsController, Class.new(ActionController::Base) { typed_params(:contact_params) { param(:name) } })
        end
      end

      App.initialize!
      schema = ActiveTypedParams.schema(ContactsController, :contact_params)
      statuses = %w[InvalidParameter UnprocessableParameter].map { |name|
        ActionDispatch::ExceptionWrapper.status_code_for_exception("ActiveTypedParams::\#{name}")
      }
      puts [ActionController::Base.include?(ActiveTypedParams::Controller), schema.installed?.inspect, *statuses].join(",")
    RUBY
    output, status = Open3.capture2e(RbConfig.ruby, "-Ilib", "-e", script, chdir: File.expand_path("../..", __dir__))
    expect(status).to be_success, output
    output.lines.last.chomp.split(",")
  end

  it "adds typed_params to controllers, and maps the errors to 400 and 422" do
    expect(boot(eager_load: false)).to eq(%w[true nil 400 422])
  end

  it "compiles every schema at boot when eager loading" do
    expect(boot(eager_load: true)).to eq(%w[true true 400 422])
  end
end
