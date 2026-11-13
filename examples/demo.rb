# frozen_string_literal: true
$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require_relative "../lib/prompt_craft"

PromptCraft.provider :mock do |messages:, **|
  "Local response for: #{messages.last[:content]} [DONE]"
end

PromptCraft.workflow :research do
  step :question, "Define {{topic}} in one clear sentence."
  agent :editor, role: "editor", goal: "Review the definition and make it concise", max_iterations: 2
end

if $PROGRAM_NAME == __FILE__
  result = PromptCraft.workflows[:research].run(topic: "fluent DSL")
  puts JSON.pretty_generate(result.to_h)
end
