# frozen_string_literal: true

require "openssl"

module Missive
  class Signature
    def self.generate(payload, secret)
      OpenSSL::HMAC.hexdigest("SHA256", secret, payload)
    end

    def self.valid?(payload, header, secret)
      expected = generate(payload, secret)
      secure_compare(expected, header)
    end

    private_class_method def self.secure_compare(a, b)
      return false unless a.bytesize == b.bytesize

      l = a.unpack("C*")
      res = 0
      b.each_byte { |byte| res |= byte ^ l.shift }
      res.zero?
    end
  end
end
