# frozen_string_literal: true
module PromptCraft
  module DSL
    def workflow(name, **options, &block)
      workflow = Workflow.new(name, **options, &block)
      workflows[name.to_sym] = workflow
    end

    def workflows
      @workflows ||= {}
    end
  end

  extend DSL
end
