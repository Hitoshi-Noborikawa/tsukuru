# frozen_string_literal: true

require 'rails/generators'
require 'readline'

module Tsukuru
  class ReadmeGenerator < Rails::Generators::Base
    INITIAL_FILES = [
      'README.md',
      'Gemfile',
      'config/application.rb',
      'config/database.yml',
      'config/database.yml.sample',
      'config/environments/production.rb',
      'config/environments/staging.rb',
      'config/environments/development.rb',
      'config/environments/test.rb',
      'app/models/user.rb',
      'app/models/admin.rb',
      'app/models/administrator.rb'
    ].freeze

    def call
      @loaded_file_paths = []
      puts <<~MSG
        プロジェクトについてのREADMEを作成します。

        特に含めたい内容があれば指示してください。

      MSG

      lines = []
      loop do
        lines << Readline.readline('> ', true)
        break if lines.last == ''
      end

      user_prompt = lines.join("\n").strip

      puts 'Generating...'
      generate(user_prompt, contents(file_paths: INITIAL_FILES))
    rescue Interrupt
    end

    private

    def generate(user_prompt, contents, count = 0)
      response = client.chat(
        messages: [
          { role: 'system', content: <<~CONTENT },
            あなたは README を作成するためのツールです。
            このプロジェクトについてのREADMEを作成してください。

            以下にこのプロジェクトの基本的な情報が含まれているファイルの内容を示します。
            このファイルに従って README に書くべき内容を作成してください。
            必要な項目は以下の通りです。

            - 本番、ステージングのURL
            - 利用データベースの種類、バージョン ( CI 情報などから分かることがあります )
            - 初期データの作成方法（もし方法があれば）
            - 管理者ユーザーの作成方法

            既存の README がある場合は、それを参考にしてください。
            無闇に書き換えず、実際のファイルの内容と違う点のみ修正してください。

            #{contents}
          CONTENT
          { role: 'user', content: <<~CONTENT }
            READMEを記載してください。
            #{user_prompt}
          CONTENT
        ],
        tools: [
          {
            type: 'function',
            function: {
              name: 'contents',
              description: <<~DESCRIPTION,
                README を正確に書くために、プロジェクトのファイル内容を把握するための関数です。
                引数には必要なファイルのパスを渡します。
              DESCRIPTION
              parameters: {
                type: :object,
                properties: {
                  file_paths: {
                    type: 'array',
                    description: 'ファイルパスを Rails.root からの相対パスで指定してください。複数指定できます。',
                    items: {
                      type: 'string',
                      enum: Tsukuru::FileInspector.all_paths - @loaded_file_paths
                    }
                  }
                },
                required: ['file_paths']
              }
            }
          },
          {
            type: 'function',
            function: {
              name: 'generate_readme',
              description: <<~DESCRIPTION,
                README ファイルを実際に生成するための関数です。
                引数には Markdown 形式で README の内容を返します。
              DESCRIPTION
              parameters: {
                type: :object,
                properties: {
                  content: {
                    type: 'string',
                    description: 'README の内容を Markdown 形式で指定してください。'
                  }
                },
                required: ['content']
              }
            }
          }
        ],
        tool_choice: 'required'
      )

      tool_calls = response.dig('choices', 0, 'message', 'tool_calls')
      function_name = tool_calls.dig(0, 'function', 'name')
      arguments = JSON.parse(tool_calls.dig(0, 'function', 'arguments')).transform_keys(&:to_sym)
      if function_name == 'contents' && count < 3
        count += 1
        generate(contents(**arguments), count)
      elsif function_name == 'generate_readme'
        generate_readme(**arguments)
      else
        raise "Max count error #{tool_calls}"
      end
    end

    def generate_readme(content:)
      File.open('README.md', 'w') { _1.write(content) }
      puts 'README.md generated'
    end

    def contents(file_paths:)
      paths = file_paths - @loaded_file_paths
      paths.each do |path|
        puts "- #{path}"
      end
      @loaded_file_paths += paths
      Tsukuru::FileInspector.contents(paths).map do
        <<~CONTENT

          ```#{_1.path}
          #{_1.body}
          ```
        CONTENT
      end
    end

    def client
      @client ||= Tsukuru::OpenAiClient.new
    end
  end
end
