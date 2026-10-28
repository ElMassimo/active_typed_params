# frozen_string_literal: true

require "spec_helper"

RSpec.describe ActiveTypedParams::Runtime, :active_typed_params do
  def parameters_for(path, **env)
    request = ActionDispatch::Request.new(Rack::MockRequest.env_for(path, **env))
    ActionController::Parameters.new(request.parameters)
  end

  # Guards the one Rails internal the library reads: the hash behind
  # ActionController::Parameters must match what `to_unsafe_h` exposes.
  it "reads the same keys and values as to_unsafe_h for JSON, form and query parameters" do
    requests = {
      json: parameters_for("/users/7?debug=1", method: "POST", input: '{"user":{"email":"a","tags":["x"],"address":{"zip":"1"}},"n":1}', "CONTENT_TYPE" => "application/json"),
      form: parameters_for("/users/7", method: "POST", input: "user[email]=a&user[tags][]=x&user[address][zip]=1", "CONTENT_TYPE" => "application/x-www-form-urlencoded"),
      query: parameters_for("/users?page=2&ids[]=1&ids[]=2&user[email]=a"),
    }

    requests.each do |kind, params|
      raw = described_class.raw(params)
      expect(raw).to eq(params.to_unsafe_h), "#{kind} parameters diverged"
      expect(raw).to be_a(ActiveSupport::HashWithIndifferentAccess)
      expect(raw.keys).to all(be_a(String))
    end

    nested = requests[:json]
    nested[:user]
    nested[:user][:tags]
    expect(described_class.unwrap_hash(described_class.raw(nested)["user"])).to eq(nested[:user].to_unsafe_h)
    expect(described_class.raw(nested)["n"]).to eq(1)
  end

  it "accepts plain hashes, converting them to indifferent access, and rejects other inputs" do
    expect(described_class.raw({a: {b: 1}})["a"]["b"]).to eq(1)
    expect(described_class.unwrap_hash("x")).to be_nil
    expect { described_class.raw("x") }.to raise_error(ArgumentError)
  end
end
