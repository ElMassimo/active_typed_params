# frozen_string_literal: true
def login_params(params = self.params, request = self.request)
  h0 = ActiveTypedParams::Runtime.raw(params)
  r0 = {}
  if h0.key?("user")
    v0 = h0["user"]
    if v0.nil?
      ActiveTypedParams::Runtime.fail(:missing, ["user"], :hash)
    else
      h1 = ActiveTypedParams::Runtime.unwrap_hash(v0) || ActiveTypedParams::Runtime.fail(:invalid_type, ["user"], :hash)
      r1 = {}
      if h1.key?("email")
        v1 = h1["email"]
        if v1.nil?
          ActiveTypedParams::Runtime.fail(:missing, ["user", "email"], :string)
        else
          ActiveTypedParams::Runtime.fail(:invalid_type, ["user", "email"], :string) unless v1.is_a?(String) && !v1.include?("\0")
          ActiveTypedParams::Runtime.fail(:blank, ["user", "email"]) if v1.empty?
          ActiveTypedParams::Runtime.fail(:too_long, ["user", "email"]) if v1.length > 512
          r1[:email] = v1
        end
      else
        ActiveTypedParams::Runtime.fail(:missing, ["user", "email"])
      end
      if h1.key?("password")
        v1 = h1["password"]
        if v1.nil?
          ActiveTypedParams::Runtime.fail(:missing, ["user", "password"], :string)
        else
          ActiveTypedParams::Runtime.fail(:invalid_type, ["user", "password"], :string) unless v1.is_a?(String) && !v1.include?("\0")
          ActiveTypedParams::Runtime.fail(:blank, ["user", "password"]) if v1.empty?
          ActiveTypedParams::Runtime.fail(:too_long, ["user", "password"]) if v1.length > 512
          r1[:password] = v1
        end
      else
        ActiveTypedParams::Runtime.fail(:missing, ["user", "password"])
      end
      r0[:user] = r1
    end
  else
    ActiveTypedParams::Runtime.fail(:missing, ["user"])
  end
  r0
rescue ActiveTypedParams::InvalidParameter => error
  ActiveTypedParams::Runtime.report_invalid(error, self)
  raise
end
