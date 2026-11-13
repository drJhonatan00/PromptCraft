# frozen_string_literal: true

require "net/http"
require "uri"
require "json"

module PromptCraft
  module Provider
    Response = Struct.new(:text, :raw, keyword_init: true)

    class Base
      def chat(messages:, model:, temperature:, **_options)
        raise NotImplementedError
      end
    end

    class OpenAI < Base
      def initialize(api_key:, base_url: "https://api.openai.com/v1", timeout: 120)
        raise ConfigurationError, "Set OPENAI_API_KEY or api_key" if api_key.to_s.empty?
        @api_key, @base_url, @timeout = api_key, base_url.sub(%r{/$}, ""), timeout
      end

      def chat(messages:, model:, temperature:, **options)
        uri = URI.parse("#{@base_url}/chat/completions")
        request = Net::HTTP::Post.new(uri)
        request["Authorization"] = "Bearer #{@api_key}"
        request["Content-Type"] = "application/json"
        request.body = JSON.generate({ model: model, messages: messages, temperature: temperature }.merge(options))
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == "https"
        http.open_timeout = @timeout
        http.read_timeout = @timeout
        response = http.request(request)
        body = JSON.parse(response.body)
        raise ProviderError, body.dig("error", "message") || "HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)
        Response.new(text: body.dig("choices", 0, "message", "content").to_s, raw: body)
      rescue JSON::ParserError => e
        raise ProviderError, "Invalid JSON response: #{e.message}"
      rescue StandardError => e
        raise e if e.is_a?(PromptCraft::Error)
        raise ProviderError, "Provider failure: #{e.message}"
      end
    end

    class Mock < Base
      attr_reader :calls

      def initialize(&block)
        @block = block || ->(messages:, **) { "Mock: #{messages.last[:content]}" }
        @calls = []
      end

      def chat(**kwargs)
        @calls << kwargs
        Response.new(text: @block.call(**kwargs), raw: { mock: true })
      end
    end

    module_function

    def build(name, **options, &block)
      case name.to_sym
      when :openai then OpenAI.new(api_key: options.delete(:api_key) || ENV["OPENAI_API_KEY"], **options)
      when :mock then Mock.new(&block)
      else raise ConfigurationError, "Unknown provider: #{name}"
      end
    end
  end
end
