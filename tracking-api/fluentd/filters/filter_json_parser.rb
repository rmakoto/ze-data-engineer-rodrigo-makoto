# frozen_string_literal: true

require 'fluent/filter'

module Fluent
  class JsonParserFilter < Filter
    Plugin.register_filter('json_parser', self)

    config_param :key_name, :string, default: 'body'

    def filter(_tag, _time, record)
      record[@key_name] = record[@key_name].empty? ? {} : JSON.parse(record[@key_name])

      record
     rescue JSON::ParserError, SyntaxError => error
      log.error "#{error.message} on #{record[@key_name]}"

      record[@key_name] = {}
      record
     end
   end
end
