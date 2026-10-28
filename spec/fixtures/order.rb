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
  if h0.key?("amount")
    n0 += 1
    v0 = h0["amount"]
    if v0.nil? || v0 == ""
      r0[:amount] = nil
    else
      v0 = ActiveTypedParams::Runtime.decimal(v0)
      ActiveTypedParams::Runtime.fail(:invalid_type, ["amount"], :decimal) if v0.nil?
      r0[:amount] = v0
    end
  end
  if h0.key?("gift_wrap")
    n0 += 1
    v0 = h0["gift_wrap"]
    if v0.nil? || v0 == ""
      r0[:gift_wrap] = nil
    else
      v0 = ActiveTypedParams::Runtime.boolean(v0)
      ActiveTypedParams::Runtime.fail(:invalid_type, ["gift_wrap"], :boolean) if v0.nil?
      r0[:gift_wrap] = v0
    end
  end
  if h0.key?("store_ids")
    n0 += 1
    v0 = h0["store_ids"]
    if v0.nil?
      r0[:store_ids] = nil
    else
      ActiveTypedParams::Runtime.fail(:invalid_type, ["store_ids"], :array) unless v0.is_a?(Array)
      ActiveTypedParams::Runtime.fail(:too_long, ["store_ids"]) if v0.length > 1000
      a1 = Array.new(v0.length)
      v0.each_with_index do |e1, i1|
        if e1.nil? || e1 == ""
          ActiveTypedParams::Runtime.fail(:invalid_type, ["store_ids", i1], :id)
        else
          e1 = ActiveTypedParams::Runtime.integer(e1) if e1.is_a?(String)
          ActiveTypedParams::Runtime.fail(:invalid_type, ["store_ids", i1], :id) unless e1.is_a?(Integer) && e1 > 0 && e1 < 2147483648
          a1[i1] = e1
        end
      end
      r0[:store_ids] = a1
    end
  end
  if h0.key?("delivery")
    n0 += 1
    v0 = h0["delivery"]
    if v0.nil?
      r0[:delivery] = nil
    else
      h1 = ActiveTypedParams::Runtime.unwrap_hash(v0) || ActiveTypedParams::Runtime.fail(:invalid_type, ["delivery"], :hash)
      r1 = {}
      n1 = 0
      if h1.key?("recipient_email")
        n1 += 1
        v1 = h1["recipient_email"]
        if v1.nil?
          r1[:recipient_email] = nil
        else
          ActiveTypedParams::Runtime.fail(:invalid_type, ["delivery", "recipient_email"], :string) unless v1.is_a?(String) && !v1.include?("\0")
          ActiveTypedParams::Runtime.fail(:too_long, ["delivery", "recipient_email"]) if v1.length > 512
          r1[:recipient_email] = v1
        end
      end
      if h1.key?("recipient_phone_number")
        n1 += 1
        v1 = h1["recipient_phone_number"]
        if v1.nil?
          r1[:recipient_phone_number] = nil
        else
          ActiveTypedParams::Runtime.fail(:invalid_type, ["delivery", "recipient_phone_number"], :string) unless v1.is_a?(String) && !v1.include?("\0")
          ActiveTypedParams::Runtime.fail(:too_long, ["delivery", "recipient_phone_number"]) if v1.length > 512
          r1[:recipient_phone_number] = v1
        end
      end
      if h1.key?("same_email_reason")
        n1 += 1
        v1 = h1["same_email_reason"]
        if v1.nil?
          r1[:same_email_reason] = nil
        else
          ActiveTypedParams::Runtime.fail(:invalid_type, ["delivery", "same_email_reason"], :string) unless v1.is_a?(String) && !v1.include?("\0")
          ActiveTypedParams::Runtime.fail(:too_long, ["delivery", "same_email_reason"]) if v1.length > 512
          r1[:same_email_reason] = v1
        end
      end
      if h1.key?("delivery_date")
        n1 += 1
        v1 = h1["delivery_date"]
        if v1.nil? || v1 == ""
          r1[:delivery_date] = nil
        else
          v1 = ActiveTypedParams::Runtime.date(v1)
          ActiveTypedParams::Runtime.fail(:invalid_type, ["delivery", "delivery_date"], :date) if v1.nil?
          r1[:delivery_date] = v1
        end
      end
      if h1.key?("delivery_method")
        n1 += 1
        v1 = h1["delivery_method"]
        if v1.nil? || v1 == ""
          r1[:delivery_method] = nil
        else
          v1 = ENUM_1.fetch(v1) { ActiveTypedParams::Runtime.fail(:not_allowed, ["delivery", "delivery_method"]) }
          r1[:delivery_method] = v1
        end
      end
      if h1.key?("recipient_type")
        n1 += 1
        v1 = h1["recipient_type"]
        if v1.nil?
          r1[:recipient_type] = nil
        else
          ActiveTypedParams::Runtime.fail(:invalid_type, ["delivery", "recipient_type"], :string) unless v1.is_a?(String) && !v1.include?("\0")
          ActiveTypedParams::Runtime.fail(:too_long, ["delivery", "recipient_type"]) if v1.length > 512
          ActiveTypedParams::Runtime.fail(:not_allowed, ["delivery", "recipient_type"]) unless SET_1.include?(v1)
          r1[:recipient_type] = v1
        end
      end
      if h1.key?("recipient_id")
        n1 += 1
        v1 = h1["recipient_id"]
        if v1.nil? || v1 == ""
          r1[:recipient_id] = nil
        else
          v1 = ActiveTypedParams::Runtime.integer(v1) if v1.is_a?(String)
          ActiveTypedParams::Runtime.fail(:invalid_type, ["delivery", "recipient_id"], :id) unless v1.is_a?(Integer) && v1 > 0 && v1 < 9223372036854775808
          r1[:recipient_id] = v1
        end
      end
      if h1.key?("save_delivery_information")
        n1 += 1
        v1 = h1["save_delivery_information"]
        if v1.nil? || v1 == ""
          r1[:save_delivery_information] = nil
        else
          v1 = ActiveTypedParams::Runtime.boolean(v1)
          ActiveTypedParams::Runtime.fail(:invalid_type, ["delivery", "save_delivery_information"], :boolean) if v1.nil?
          r1[:save_delivery_information] = v1
        end
      end
      if h1.key?("recipient_mailing_address")
        n1 += 1
        v1 = h1["recipient_mailing_address"]
        if v1.nil?
          r1[:recipient_mailing_address] = nil
        else
          h2 = ActiveTypedParams::Runtime.unwrap_hash(v1) || ActiveTypedParams::Runtime.fail(:invalid_type, ["delivery", "recipient_mailing_address"], :hash)
          r2 = {}
          n2 = 0
          if h2.key?("name")
            n2 += 1
            v2 = h2["name"]
            if v2.nil?
              r2[:name] = nil
            else
              ActiveTypedParams::Runtime.fail(:invalid_type, ["delivery", "recipient_mailing_address", "name"], :string) unless v2.is_a?(String) && !v2.include?("\0")
              ActiveTypedParams::Runtime.fail(:too_long, ["delivery", "recipient_mailing_address", "name"]) if v2.length > 512
              r2[:name] = v2
            end
          end
          if h2.key?("street")
            n2 += 1
            v2 = h2["street"]
            if v2.nil?
              r2[:street] = nil
            else
              ActiveTypedParams::Runtime.fail(:invalid_type, ["delivery", "recipient_mailing_address", "street"], :string) unless v2.is_a?(String) && !v2.include?("\0")
              ActiveTypedParams::Runtime.fail(:too_long, ["delivery", "recipient_mailing_address", "street"]) if v2.length > 512
              r2[:street] = v2
            end
          end
          if h2.key?("city")
            n2 += 1
            v2 = h2["city"]
            if v2.nil?
              r2[:city] = nil
            else
              ActiveTypedParams::Runtime.fail(:invalid_type, ["delivery", "recipient_mailing_address", "city"], :string) unless v2.is_a?(String) && !v2.include?("\0")
              ActiveTypedParams::Runtime.fail(:too_long, ["delivery", "recipient_mailing_address", "city"]) if v2.length > 512
              r2[:city] = v2
            end
          end
          if h2.key?("state")
            n2 += 1
            v2 = h2["state"]
            if v2.nil?
              r2[:state] = nil
            else
              ActiveTypedParams::Runtime.fail(:invalid_type, ["delivery", "recipient_mailing_address", "state"], :string) unless v2.is_a?(String) && !v2.include?("\0")
              ActiveTypedParams::Runtime.fail(:too_long, ["delivery", "recipient_mailing_address", "state"]) if v2.length > 512
              r2[:state] = v2
            end
          end
          if h2.key?("zip")
            n2 += 1
            v2 = h2["zip"]
            if v2.nil?
              r2[:zip] = nil
            else
              ActiveTypedParams::Runtime.fail(:invalid_type, ["delivery", "recipient_mailing_address", "zip"], :string) unless v2.is_a?(String) && !v2.include?("\0")
              ActiveTypedParams::Runtime.fail(:too_long, ["delivery", "recipient_mailing_address", "zip"]) if v2.length > 512
              r2[:zip] = v2
            end
          end
          ActiveTypedParams::Runtime.check_unknown(h2, KEYS_1, :report, PATH_1, self, nil) if h2.size > n2
          r1[:recipient_mailing_address] = r2
        end
      end
      ActiveTypedParams::Runtime.check_unknown(h1, KEYS_2, :report, PATH_2, self, nil) if h1.size > n1
      r0[:delivery] = r1
    end
  end
  if h0.key?("greeting")
    n0 += 1
    v0 = h0["greeting"]
    if v0.nil?
      r0[:greeting] = nil
    else
      h1 = ActiveTypedParams::Runtime.unwrap_hash(v0) || ActiveTypedParams::Runtime.fail(:invalid_type, ["greeting"], :hash)
      r1 = {}
      n1 = 0
      if h1.key?("from")
        n1 += 1
        v1 = h1["from"]
        if v1.nil?
          r1[:from] = nil
        else
          ActiveTypedParams::Runtime.fail(:invalid_type, ["greeting", "from"], :string) unless v1.is_a?(String) && !v1.include?("\0")
          ActiveTypedParams::Runtime.fail(:too_long, ["greeting", "from"]) if v1.length > 512
          r1[:from] = v1
        end
      end
      if h1.key?("to")
        n1 += 1
        v1 = h1["to"]
        if v1.nil?
          r1[:to] = nil
        else
          ActiveTypedParams::Runtime.fail(:invalid_type, ["greeting", "to"], :string) unless v1.is_a?(String) && !v1.include?("\0")
          ActiveTypedParams::Runtime.fail(:too_long, ["greeting", "to"]) if v1.length > 512
          r1[:to] = v1
        end
      end
      if h1.key?("message")
        n1 += 1
        v1 = h1["message"]
        if v1.nil?
          r1[:message] = nil
        else
          ActiveTypedParams::Runtime.fail(:invalid_type, ["greeting", "message"], :string) unless v1.is_a?(String) && !v1.include?("\0")
          ActiveTypedParams::Runtime.fail(:too_long, ["greeting", "message"]) if v1.length > 2000
          r1[:message] = v1
        end
      end
      if h1.key?("category_id")
        n1 += 1
        v1 = h1["category_id"]
        if v1.nil? || v1 == ""
          r1[:category_id] = nil
        else
          v1 = ActiveTypedParams::Runtime.integer(v1) if v1.is_a?(String)
          ActiveTypedParams::Runtime.fail(:invalid_type, ["greeting", "category_id"], :id) unless v1.is_a?(Integer) && v1 > 0 && v1 < 2147483648
          r1[:category_id] = v1
        end
      end
      if h1.key?("card")
        n1 += 1
        v1 = h1["card"]
        if v1.nil?
          r1[:card] = nil
        else
          h2 = ActiveTypedParams::Runtime.unwrap_hash(v1) || ActiveTypedParams::Runtime.fail(:invalid_type, ["greeting", "card"], :hash)
          r2 = {}
          n2 = 0
          if h2.key?("id")
            n2 += 1
            v2 = h2["id"]
            if v2.nil? || v2 == ""
              ActiveTypedParams::Runtime.fail(:missing, ["greeting", "card", "id"], :id)
            else
              v2 = ActiveTypedParams::Runtime.integer(v2) if v2.is_a?(String)
              ActiveTypedParams::Runtime.fail(:invalid_type, ["greeting", "card", "id"], :id) unless v2.is_a?(Integer) && v2 > 0 && v2 < 2147483648
              r2[:id] = v2
            end
          else
            ActiveTypedParams::Runtime.fail(:missing, ["greeting", "card", "id"])
          end
          ActiveTypedParams::Runtime.check_unknown(h2, KEYS_3, :report, PATH_3, self, nil) if h2.size > n2
          r1[:card] = r2
        end
      end
      if h1.key?("greeting_card_customization")
        n1 += 1
        v1 = h1["greeting_card_customization"]
        if v1.nil?
          r1[:greeting_card_customization] = nil
        else
          h2 = ActiveTypedParams::Runtime.unwrap_hash(v1) || ActiveTypedParams::Runtime.fail(:invalid_type, ["greeting", "greeting_card_customization"], :hash)
          r2 = {}
          n2 = 0
          if h2.key?("sender")
            n2 += 1
            v2 = h2["sender"]
            if v2.nil?
              r2[:sender] = nil
            else
              ActiveTypedParams::Runtime.fail(:invalid_type, ["greeting", "greeting_card_customization", "sender"], :string) unless v2.is_a?(String) && !v2.include?("\0")
              ActiveTypedParams::Runtime.fail(:too_long, ["greeting", "greeting_card_customization", "sender"]) if v2.length > 512
              r2[:sender] = v2
            end
          end
          if h2.key?("recipient")
            n2 += 1
            v2 = h2["recipient"]
            if v2.nil?
              r2[:recipient] = nil
            else
              ActiveTypedParams::Runtime.fail(:invalid_type, ["greeting", "greeting_card_customization", "recipient"], :string) unless v2.is_a?(String) && !v2.include?("\0")
              ActiveTypedParams::Runtime.fail(:too_long, ["greeting", "greeting_card_customization", "recipient"]) if v2.length > 512
              r2[:recipient] = v2
            end
          end
          if h2.key?("title")
            n2 += 1
            v2 = h2["title"]
            if v2.nil?
              r2[:title] = nil
            else
              ActiveTypedParams::Runtime.fail(:invalid_type, ["greeting", "greeting_card_customization", "title"], :string) unless v2.is_a?(String) && !v2.include?("\0")
              ActiveTypedParams::Runtime.fail(:too_long, ["greeting", "greeting_card_customization", "title"]) if v2.length > 512
              r2[:title] = v2
            end
          end
          if h2.key?("note")
            n2 += 1
            v2 = h2["note"]
            if v2.nil?
              r2[:note] = nil
            else
              ActiveTypedParams::Runtime.fail(:invalid_type, ["greeting", "greeting_card_customization", "note"], :string) unless v2.is_a?(String) && !v2.include?("\0")
              ActiveTypedParams::Runtime.fail(:too_long, ["greeting", "greeting_card_customization", "note"]) if v2.length > 512
              r2[:note] = v2
            end
          end
          if h2.key?("story_slides")
            n2 += 1
            v2 = h2["story_slides"]
            if v2.nil?
              r2[:story_slides] = nil
            else
              ActiveTypedParams::Runtime.fail(:invalid_type, ["greeting", "greeting_card_customization", "story_slides"], :array) unless v2.is_a?(Array)
              ActiveTypedParams::Runtime.fail(:too_long, ["greeting", "greeting_card_customization", "story_slides"]) if v2.length > 1000
              a3 = Array.new(v2.length)
              v2.each_with_index do |e3, i3|
                if e3.nil?
                  ActiveTypedParams::Runtime.fail(:invalid_type, ["greeting", "greeting_card_customization", "story_slides", i3], :hash)
                else
                  h4 = ActiveTypedParams::Runtime.unwrap_hash(e3) || ActiveTypedParams::Runtime.fail(:invalid_type, ["greeting", "greeting_card_customization", "story_slides", i3], :hash)
                  r4 = {}
                  n4 = 0
                  if h4.key?("photo")
                    n4 += 1
                    v4 = h4["photo"]
                    if v4.nil?
                      r4[:photo] = nil
                    else
                      ActiveTypedParams::Runtime.fail(:invalid_type, ["greeting", "greeting_card_customization", "story_slides", i3, "photo"], :string) unless v4.is_a?(String) && !v4.include?("\0")
                      ActiveTypedParams::Runtime.fail(:too_long, ["greeting", "greeting_card_customization", "story_slides", i3, "photo"]) if v4.length > 512
                      r4[:photo] = v4
                    end
                  end
                  if h4.key?("video")
                    n4 += 1
                    v4 = h4["video"]
                    if v4.nil?
                      r4[:video] = nil
                    else
                      ActiveTypedParams::Runtime.fail(:invalid_type, ["greeting", "greeting_card_customization", "story_slides", i3, "video"], :string) unless v4.is_a?(String) && !v4.include?("\0")
                      ActiveTypedParams::Runtime.fail(:too_long, ["greeting", "greeting_card_customization", "story_slides", i3, "video"]) if v4.length > 512
                      r4[:video] = v4
                    end
                  end
                  if h4.key?("text")
                    n4 += 1
                    v4 = h4["text"]
                    if v4.nil?
                      r4[:text] = nil
                    else
                      ActiveTypedParams::Runtime.fail(:invalid_type, ["greeting", "greeting_card_customization", "story_slides", i3, "text"], :string) unless v4.is_a?(String) && !v4.include?("\0")
                      ActiveTypedParams::Runtime.fail(:too_long, ["greeting", "greeting_card_customization", "story_slides", i3, "text"]) if v4.length > 512
                      r4[:text] = v4
                    end
                  end
                  if h4.key?("frame")
                    n4 += 1
                    v4 = h4["frame"]
                    if v4.nil?
                      r4[:frame] = nil
                    else
                      ActiveTypedParams::Runtime.fail(:invalid_type, ["greeting", "greeting_card_customization", "story_slides", i3, "frame"], :string) unless v4.is_a?(String) && !v4.include?("\0")
                      ActiveTypedParams::Runtime.fail(:too_long, ["greeting", "greeting_card_customization", "story_slides", i3, "frame"]) if v4.length > 512
                      r4[:frame] = v4
                    end
                  end
                  if h4.key?("color_filter")
                    n4 += 1
                    v4 = h4["color_filter"]
                    if v4.nil?
                      r4[:color_filter] = nil
                    else
                      ActiveTypedParams::Runtime.fail(:invalid_type, ["greeting", "greeting_card_customization", "story_slides", i3, "color_filter"], :string) unless v4.is_a?(String) && !v4.include?("\0")
                      ActiveTypedParams::Runtime.fail(:too_long, ["greeting", "greeting_card_customization", "story_slides", i3, "color_filter"]) if v4.length > 512
                      r4[:color_filter] = v4
                    end
                  end
                  if h4.key?("stickers")
                    n4 += 1
                    v4 = h4["stickers"]
                    if v4.nil?
                      r4[:stickers] = nil
                    else
                      ActiveTypedParams::Runtime.fail(:invalid_type, ["greeting", "greeting_card_customization", "story_slides", i3, "stickers"], :array) unless v4.is_a?(Array)
                      ActiveTypedParams::Runtime.fail(:too_long, ["greeting", "greeting_card_customization", "story_slides", i3, "stickers"]) if v4.length > 1000
                      a5 = Array.new(v4.length)
                      v4.each_with_index do |e5, i5|
                        if e5.nil?
                          ActiveTypedParams::Runtime.fail(:invalid_type, ["greeting", "greeting_card_customization", "story_slides", i3, "stickers", i5], :hash)
                        else
                          h6 = ActiveTypedParams::Runtime.unwrap_hash(e5) || ActiveTypedParams::Runtime.fail(:invalid_type, ["greeting", "greeting_card_customization", "story_slides", i3, "stickers", i5], :hash)
                          r6 = {}
                          n6 = 0
                          if h6.key?("key")
                            n6 += 1
                            v6 = h6["key"]
                            if v6.nil?
                              ActiveTypedParams::Runtime.fail(:missing, ["greeting", "greeting_card_customization", "story_slides", i3, "stickers", i5, "key"], :string)
                            else
                              ActiveTypedParams::Runtime.fail(:invalid_type, ["greeting", "greeting_card_customization", "story_slides", i3, "stickers", i5, "key"], :string) unless v6.is_a?(String) && !v6.include?("\0")
                              ActiveTypedParams::Runtime.fail(:blank, ["greeting", "greeting_card_customization", "story_slides", i3, "stickers", i5, "key"]) if v6.empty?
                              ActiveTypedParams::Runtime.fail(:too_long, ["greeting", "greeting_card_customization", "story_slides", i3, "stickers", i5, "key"]) if v6.length > 512
                              r6[:key] = v6
                            end
                          else
                            ActiveTypedParams::Runtime.fail(:missing, ["greeting", "greeting_card_customization", "story_slides", i3, "stickers", i5, "key"])
                          end
                          if h6.key?("x")
                            n6 += 1
                            v6 = h6["x"]
                            if v6.nil? || v6 == ""
                              ActiveTypedParams::Runtime.fail(:missing, ["greeting", "greeting_card_customization", "story_slides", i3, "stickers", i5, "x"], :float)
                            else
                              v6 = ActiveTypedParams::Runtime.float(v6)
                              ActiveTypedParams::Runtime.fail(:invalid_type, ["greeting", "greeting_card_customization", "story_slides", i3, "stickers", i5, "x"], :float) if v6.nil?
                              r6[:x] = v6
                            end
                          else
                            ActiveTypedParams::Runtime.fail(:missing, ["greeting", "greeting_card_customization", "story_slides", i3, "stickers", i5, "x"])
                          end
                          if h6.key?("y")
                            n6 += 1
                            v6 = h6["y"]
                            if v6.nil? || v6 == ""
                              ActiveTypedParams::Runtime.fail(:missing, ["greeting", "greeting_card_customization", "story_slides", i3, "stickers", i5, "y"], :float)
                            else
                              v6 = ActiveTypedParams::Runtime.float(v6)
                              ActiveTypedParams::Runtime.fail(:invalid_type, ["greeting", "greeting_card_customization", "story_slides", i3, "stickers", i5, "y"], :float) if v6.nil?
                              r6[:y] = v6
                            end
                          else
                            ActiveTypedParams::Runtime.fail(:missing, ["greeting", "greeting_card_customization", "story_slides", i3, "stickers", i5, "y"])
                          end
                          if h6.key?("rotation")
                            n6 += 1
                            v6 = h6["rotation"]
                            if v6.nil? || v6 == ""
                              ActiveTypedParams::Runtime.fail(:missing, ["greeting", "greeting_card_customization", "story_slides", i3, "stickers", i5, "rotation"], :float)
                            else
                              v6 = ActiveTypedParams::Runtime.float(v6)
                              ActiveTypedParams::Runtime.fail(:invalid_type, ["greeting", "greeting_card_customization", "story_slides", i3, "stickers", i5, "rotation"], :float) if v6.nil?
                              r6[:rotation] = v6
                            end
                          else
                            ActiveTypedParams::Runtime.fail(:missing, ["greeting", "greeting_card_customization", "story_slides", i3, "stickers", i5, "rotation"])
                          end
                          if h6.key?("scale")
                            n6 += 1
                            v6 = h6["scale"]
                            if v6.nil? || v6 == ""
                              ActiveTypedParams::Runtime.fail(:missing, ["greeting", "greeting_card_customization", "story_slides", i3, "stickers", i5, "scale"], :float)
                            else
                              v6 = ActiveTypedParams::Runtime.float(v6)
                              ActiveTypedParams::Runtime.fail(:invalid_type, ["greeting", "greeting_card_customization", "story_slides", i3, "stickers", i5, "scale"], :float) if v6.nil?
                              r6[:scale] = v6
                            end
                          else
                            ActiveTypedParams::Runtime.fail(:missing, ["greeting", "greeting_card_customization", "story_slides", i3, "stickers", i5, "scale"])
                          end
                          ActiveTypedParams::Runtime.check_unknown(h6, KEYS_4, :report, ["greeting", "greeting_card_customization", "story_slides", i3, "stickers", i5], self, nil) if h6.size > n6
                          a5[i5] = r6
                        end
                      end
                      r4[:stickers] = a5
                    end
                  end
                  ActiveTypedParams::Runtime.check_unknown(h4, KEYS_5, :report, ["greeting", "greeting_card_customization", "story_slides", i3], self, nil) if h4.size > n4
                  a3[i3] = r4
                end
              end
              r2[:story_slides] = a3
            end
          end
          ActiveTypedParams::Runtime.check_unknown(h2, KEYS_6, :report, PATH_4, self, nil) if h2.size > n2
          r1[:greeting_card_customization] = r2
        end
      end
      ActiveTypedParams::Runtime.check_unknown(h1, KEYS_7, :report, PATH_5, self, nil) if h1.size > n1
      r0[:greeting] = r1
    end
  end
  ActiveTypedParams::Runtime.check_unknown(h0, KEYS_8, :report, PATH_6, self, request) if h0.size > n0
  r0
rescue ActiveTypedParams::InvalidParameter => error
  ActiveTypedParams::Runtime.report_invalid(error, self)
  raise
end
