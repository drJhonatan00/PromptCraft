# frozen_string_literal: true
module PromptCraft
  class Error < StandardError; end
  class ConfigurationError < Error; end
  class ProviderError < Error; end
  class WorkflowError < Error; end
  class MaxIterationsError < Error; end
end
