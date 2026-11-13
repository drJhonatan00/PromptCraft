# PromptCraft

PromptCraft is a small, dependency-light Ruby library and command-line interface for orchestrating AI agents with a fluent, block-based DSL. It lets you compose prompts, preserve execution context, run bounded autonomous agents and connect to OpenAI-compatible chat-completion endpoints without hiding the control flow behind a large framework.

The project is deliberately transparent: a workflow is ordinary Ruby, each step is inspectable, and every execution produces a structured `Context` containing input, named results and history.

> **Responsible reasoning boundary:** PromptCraft records outputs, metadata and completion markers. It does not attempt to expose or reconstruct a model's private chain of thought. For auditability, prefer concise intermediate artefacts, explicit acceptance criteria and application-level logs.

## What you get

PromptCraft provides a fluent workflow DSL, named steps with `{{placeholder}}` interpolation, bounded agents with a configurable role and goal, an OpenAI-compatible provider, a deterministic Mock provider for local development, a structured execution history, and a small CLI for initialising, validating and running workflow files.

It has no runtime dependency outside Ruby's standard library. `minitest` is included as a development/test dependency, so the example and test suite can run without an API key or network access.

## Requirements

- Ruby 3.1 or newer.
- Bundler, when you want to use the repository's `Gemfile`.
- An API key for a live OpenAI-compatible provider. The local Mock provider requires neither an account nor an internet connection.

## Installation on Windows

Install Ruby with DevKit using [RubyInstaller for Windows](https://rubyinstaller.org/downloads/). Choose Ruby 3.1 or newer and allow the installer to run `ridk install` when prompted. Open a new PowerShell window afterwards and check that Ruby is available:

```powershell
ruby --version
gem --version
```

Extract the downloaded archive, change to the project directory and install Bundler and the development dependency:

```powershell
cd C:\path\to\promptcraft
gem install bundler
bundle install
```

The commands in this README use PowerShell path syntax. From Command Prompt, use `ruby -Ilib bin\promptcraft ...` in the same way, or use `bundle exec ruby bin\promptcraft ...` when running through Bundler.

## Quick start without an API key

The bundled example uses the Mock provider, so it is safe to run locally and does not spend tokens:

```powershell
ruby examples\demo.rb
```

The output is JSON containing the original input, named step results and execution history. To run the test suite:

```powershell
ruby -Ilib -e "Dir['test/**/*_test.rb'].each { |file| require_relative file }"
```

A successful run reports three tests, eight assertions and no failures.

## Using the CLI

Create a starter workflow file:

```powershell
ruby -Ilib bin\promptcraft init my_workflow.rb
```

Validate a workflow file without running its model calls:

```powershell
ruby -Ilib bin\promptcraft validate my_workflow.rb
```

Run the first workflow declared in a file, passing input values as `key=value` arguments:

```powershell
ruby -Ilib bin\promptcraft run my_workflow.rb topic=Ruby
```

If a file contains more than one workflow, provide its name after the file path:

```powershell
ruby -Ilib bin\promptcraft run my_workflow.rb article topic=Ruby
```

The same commands can be run through Bundler:

```powershell
bundle exec ruby bin\promptcraft validate my_workflow.rb
bundle exec ruby bin\promptcraft run my_workflow.rb article topic=Ruby
```

The CLI writes the final `Context` as pretty-printed JSON to standard output. Errors are written to standard error and return a non-zero exit status, which makes the CLI suitable for scripts and CI jobs.

## The DSL

A workflow is declared with `PromptCraft.workflow`. Steps execute in declaration order and return the value produced by the provider. A later step can refer to an earlier result by name:

```ruby
require "prompt_craft"

PromptCraft.provider :openai

PromptCraft.workflow :article do
  step :outline, "Create a short outline about {{topic}}."

  step :draft, "Write a first draft using this outline: {{outline}}."

  agent :critic,
    role: "editorial critic",
    goal: "Find weaknesses in the draft and suggest specific improvements",
    max_iterations: 3
end

context = PromptCraft.workflows[:article].run(topic: "Ruby DSL design")
puts context[:critic]
```

`{{topic}}` resolves from workflow input. `{{outline}}` resolves from a result already recorded in the context. Every step also remains available in `context.history`, together with its name, result, type, iteration metadata and UTC timestamp.

### Custom step logic

A step can receive the current context directly instead of using a prompt template. This is useful for deterministic preparation, validation or post-processing:

```ruby
PromptCraft.workflow :prepared do
  step :normalise do |context|
    context[:topic].to_s.strip.downcase
  end

  step :answer, "Explain the normalised topic: {{normalise}}."
end
```

### Bounded autonomous agents

An agent repeats its task until the provider returns a response containing `[DONE]`, or until `max_iterations` is reached. The limit is intentional: it prevents an accidental prompt from creating an unbounded loop.

```ruby
agent :reviewer,
  role: "senior Ruby reviewer",
  goal: "Check the proposed API for clarity, safety and backwards compatibility",
  max_iterations: 2
```

For complete control, pass a block. The block receives the context, the zero-based iteration number and the previous result:

```ruby
agent :planner,
  role: "planner",
  goal: "produce an actionable plan",
  max_iterations: 3 do |context, iteration, previous|
    "Iteration #{iteration}: improve this plan. Previous result: #{previous}. Context: #{context.to_h}"
  end
```

The block constructs each task; the provider still performs the actual model call. Keep the iteration limit small and define an explicit completion condition in the prompt.

### Context and results

`Context` exposes `input`, `data` and `history`. Bracket access reads named results first and then workflow input:

```ruby
context[:topic]       # input value
context[:outline]     # result recorded by the outline step
context.history       # array of structured execution records
context.to_h          # serialisable hash
```

## Providers

The OpenAI-compatible provider reads `OPENAI_API_KEY` by default:

```powershell
$env:OPENAI_API_KEY = "your-api-key"
```

To persist it for your Windows user account rather than only the current PowerShell session:

```powershell
[Environment]::SetEnvironmentVariable("OPENAI_API_KEY", "your-api-key", "User")
```

Never commit an API key, place one in a Ruby source file, or distribute an archive containing a secret. Restart PowerShell after setting a persistent variable if the current process cannot see it.

You can also provide a compatible base URL and model from Ruby:

```ruby
PromptCraft.configure do |config|
  config.default_model = "gpt-4o-mini"
  config.temperature = 0.2
  config.timeout = 120
end

PromptCraft.provider :openai,
  base_url: "https://api.openai.com/v1"
```

Any object implementing `chat(messages:, model:, temperature:, **options)` can be passed directly to `workflow.run(provider: custom_provider)`. It must return an object responding to `text`; `PromptCraft::Provider::Response` is a convenient value object for custom providers.

For tests, use the Mock provider:

```ruby
mock = PromptCraft::Provider::Mock.new do |messages:, **|
  "Test response for: #{messages.last[:content]} [DONE]"
end

context = PromptCraft.workflows[:article].run({ topic: "Ruby" }, provider: mock)
```

## API overview

| API | Purpose |
| --- | --- |
| `PromptCraft.workflow(name) { ... }` | Declare and register a workflow. |
| `step(name, prompt, **options)` | Add a provider-backed or block-backed step. |
| `agent(name, role:, goal:, max_iterations:)` | Add a bounded iterative agent. |
| `workflow.run(input, provider:)` | Execute the workflow and return a `Context`. |
| `PromptCraft.provider(:openai)` | Register the OpenAI-compatible provider. |
| `PromptCraft.provider(:mock)` | Register a deterministic local provider. |
| `promptcraft init` | Generate a starter workflow file. |
| `promptcraft validate` | Load a workflow and list its names. |
| `promptcraft run` | Execute a workflow and print JSON. |

## Project layout

```text
promptcraft/
├── bin/promptcraft                 # command-line entry point
├── examples/demo.rb                # offline example using Mock
├── lib/prompt_craft.rb             # public entry point
├── lib/prompt_craft/               # DSL, context, providers and execution
├── test/test_prompt_craft.rb       # unit tests
├── promptcraft.gemspec             # gem metadata
├── Gemfile                          # development dependency
└── README.md                        # this guide
```

## Troubleshooting

**`ruby` is not recognised.** Close and reopen PowerShell after installing RubyInstaller. If the problem persists, add the RubyInstaller `bin` directory to your user `PATH`, then run `ruby --version` again.

**`cannot load such file -- prompt_craft`.** Run commands from the project root and include `-Ilib`, or use `bundle exec ruby bin\promptcraft ...`.

**`Set OPENAI_API_KEY or api_key`.** The OpenAI provider was selected but no key was found. Set `$env:OPENAI_API_KEY` in the current PowerShell session, or pass `api_key:` when registering the provider.

**`Workflow not found`.** Check the symbol passed to the CLI against the name in `PromptCraft.workflow :name do ... end`. `validate` prints all workflows discovered in a file.

**The example makes a network request.** The bundled `examples/demo.rb` uses `:mock`. A workflow only makes a model call when it explicitly registers or receives a live provider.

## Development

Run the tests from the repository root:

```powershell
ruby -Ilib -e "Dir['test/**/*_test.rb'].each { |file| require_relative file }"
```

The project intentionally keeps its runtime surface small. When adding a provider, preserve the provider contract, add tests using the Mock provider, keep network calls out of unit tests, and document any provider-specific options.

## Licence

PromptCraft is released under the MIT Licence. See [LICENSE](LICENSE) for the complete text.

<!-- Watashi wa Watashi sore dake-->
