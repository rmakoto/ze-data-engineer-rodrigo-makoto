# frozen_string_literal: true

require 'fluent/filter'

module Fluent
  class SchemaParserFilter < Filter
    Plugin.register_filter('schema_parser', self)

    def filter(_tag, time, record)
      record = schema_v1(get_time_millis(time), record)

    rescue StandardError => error
      log.error error.message.to_s

      record
    end

    def schema_v1(time, record)
      record['event_name'] = record.dig('body', 'event_name')
      record['type'] = record.dig('body', 'type')
      record['collector_timestamp'] = time
      record['device_sent_timestamp'] = record.dig('body', 'device_sent_timestamp')
      record['attributes'] = record.dig('body', 'attributes')
    
      record
    end

    def get_time_millis(time)
      # Remove last six digits since this has nano precision
      (time.sec.to_s + time.nsec.to_s[0...-6].rjust(3, '0')).to_i
    end
  end
end
