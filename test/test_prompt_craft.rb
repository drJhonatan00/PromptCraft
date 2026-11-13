# frozen_string_literal: true
require "minitest/autorun"
require_relative "../lib/prompt_craft"

class PromptCraftTest < Minitest::Test
  def setup
    @mock = PromptCraft::Provider::Mock.new { |messages:, **| "ok: #{messages.last[:content]}" }
  end

  def test_context_renders_input_and_records_history
    context = PromptCraft::Context.new(topic: "Ruby")
    context.record(:answer, "sim")
    assert_equal "Ruby", context[:topic]
    assert_equal "sim", context[:answer]
    assert_equal 1, context.history.length
  end

  def test_workflow_chains_steps
    workflow = PromptCraft::Workflow.new(:demo) do
      step :first, "Olá {{topic}}"
      step :second, "Use o resultado: {{first}}"
    end
    result = workflow.run({ topic: "Ruby" }, provider: @mock)
    assert_equal 2, result.history.length
    assert_includes result[:second], "ok:"
  end

  def test_agent_stops_when_done
    calls = 0
    provider = PromptCraft::Provider::Mock.new do |**|
      calls += 1
      calls == 1 ? "primeira" : "final [DONE]"
    end
    workflow = PromptCraft::Workflow.new(:agent) do
      agent :worker, role: "tester", goal: "terminar", max_iterations: 3
    end
    result = workflow.run({}, provider: provider)
    assert_equal 2, calls
    assert_equal 2, result.history.length
  end
end
