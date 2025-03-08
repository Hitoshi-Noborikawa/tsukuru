# lib/open_ai_client.rb

module Tsukuru
  class OpenAiClient
    def initialize
      @client =
        if (access_token = ENV['TSUKURU_OPEN_AI_ACCESS_TOKEN']).present?
          OpenAI::Client.new(
            access_token: access_token,
            log_errors: true
          )
        else
          OpenAI::Client.new(log_errors: true)
        end
    end

    def chat(parameters)
      @client.chat(
        parameters: { model: model }.merge(parameters)
      )
    end

    private

    def model
      ENV['TSUKURU_OPEN_AI_MODEL'] ? ENV['TSUKURU_OPEN_AI_MODEL'] : 'gpt-4o-mini'
    end
  end
end
