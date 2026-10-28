# frozen_string_literal: true
def order_params(params = self.params, request = self.request)
  h0 = ActiveTypedParams::Runtime.raw(params)
  r0 = {}
  n0 = 0
  if h0.key?("payment_method")
    n0 += 1
    v0 = h0["payment_method"]
    if v0.nil?
      r0[:payment_method] = nil
    else
      ActiveTypedParams::Runtime.fail(:invalid_type, ["payment_method"], :string) unless v0.is_a?(String) && !v0.include?("\0")
      ActiveTypedParams::Runtime.fail(:too_long, ["payment_method"]) if v0.length > 512
      r0[:payment_method] = v0
    end
  end
  if h0.key?("total")
    n0 += 1
    v0 = h0["total"]
    if v0.nil? || v0 == ""
      r0[:total] = nil
    else
      v0 = ActiveTypedParams::Runtime.decimal(v0)
      ActiveTypedParams::Runtime.fail(:invalid_type, ["total"], :decimal) if v0.nil?
      r0[:total] = v0
    end
  end
  if h0.key?("express_shipping")
    n0 += 1
    v0 = h0["express_shipping"]
    if v0.nil? || v0 == ""
      r0[:express_shipping] = nil
    else
      v0 = ActiveTypedParams::Runtime.boolean(v0)
      ActiveTypedParams::Runtime.fail(:invalid_type, ["express_shipping"], :boolean) if v0.nil?
      r0[:express_shipping] = v0
    end
  end
  if h0.key?("coupon_ids")
    n0 += 1
    v0 = h0["coupon_ids"]
    if v0.nil?
      r0[:coupon_ids] = nil
    else
      ActiveTypedParams::Runtime.fail(:invalid_type, ["coupon_ids"], :array) unless v0.is_a?(Array)
      ActiveTypedParams::Runtime.fail(:too_long, ["coupon_ids"]) if v0.length > 1000
      a1 = Array.new(v0.length)
      v0.each_with_index do |e1, i1|
        if e1.nil? || e1 == ""
          ActiveTypedParams::Runtime.fail(:invalid_type, ["coupon_ids", i1], :id)
        else
          e1 = ActiveTypedParams::Runtime.integer(e1) if e1.is_a?(String)
          ActiveTypedParams::Runtime.fail(:invalid_type, ["coupon_ids", i1], :id) unless e1.is_a?(Integer) && e1 > 0 && e1 < 2147483648
          a1[i1] = e1
        end
      end
      r0[:coupon_ids] = a1
    end
  end
  if h0.key?("shipping")
    n0 += 1
    v0 = h0["shipping"]
    if v0.nil?
      r0[:shipping] = nil
    else
      h1 = ActiveTypedParams::Runtime.unwrap_hash(v0) || ActiveTypedParams::Runtime.fail(:invalid_type, ["shipping"], :hash)
      r1 = {}
      n1 = 0
      if h1.key?("email")
        n1 += 1
        v1 = h1["email"]
        if v1.nil?
          r1[:email] = nil
        else
          ActiveTypedParams::Runtime.fail(:invalid_type, ["shipping", "email"], :string) unless v1.is_a?(String) && !v1.include?("\0")
          ActiveTypedParams::Runtime.fail(:too_long, ["shipping", "email"]) if v1.length > 512
          r1[:email] = v1
        end
      end
      if h1.key?("phone")
        n1 += 1
        v1 = h1["phone"]
        if v1.nil?
          r1[:phone] = nil
        else
          ActiveTypedParams::Runtime.fail(:invalid_type, ["shipping", "phone"], :string) unless v1.is_a?(String) && !v1.include?("\0")
          ActiveTypedParams::Runtime.fail(:too_long, ["shipping", "phone"]) if v1.length > 512
          r1[:phone] = v1
        end
      end
      if h1.key?("instructions")
        n1 += 1
        v1 = h1["instructions"]
        if v1.nil?
          r1[:instructions] = nil
        else
          ActiveTypedParams::Runtime.fail(:invalid_type, ["shipping", "instructions"], :string) unless v1.is_a?(String) && !v1.include?("\0")
          ActiveTypedParams::Runtime.fail(:too_long, ["shipping", "instructions"]) if v1.length > 512
          r1[:instructions] = v1
        end
      end
      if h1.key?("ship_on")
        n1 += 1
        v1 = h1["ship_on"]
        if v1.nil? || v1 == ""
          r1[:ship_on] = nil
        else
          v1 = ActiveTypedParams::Runtime.date(v1)
          ActiveTypedParams::Runtime.fail(:invalid_type, ["shipping", "ship_on"], :date) if v1.nil?
          r1[:ship_on] = v1
        end
      end
      if h1.key?("carrier")
        n1 += 1
        v1 = h1["carrier"]
        if v1.nil? || v1 == ""
          r1[:carrier] = nil
        else
          v1 = ENUM_1.fetch(v1) { ActiveTypedParams::Runtime.fail(:not_allowed, ["shipping", "carrier"]) }
          r1[:carrier] = v1
        end
      end
      if h1.key?("address_type")
        n1 += 1
        v1 = h1["address_type"]
        if v1.nil?
          r1[:address_type] = nil
        else
          ActiveTypedParams::Runtime.fail(:invalid_type, ["shipping", "address_type"], :string) unless v1.is_a?(String) && !v1.include?("\0")
          ActiveTypedParams::Runtime.fail(:too_long, ["shipping", "address_type"]) if v1.length > 512
          ActiveTypedParams::Runtime.fail(:not_allowed, ["shipping", "address_type"]) unless SET_1.include?(v1)
          r1[:address_type] = v1
        end
      end
      if h1.key?("address_id")
        n1 += 1
        v1 = h1["address_id"]
        if v1.nil? || v1 == ""
          r1[:address_id] = nil
        else
          v1 = ActiveTypedParams::Runtime.integer(v1) if v1.is_a?(String)
          ActiveTypedParams::Runtime.fail(:invalid_type, ["shipping", "address_id"], :id) unless v1.is_a?(Integer) && v1 > 0 && v1 < 9223372036854775808
          r1[:address_id] = v1
        end
      end
      if h1.key?("save_address")
        n1 += 1
        v1 = h1["save_address"]
        if v1.nil? || v1 == ""
          r1[:save_address] = nil
        else
          v1 = ActiveTypedParams::Runtime.boolean(v1)
          ActiveTypedParams::Runtime.fail(:invalid_type, ["shipping", "save_address"], :boolean) if v1.nil?
          r1[:save_address] = v1
        end
      end
      if h1.key?("address")
        n1 += 1
        v1 = h1["address"]
        if v1.nil?
          r1[:address] = nil
        else
          h2 = ActiveTypedParams::Runtime.unwrap_hash(v1) || ActiveTypedParams::Runtime.fail(:invalid_type, ["shipping", "address"], :hash)
          r2 = {}
          n2 = 0
          if h2.key?("name")
            n2 += 1
            v2 = h2["name"]
            if v2.nil?
              r2[:name] = nil
            else
              ActiveTypedParams::Runtime.fail(:invalid_type, ["shipping", "address", "name"], :string) unless v2.is_a?(String) && !v2.include?("\0")
              ActiveTypedParams::Runtime.fail(:too_long, ["shipping", "address", "name"]) if v2.length > 512
              r2[:name] = v2
            end
          end
          if h2.key?("street")
            n2 += 1
            v2 = h2["street"]
            if v2.nil?
              r2[:street] = nil
            else
              ActiveTypedParams::Runtime.fail(:invalid_type, ["shipping", "address", "street"], :string) unless v2.is_a?(String) && !v2.include?("\0")
              ActiveTypedParams::Runtime.fail(:too_long, ["shipping", "address", "street"]) if v2.length > 512
              r2[:street] = v2
            end
          end
          if h2.key?("city")
            n2 += 1
            v2 = h2["city"]
            if v2.nil?
              r2[:city] = nil
            else
              ActiveTypedParams::Runtime.fail(:invalid_type, ["shipping", "address", "city"], :string) unless v2.is_a?(String) && !v2.include?("\0")
              ActiveTypedParams::Runtime.fail(:too_long, ["shipping", "address", "city"]) if v2.length > 512
              r2[:city] = v2
            end
          end
          if h2.key?("state")
            n2 += 1
            v2 = h2["state"]
            if v2.nil?
              r2[:state] = nil
            else
              ActiveTypedParams::Runtime.fail(:invalid_type, ["shipping", "address", "state"], :string) unless v2.is_a?(String) && !v2.include?("\0")
              ActiveTypedParams::Runtime.fail(:too_long, ["shipping", "address", "state"]) if v2.length > 512
              r2[:state] = v2
            end
          end
          if h2.key?("zip")
            n2 += 1
            v2 = h2["zip"]
            if v2.nil?
              r2[:zip] = nil
            else
              ActiveTypedParams::Runtime.fail(:invalid_type, ["shipping", "address", "zip"], :string) unless v2.is_a?(String) && !v2.include?("\0")
              ActiveTypedParams::Runtime.fail(:too_long, ["shipping", "address", "zip"]) if v2.length > 512
              r2[:zip] = v2
            end
          end
          ActiveTypedParams::Runtime.check_unknown(h2, KEYS_1, :report, PATH_1, self, nil) if h2.size > n2
          r1[:address] = r2
        end
      end
      ActiveTypedParams::Runtime.check_unknown(h1, KEYS_2, :report, PATH_2, self, nil) if h1.size > n1
      r0[:shipping] = r1
    end
  end
  if h0.key?("cart")
    n0 += 1
    v0 = h0["cart"]
    if v0.nil?
      r0[:cart] = nil
    else
      h1 = ActiveTypedParams::Runtime.unwrap_hash(v0) || ActiveTypedParams::Runtime.fail(:invalid_type, ["cart"], :hash)
      r1 = {}
      n1 = 0
      if h1.key?("channel")
        n1 += 1
        v1 = h1["channel"]
        if v1.nil?
          r1[:channel] = nil
        else
          ActiveTypedParams::Runtime.fail(:invalid_type, ["cart", "channel"], :string) unless v1.is_a?(String) && !v1.include?("\0")
          ActiveTypedParams::Runtime.fail(:too_long, ["cart", "channel"]) if v1.length > 512
          r1[:channel] = v1
        end
      end
      if h1.key?("campaign")
        n1 += 1
        v1 = h1["campaign"]
        if v1.nil?
          r1[:campaign] = nil
        else
          ActiveTypedParams::Runtime.fail(:invalid_type, ["cart", "campaign"], :string) unless v1.is_a?(String) && !v1.include?("\0")
          ActiveTypedParams::Runtime.fail(:too_long, ["cart", "campaign"]) if v1.length > 512
          r1[:campaign] = v1
        end
      end
      if h1.key?("notes")
        n1 += 1
        v1 = h1["notes"]
        if v1.nil?
          r1[:notes] = nil
        else
          ActiveTypedParams::Runtime.fail(:invalid_type, ["cart", "notes"], :string) unless v1.is_a?(String) && !v1.include?("\0")
          ActiveTypedParams::Runtime.fail(:too_long, ["cart", "notes"]) if v1.length > 2000
          r1[:notes] = v1
        end
      end
      if h1.key?("store_id")
        n1 += 1
        v1 = h1["store_id"]
        if v1.nil? || v1 == ""
          r1[:store_id] = nil
        else
          v1 = ActiveTypedParams::Runtime.integer(v1) if v1.is_a?(String)
          ActiveTypedParams::Runtime.fail(:invalid_type, ["cart", "store_id"], :id) unless v1.is_a?(Integer) && v1 > 0 && v1 < 2147483648
          r1[:store_id] = v1
        end
      end
      if h1.key?("customer")
        n1 += 1
        v1 = h1["customer"]
        if v1.nil?
          r1[:customer] = nil
        else
          h2 = ActiveTypedParams::Runtime.unwrap_hash(v1) || ActiveTypedParams::Runtime.fail(:invalid_type, ["cart", "customer"], :hash)
          r2 = {}
          n2 = 0
          if h2.key?("id")
            n2 += 1
            v2 = h2["id"]
            if v2.nil? || v2 == ""
              ActiveTypedParams::Runtime.fail(:missing, ["cart", "customer", "id"], :id)
            else
              v2 = ActiveTypedParams::Runtime.integer(v2) if v2.is_a?(String)
              ActiveTypedParams::Runtime.fail(:invalid_type, ["cart", "customer", "id"], :id) unless v2.is_a?(Integer) && v2 > 0 && v2 < 2147483648
              r2[:id] = v2
            end
          else
            ActiveTypedParams::Runtime.fail(:missing, ["cart", "customer", "id"])
          end
          ActiveTypedParams::Runtime.check_unknown(h2, KEYS_3, :report, PATH_3, self, nil) if h2.size > n2
          r1[:customer] = r2
        end
      end
      if h1.key?("packaging")
        n1 += 1
        v1 = h1["packaging"]
        if v1.nil?
          r1[:packaging] = nil
        else
          h2 = ActiveTypedParams::Runtime.unwrap_hash(v1) || ActiveTypedParams::Runtime.fail(:invalid_type, ["cart", "packaging"], :hash)
          r2 = {}
          n2 = 0
          if h2.key?("box")
            n2 += 1
            v2 = h2["box"]
            if v2.nil?
              r2[:box] = nil
            else
              ActiveTypedParams::Runtime.fail(:invalid_type, ["cart", "packaging", "box"], :string) unless v2.is_a?(String) && !v2.include?("\0")
              ActiveTypedParams::Runtime.fail(:too_long, ["cart", "packaging", "box"]) if v2.length > 512
              r2[:box] = v2
            end
          end
          if h2.key?("filler")
            n2 += 1
            v2 = h2["filler"]
            if v2.nil?
              r2[:filler] = nil
            else
              ActiveTypedParams::Runtime.fail(:invalid_type, ["cart", "packaging", "filler"], :string) unless v2.is_a?(String) && !v2.include?("\0")
              ActiveTypedParams::Runtime.fail(:too_long, ["cart", "packaging", "filler"]) if v2.length > 512
              r2[:filler] = v2
            end
          end
          if h2.key?("label")
            n2 += 1
            v2 = h2["label"]
            if v2.nil?
              r2[:label] = nil
            else
              ActiveTypedParams::Runtime.fail(:invalid_type, ["cart", "packaging", "label"], :string) unless v2.is_a?(String) && !v2.include?("\0")
              ActiveTypedParams::Runtime.fail(:too_long, ["cart", "packaging", "label"]) if v2.length > 512
              r2[:label] = v2
            end
          end
          if h2.key?("note")
            n2 += 1
            v2 = h2["note"]
            if v2.nil?
              r2[:note] = nil
            else
              ActiveTypedParams::Runtime.fail(:invalid_type, ["cart", "packaging", "note"], :string) unless v2.is_a?(String) && !v2.include?("\0")
              ActiveTypedParams::Runtime.fail(:too_long, ["cart", "packaging", "note"]) if v2.length > 512
              r2[:note] = v2
            end
          end
          if h2.key?("line_items")
            n2 += 1
            v2 = h2["line_items"]
            if v2.nil?
              r2[:line_items] = nil
            else
              ActiveTypedParams::Runtime.fail(:invalid_type, ["cart", "packaging", "line_items"], :array) unless v2.is_a?(Array)
              ActiveTypedParams::Runtime.fail(:too_long, ["cart", "packaging", "line_items"]) if v2.length > 1000
              a3 = Array.new(v2.length)
              v2.each_with_index do |e3, i3|
                if e3.nil?
                  ActiveTypedParams::Runtime.fail(:invalid_type, ["cart", "packaging", "line_items", i3], :hash)
                else
                  h4 = ActiveTypedParams::Runtime.unwrap_hash(e3) || ActiveTypedParams::Runtime.fail(:invalid_type, ["cart", "packaging", "line_items", i3], :hash)
                  r4 = {}
                  n4 = 0
                  if h4.key?("sku")
                    n4 += 1
                    v4 = h4["sku"]
                    if v4.nil?
                      r4[:sku] = nil
                    else
                      ActiveTypedParams::Runtime.fail(:invalid_type, ["cart", "packaging", "line_items", i3, "sku"], :string) unless v4.is_a?(String) && !v4.include?("\0")
                      ActiveTypedParams::Runtime.fail(:too_long, ["cart", "packaging", "line_items", i3, "sku"]) if v4.length > 512
                      r4[:sku] = v4
                    end
                  end
                  if h4.key?("name")
                    n4 += 1
                    v4 = h4["name"]
                    if v4.nil?
                      r4[:name] = nil
                    else
                      ActiveTypedParams::Runtime.fail(:invalid_type, ["cart", "packaging", "line_items", i3, "name"], :string) unless v4.is_a?(String) && !v4.include?("\0")
                      ActiveTypedParams::Runtime.fail(:too_long, ["cart", "packaging", "line_items", i3, "name"]) if v4.length > 512
                      r4[:name] = v4
                    end
                  end
                  if h4.key?("size")
                    n4 += 1
                    v4 = h4["size"]
                    if v4.nil?
                      r4[:size] = nil
                    else
                      ActiveTypedParams::Runtime.fail(:invalid_type, ["cart", "packaging", "line_items", i3, "size"], :string) unless v4.is_a?(String) && !v4.include?("\0")
                      ActiveTypedParams::Runtime.fail(:too_long, ["cart", "packaging", "line_items", i3, "size"]) if v4.length > 512
                      r4[:size] = v4
                    end
                  end
                  if h4.key?("color")
                    n4 += 1
                    v4 = h4["color"]
                    if v4.nil?
                      r4[:color] = nil
                    else
                      ActiveTypedParams::Runtime.fail(:invalid_type, ["cart", "packaging", "line_items", i3, "color"], :string) unless v4.is_a?(String) && !v4.include?("\0")
                      ActiveTypedParams::Runtime.fail(:too_long, ["cart", "packaging", "line_items", i3, "color"]) if v4.length > 512
                      r4[:color] = v4
                    end
                  end
                  if h4.key?("variant")
                    n4 += 1
                    v4 = h4["variant"]
                    if v4.nil?
                      r4[:variant] = nil
                    else
                      ActiveTypedParams::Runtime.fail(:invalid_type, ["cart", "packaging", "line_items", i3, "variant"], :string) unless v4.is_a?(String) && !v4.include?("\0")
                      ActiveTypedParams::Runtime.fail(:too_long, ["cart", "packaging", "line_items", i3, "variant"]) if v4.length > 512
                      r4[:variant] = v4
                    end
                  end
                  if h4.key?("engravings")
                    n4 += 1
                    v4 = h4["engravings"]
                    if v4.nil?
                      r4[:engravings] = nil
                    else
                      ActiveTypedParams::Runtime.fail(:invalid_type, ["cart", "packaging", "line_items", i3, "engravings"], :array) unless v4.is_a?(Array)
                      ActiveTypedParams::Runtime.fail(:too_long, ["cart", "packaging", "line_items", i3, "engravings"]) if v4.length > 1000
                      a5 = Array.new(v4.length)
                      v4.each_with_index do |e5, i5|
                        if e5.nil?
                          ActiveTypedParams::Runtime.fail(:invalid_type, ["cart", "packaging", "line_items", i3, "engravings", i5], :hash)
                        else
                          h6 = ActiveTypedParams::Runtime.unwrap_hash(e5) || ActiveTypedParams::Runtime.fail(:invalid_type, ["cart", "packaging", "line_items", i3, "engravings", i5], :hash)
                          r6 = {}
                          n6 = 0
                          if h6.key?("key")
                            n6 += 1
                            v6 = h6["key"]
                            if v6.nil?
                              ActiveTypedParams::Runtime.fail(:missing, ["cart", "packaging", "line_items", i3, "engravings", i5, "key"], :string)
                            else
                              ActiveTypedParams::Runtime.fail(:invalid_type, ["cart", "packaging", "line_items", i3, "engravings", i5, "key"], :string) unless v6.is_a?(String) && !v6.include?("\0")
                              ActiveTypedParams::Runtime.fail(:blank, ["cart", "packaging", "line_items", i3, "engravings", i5, "key"]) if v6.empty?
                              ActiveTypedParams::Runtime.fail(:too_long, ["cart", "packaging", "line_items", i3, "engravings", i5, "key"]) if v6.length > 512
                              r6[:key] = v6
                            end
                          else
                            ActiveTypedParams::Runtime.fail(:missing, ["cart", "packaging", "line_items", i3, "engravings", i5, "key"])
                          end
                          if h6.key?("x")
                            n6 += 1
                            v6 = h6["x"]
                            if v6.nil? || v6 == ""
                              ActiveTypedParams::Runtime.fail(:missing, ["cart", "packaging", "line_items", i3, "engravings", i5, "x"], :float)
                            else
                              v6 = ActiveTypedParams::Runtime.float(v6)
                              ActiveTypedParams::Runtime.fail(:invalid_type, ["cart", "packaging", "line_items", i3, "engravings", i5, "x"], :float) if v6.nil?
                              r6[:x] = v6
                            end
                          else
                            ActiveTypedParams::Runtime.fail(:missing, ["cart", "packaging", "line_items", i3, "engravings", i5, "x"])
                          end
                          if h6.key?("y")
                            n6 += 1
                            v6 = h6["y"]
                            if v6.nil? || v6 == ""
                              ActiveTypedParams::Runtime.fail(:missing, ["cart", "packaging", "line_items", i3, "engravings", i5, "y"], :float)
                            else
                              v6 = ActiveTypedParams::Runtime.float(v6)
                              ActiveTypedParams::Runtime.fail(:invalid_type, ["cart", "packaging", "line_items", i3, "engravings", i5, "y"], :float) if v6.nil?
                              r6[:y] = v6
                            end
                          else
                            ActiveTypedParams::Runtime.fail(:missing, ["cart", "packaging", "line_items", i3, "engravings", i5, "y"])
                          end
                          if h6.key?("rotation")
                            n6 += 1
                            v6 = h6["rotation"]
                            if v6.nil? || v6 == ""
                              ActiveTypedParams::Runtime.fail(:missing, ["cart", "packaging", "line_items", i3, "engravings", i5, "rotation"], :float)
                            else
                              v6 = ActiveTypedParams::Runtime.float(v6)
                              ActiveTypedParams::Runtime.fail(:invalid_type, ["cart", "packaging", "line_items", i3, "engravings", i5, "rotation"], :float) if v6.nil?
                              r6[:rotation] = v6
                            end
                          else
                            ActiveTypedParams::Runtime.fail(:missing, ["cart", "packaging", "line_items", i3, "engravings", i5, "rotation"])
                          end
                          if h6.key?("scale")
                            n6 += 1
                            v6 = h6["scale"]
                            if v6.nil? || v6 == ""
                              ActiveTypedParams::Runtime.fail(:missing, ["cart", "packaging", "line_items", i3, "engravings", i5, "scale"], :float)
                            else
                              v6 = ActiveTypedParams::Runtime.float(v6)
                              ActiveTypedParams::Runtime.fail(:invalid_type, ["cart", "packaging", "line_items", i3, "engravings", i5, "scale"], :float) if v6.nil?
                              r6[:scale] = v6
                            end
                          else
                            ActiveTypedParams::Runtime.fail(:missing, ["cart", "packaging", "line_items", i3, "engravings", i5, "scale"])
                          end
                          ActiveTypedParams::Runtime.check_unknown(h6, KEYS_4, :report, ["cart", "packaging", "line_items", i3, "engravings", i5], self, nil) if h6.size > n6
                          a5[i5] = r6
                        end
                      end
                      r4[:engravings] = a5
                    end
                  end
                  ActiveTypedParams::Runtime.check_unknown(h4, KEYS_5, :report, ["cart", "packaging", "line_items", i3], self, nil) if h4.size > n4
                  a3[i3] = r4
                end
              end
              r2[:line_items] = a3
            end
          end
          ActiveTypedParams::Runtime.check_unknown(h2, KEYS_6, :report, PATH_4, self, nil) if h2.size > n2
          r1[:packaging] = r2
        end
      end
      ActiveTypedParams::Runtime.check_unknown(h1, KEYS_7, :report, PATH_5, self, nil) if h1.size > n1
      r0[:cart] = r1
    end
  end
  ActiveTypedParams::Runtime.check_unknown(h0, KEYS_8, :report, PATH_6, self, request) if h0.size > n0
  r0
rescue ActiveTypedParams::InvalidParameter => error
  ActiveTypedParams::Runtime.report_invalid(error, self)
  raise
end
