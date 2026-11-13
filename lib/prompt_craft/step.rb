# frozen_string_literal: true
module PromptCraft
  class Step
    attr_reader :name, :prompt_template, :options

    def initialize(name, prompt_template = nil, **options, &block)
      @name, @prompt_template, @options, @block = name.to_sym, prompt_template, options, block
    end

    def call(context, runner)
      result = if @block
                 @block.arity == 1 ? @block.call(context) : @block.call(context, runner)
               else
                 runner.ask(render(@prompt_template, context), **@options)
               end
      context.record(@name, result, type: :step)
    end

    private

    def render(template, context)
      template.to_s.gsub(/\{\{\s*([\w.]+)\s*\}\}/) do
        key = Regexp.last_match(1).split(".")
        key.shift if key.first == "context"
        key.reduce(context) { |object, part| object.respond_to?(:[]) ? object[part.to_sym] : nil }.to_s
      end
    end
  end
end
