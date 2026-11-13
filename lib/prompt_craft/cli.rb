# frozen_string_literal: true

module PromptCraft
  class CLI
    def self.start(argv)
      command = argv.shift || "help"
      case command
      when "init" then init(argv.shift || "promptcraft_workflow.rb")
      when "run" then run(argv)
      when "validate" then validate(argv.shift || "workflow.rb")
      else puts usage
      end
    rescue Error => e
      warn "PromptCraft: #{e.message}"
      exit 1
    end

    def self.run(argv)
      file = argv.shift || "workflow.rb"
      name = argv.shift
      input = parse_input(argv)
      load File.expand_path(file)
      workflows = PromptCraft.workflows
      workflow = name ? workflows[name.to_sym] : workflows.values.first
      raise WorkflowError, "Workflow not found" unless workflow
      context = workflow.run(input)
      puts JSON.pretty_generate(context.to_h)
    end

    def self.validate(file)
      load File.expand_path(file)
      puts "OK: #{PromptCraft.workflows.keys.join(", ")}"
    end

    def self.init(file)
      content = <<~RUBY
        require "prompt_craft"
        PromptCraft.provider :openai

        PromptCraft.workflow :example do
          step :greeting, "Explain Ruby in one sentence for {{topic}}."
          agent :reviewer, role: "technical reviewer", goal: "Improve the answer", max_iterations: 2
        end
      RUBY
      File.write(file, content)
      puts "Created #{file}"
    end

    def self.parse_input(args)
      args.each_with_object({}) do |arg, hash|
        key, value = arg.split("=", 2)
        hash[key] = value || true
      end
    end

    def self.usage
      <<~TEXT
        Usage:
          promptcraft init [file]
          promptcraft validate <file>
          promptcraft run <file> [workflow] [key=value ...]
      TEXT
    end
  end
end
