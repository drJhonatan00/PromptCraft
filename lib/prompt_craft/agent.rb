# frozen_string_literal: true
module PromptCraft
  class Agent
    attr_reader :name, :role, :goal, :max_iterations

    def initialize(name, role:, goal:, max_iterations: 3, **options, &block)
      @name, @role, @goal = name.to_sym, role, goal
      @max_iterations, @options, @instructions = max_iterations, options, block
    end

    def call(context, runner)
      result = nil
      @max_iterations.times do |iteration|
        task = @instructions ? @instructions.call(context, iteration, result) : default_task(context, result)
        result = runner.ask(task, **@options)
        context.record(@name, result, type: :agent, iteration: iteration + 1)
        break if done?(result)
      end
      result
    end

    private

    def default_task(context, previous)
      <<~PROMPT
        You are #{@role}.
        Goal: #{@goal}
        Context: #{context.to_h.to_json}
        Previous result: #{previous || "none"}
        Produce a useful response and finish with [DONE] when the goal has been met.
      PROMPT
    end

    def done?(result)
      result.to_s.include?("[DONE]")
    end
  end
end
