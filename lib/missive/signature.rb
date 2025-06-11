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

    private_class_method def self.secure_compare(signature_a, signature_b)
      return false unless signature_a.bytesize == signature_b.bytesize

      l = signature_a.unpack("C*")
      res = 0
      signature_b.each_byte { |byte| res |= byte ^ l.shift }
      res.zero?
    end
  end
end
