module Import
  module Helper
    # rubocop:disable Style/ModuleFunction
    extend self

    def check_import_mode
      # check if system is in import mode
      return true if Setting.get('import_mode')
      raise 'System is not in import mode!'
    end

    # log
    def log(message)
      thread_no = Thread.current[:thread_no] || '-'
      Rails.logger.info "thread##{thread_no}: #{message}"
    end

    # utf8 convert
    def utf8_encode(data)
      data.each { |key, value|
        next if !value
        next if value.class != String
        data[key] = Encode.conv('utf8', value)
      }
    end

    def reset_primary_key_sequence(table)
      DbHelper.import_post(table)
    end
  end
end
