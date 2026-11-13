# frozen_string_literal: true

require "time"

module PromptCraft
  class Context
    attr_reader :input, :data, :history

    def initialize(input = {}, data: {}, history: [], **kwargs)
      input = input.merge(kwargs) unless kwargs.empty?
      @input = input.is_a?(Hash) ? input.transform_keys(&:to_sym) : { value: input }
      @data = data
      @history = history
    end

    def [](key)
      key = key.to_sym
      return @data[key] if @data.key?(key)
      @input[key]
    end

    def []=(key, value)
      @data[key.to_sym] = value
    end

    def fetch(key, *args, &block)
      @data.fetch(key.to_sym, *args, &block)
    end

    def record(name, result, metadata = {})
      @history << { step: name.to_sym, result: result, metadata: metadata, at: Time.now.utc.iso8601 }
      self[name] = result
      result
    end

    def to_h
      { input: @input, data: @data, history: @history }
    end
  end
end
