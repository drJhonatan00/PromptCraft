# frozen_string_literal: true
module PromptCraft
  class Workflow
    attr_reader :name, :steps

    def initialize(name, **options, &block)
      @name, @options, @steps = name.to_sym, options, []
      instance_eval(&block) if block
    end

    def input(*); self; end

    def step(name, prompt = nil, **options, &block)
      @steps << Step.new(name, prompt, **options, &block)
      self
    end

    def agent(name, role:, goal:, **options, &block)
      @steps << Agent.new(name, role: role, goal: goal, **options, &block)
      self
    end

    def ask(prompt, **options)
      @steps << Step.new(:"ask_#{@steps.length + 1}", prompt, **options)
      self
    end

    def parallel(*names, &block)
      group = Workflow.new(:parallel_group, &block)
      @steps << ParallelStep.new(names, group.steps)
      self
    end

    def run(input = {}, provider: nil, model: nil, temperature: nil, **kwargs)
      input = input.merge(kwargs) unless kwargs.empty?
      runner = Runner.new(provider || PromptCraft.provider, model || PromptCraft.config.default_model,
                          temperature || PromptCraft.config.temperature)
      context = Context.new(input)
      @steps.each { |step| step.call(context, runner) }
      context
    rescue PromptCraft::Error
      raise
    rescue StandardError => e
      raise WorkflowError, "Workflow #{@name} failed: #{e.message}"
    end

    class ParallelStep
      def initialize(names, steps); @names, @steps = names, steps; end
      def call(context, runner)
        results = @steps.map { |step| [step.name, step.call(context, runner)] }.to_h
        context.record(:parallel, results, type: :parallel)
      end
    end

    class Runner
      def initialize(provider, model, temperature)
        @provider, @model, @temperature = provider, model, temperature
      end
      def ask(prompt, system: nil, **options)
        messages = []
        messages << { role: "system", content: system } if system
        messages << { role: "user", content: prompt.to_s }
        @provider.chat(messages: messages, model: @model, temperature: @temperature, **options).text
      end
    end
  end
end
