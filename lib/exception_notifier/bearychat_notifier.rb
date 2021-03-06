# coding: utf-8
module ExceptionNotifier
  class BearychatNotifier
    #include ExceptionNotifier::BacktraceCleaner # 不在 exception_notification 手动添加代码过来

    attr_accessor :notifier

    def initialize(options)
      begin
        @ignore_data_if = options[:ignore_data_if]

        webhook_url = options.fetch(:webhook_url)
        options.delete(:webhook_url)
        @payload_options = options
        @payload_options[:attachments] = options.fetch(:attachments, [])
        @notifier = Bearychat::Notifier.new webhook_url, options
      rescue
        @notifier = nil
      end
    end

    def call(exception, options={})
      text = "An exception occurred: '#{exception.message}' on '#{exception.backtrace.first}'"

      text = enrich_message_with_data(text, options)

      attachment_options = {}
      attachment_options[:text] = enrich_message_with_backtrace(text, exception)
      @payload_options[:attachments].push(attachment_options)

      @notifier.ping(text, @payload_options) if valid?
    end

    protected

    def valid?
      !@notifier.nil?
    end

    def enrich_message_with_data(message, options)
      def deep_reject(hash, block)
        hash.each do |k, v|
          if v.is_a?(Hash)
            deep_reject(v, block)
          end

          if block.call(k, v)
            hash.delete(k)
          end
        end
      end

      data = ((options[:env] || {})['exception_notifier.exception_data'] || {}).merge(options[:data] || {})
      deep_reject(data, @ignore_data_if) if @ignore_data_if.is_a?(Proc)
      text = data.map{|k,v| "#{k}: #{v}"}.join(', ')

      if text.present?
        text = ['*Data:*', text].join("\n")
        [message, text].join("\n")
      else
        message
      end
    end

    def enrich_message_with_backtrace(message, exception)
      backtrace = clean_backtrace(exception).first(10).join("\n")
      [message, ['*Backtrace:*', backtrace]].join("\n")
    end

    def clean_backtrace(exception)
      if defined?(Rails) && Rails.respond_to?(:backtrace_cleaner)
        Rails.backtrace_cleaner.send(:filter, exception.backtrace)
      else
        exception.backtrace
      end
    end

  end

end
