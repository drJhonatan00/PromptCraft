# frozen_string_literal: true

require "json"
require "logger"
require "prompt_craft/version"
require "prompt_craft/errors"
require "prompt_craft/context"
require "prompt_craft/provider"
require "prompt_craft/step"
require "prompt_craft/agent"
require "prompt_craft/workflow"
require "prompt_craft/dsl"
require "prompt_craft/cli"

module PromptCraft
  class << self
    attr_reader :configuration

    def configure
      @configuration ||= Configuration.new
      yield @configuration if block_given?
      @configuration
    end

    def config
      @configuration ||= Configuration.new
    end

    def provider(name = nil, **options, &block)
      if name
        instance = Provider.build(name, **options, &block)
        config.providers[name.to_sym] = instance
        config.providers[:default] = instance if config.providers[:default].nil?
      else
        config.providers[:default] || config.providers.values.first || raise(ConfigurationError, "Nenhum provider configurado")
      end
    end
  end

  class Configuration
    attr_accessor :default_model, :temperature, :timeout, :logger
    attr_reader :providers

    def initialize
      @providers = {}
      @default_model = ENV.fetch("PROMPTCRAFT_MODEL", "gpt-4o-mini")
      @temperature = 0.2
      @timeout = 120
      @logger = Logger.new($stderr)
      @logger.level = Logger::WARN
    end
  end
end
