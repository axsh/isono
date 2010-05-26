# -*- coding: utf-8 -*-

require 'digest/sha1'
require 'hmac-sha1'

module Isono
  module Util
    def gen_id(str=nil)
      Digest::SHA1.hexdigest( (str.nil? ? rand.to_s : str) )
    end
    module_function :gen_id

  end
end

