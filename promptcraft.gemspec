Gem::Specification.new do |spec|
  spec.name          = "promptcraft"
  spec.version       = "0.1.0"
  spec.authors       = ["PromptCraft Contributors"]
  spec.email         = ["hello@example.com"]
  spec.summary       = "A fluent Ruby DSL for orchestrating AI agents"
  spec.description   = "Chain prompts, autonomous agents and workflows with Ruby blocks."
  spec.homepage      = "https://github.com/example/promptcraft"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.1.0"
  spec.files = Dir["lib/**/*", "bin/*", "README.md", "LICENSE", "CHANGELOG.md", "examples/**/*"]
  spec.bindir        = "bin"
  spec.executables   = ["promptcraft"]
  spec.require_paths = ["lib"]
end
