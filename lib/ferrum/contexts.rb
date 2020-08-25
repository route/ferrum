# frozen_string_literal: true

require_relative "context"

module Ferrum
  class Contexts
    attr_reader :contexts

    def initialize(browser)
      @contexts = Concurrent::Hash.new
      @browser = browser
      subscribe
      discover
    end

    def default_context
      @default_context ||= create
    end

    def find_by(target_id:)
      @contexts.find { |_, c| c.targets.keys.include?(target_id) }&.last
    end

    def create
      response = @browser.command("Target.createBrowserContext")
      context_id = response["browserContextId"]
      context = Context.new(@browser, self, context_id)
      @contexts[context_id] = context
      context
    end

    def dispose(context_id)
      context = @contexts[context_id]
      @browser.command("Target.disposeBrowserContext", browserContextId: context.id)
      @contexts.delete(context_id)
      true
    end

    def reset
      @default_context = nil
      @contexts.each_key { |id| dispose(id) }
    end

    private

    def subscribe
      @browser.client.on("Target.targetCreated") do |params|
        info = params["targetInfo"]
        next unless info["type"] == "page"

        context_id = info["browserContextId"]
        @contexts[context_id]&.add_target(info)
      end

      @browser.client.on("Target.targetInfoChanged") do |params|
        info = params["targetInfo"]
        next unless info["type"] == "page"

        context_id, target_id = info.values_at("browserContextId", "targetId")
        @contexts[context_id]&.update_target(target_id, info)
      end

      @browser.client.on("Target.targetDestroyed") do |params|
        if (context = find_by(target_id: params["targetId"]))
          context.delete_target(params["targetId"])
        end
      end

      @browser.client.on("Target.targetCrashed") do |params|
        if (context = find_by(target_id: params["targetId"]))
          context.delete_target(params["targetId"])
        end
      end
    end

    def discover
      @browser.command("Target.setDiscoverTargets", discover: true)
    end
  end
end
