# frozen_string_literal: true
def search_params(params = self.params, request = self.request)
  h0 = ActiveTypedParams::Runtime.raw(params)
  r0 = {}
  if h0.key?("page")
    v0 = h0["page"]
    if v0.nil? || v0 == ""
      r0[:page] = nil
    else
      v0 = ActiveTypedParams::Runtime.integer(v0) if v0.is_a?(String)
      ActiveTypedParams::Runtime.fail(:invalid_type, ["page"], :integer) unless v0.is_a?(Integer) && v0.bit_length < 64
      ActiveTypedParams::Runtime.fail(:not_allowed, ["page"]) unless RANGE_1.cover?(v0)
      r0[:page] = v0
    end
  else
    r0[:page] = 1
  end
  if h0.key?("page_size")
    v0 = h0["page_size"]
    if v0.nil? || v0 == ""
      r0[:page_size] = nil
    else
      v0 = ActiveTypedParams::Runtime.integer(v0) if v0.is_a?(String)
      ActiveTypedParams::Runtime.fail(:invalid_type, ["page_size"], :integer) unless v0.is_a?(Integer) && v0.bit_length < 64
      ActiveTypedParams::Runtime.fail(:not_allowed, ["page_size"]) unless ActiveTypedParams::Runtime.allowed?(instance_exec(&PROC_1), v0)
      r0[:page_size] = v0
    end
  end
  if h0.key?("sort_option")
    v0 = h0["sort_option"]
    if v0.nil?
      r0[:sort_option] = nil
    else
      v0 = ActiveTypedParams::Runtime.parse_json(v0, ["sort_option"], :hash) if v0.is_a?(String)
      h1 = ActiveTypedParams::Runtime.unwrap_hash(v0) || ActiveTypedParams::Runtime.fail(:invalid_type, ["sort_option"], :hash)
      r1 = {}
      if h1.key?("id")
        v1 = h1["id"]
        if v1.nil?
          r1[:id] = nil
        else
          ActiveTypedParams::Runtime.fail(:invalid_type, ["sort_option", "id"], :string) unless v1.is_a?(String) && !v1.include?("\0")
          ActiveTypedParams::Runtime.fail(:too_long, ["sort_option", "id"]) if v1.length > 512
          r1[:id] = v1
        end
      end
      if h1.key?("direction")
        v1 = h1["direction"]
        if v1.nil?
          r1[:direction] = nil
        else
          ActiveTypedParams::Runtime.fail(:invalid_type, ["sort_option", "direction"], :string) unless v1.is_a?(String) && !v1.include?("\0")
          ActiveTypedParams::Runtime.fail(:too_long, ["sort_option", "direction"]) if v1.length > 512
          ActiveTypedParams::Runtime.fail(:not_allowed, ["sort_option", "direction"]) unless SET_1.include?(v1)
          r1[:direction] = v1
        end
      end
      r0[:sort_option] = r1
    end
  end
  if h0.key?("search_filters")
    v0 = h0["search_filters"]
    if v0.nil?
      r0[:search_filters] = nil
    else
      v0 = ActiveTypedParams::Runtime.parse_json(v0, ["search_filters"], :array) if v0.is_a?(String)
      ActiveTypedParams::Runtime.fail(:invalid_type, ["search_filters"], :array) unless v0.is_a?(Array)
      ActiveTypedParams::Runtime.fail(:too_long, ["search_filters"]) if v0.length > 1000
      a1 = Array.new(v0.length)
      v0.each_with_index do |e1, i1|
        if e1.nil?
          ActiveTypedParams::Runtime.fail(:invalid_type, ["search_filters", i1], :hash)
        else
          h2 = ActiveTypedParams::Runtime.unwrap_hash(e1) || ActiveTypedParams::Runtime.fail(:invalid_type, ["search_filters", i1], :hash)
          r2 = {}
          if h2.key?("id")
            v2 = h2["id"]
            if v2.nil?
              r2[:id] = nil
            else
              ActiveTypedParams::Runtime.fail(:invalid_type, ["search_filters", i1, "id"], :string) unless v2.is_a?(String) && !v2.include?("\0")
              ActiveTypedParams::Runtime.fail(:too_long, ["search_filters", i1, "id"]) if v2.length > 512
              r2[:id] = v2
            end
          end
          if h2.key?("value")
            v2 = h2["value"]
            if v2.nil?
              r2[:value] = nil
            else
              v2 = ActiveTypedParams::Runtime.plain(v2)
              r2[:value] = v2
            end
          end
          a1[i1] = r2
        end
      end
      r0[:search_filters] = a1
    end
  end
  r0
rescue ActiveTypedParams::InvalidParameter => error
  ActiveTypedParams::Runtime.report_invalid(error, self)
  raise
end
