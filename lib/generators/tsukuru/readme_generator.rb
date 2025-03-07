# frozen_string_literal: true

require 'rails/generators'
require 'readline'

module Tsukuru
  class ReadmeGenerator < Rails::Generators::Base
    INITIAL_FILES = [
      'README.md',
      'Gemfile',
      'config/application.rb',
      'config/deploy.yml',
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
      generate(user_prompt, collect_contents(file_paths: INITIAL_FILES))
    rescue Interrupt
    end

    private

    def generate(user_prompt, contents, count = 0)
      response = client.chat(
        messages: [
          { role: 'system', content: <<~CONTENT },
            あなたは README を作成するためのツールです。
            このプロジェクトについての情報を集めながら、READMEを作成してください。
            十分な情報が集まったら generate_readme 関数を使って README を生成してください。

            現在は#{count}回調査をしています。
            3回くらい調査しても情報が集まらなければ、README を生成してください。
            それより早く生成しても良いです。

            以下にこのプロジェクトの基本的な情報が含まれているファイルの内容を示します。
            このファイルに従って README に書くべき内容を作成してください。

            #{contents.join("\n")}
          CONTENT
          { role: 'user', content: <<~CONTENT }
            このプロジェクトにふさわしい READMEを記載してください。

            必要な項目は以下の通りです。

            - 本番、ステージングのURL( deploy.yml や production.rb などから分かります )
            - 利用データベースの種類、バージョン ( database.yml や CI の設定などから分かります )
            - 初期データの作成方法（もし方法があれば）
            - 管理者ユーザーの作成方法

            既存の README がある場合は、それを参考にしてください。
            無闇に書き換えず、実際のファイルの内容と違う点のみ修正してください。

            #{user_prompt}
          CONTENT
        ],
        tools: [
          count < 5 ? {
            type: 'function',
            function: {
              name: 'collect_contents',
              description: <<~DESCRIPTION,
                README を正確に書くために、プロジェクトのファイル内容を把握するための関数です。
                引数には必要なファイルのパスを渡します。
              DESCRIPTION
              parameters: {
                type: :object,
                properties: {
                  file_paths: {
                    type: 'array',
                    description: <<~DESC,
                      ファイルの内容を知りたいファイルパスを Rails.root からの相対パスで指定してください。複数指定できます。

                      以下のファイルは全て読み込み済みなので除外してください。
                      #{@loaded_file_paths.join("\n")}
                    DESC
                    items: {
                      type: 'string',
                      enum: Tsukuru::FileInspector.all_paths - @loaded_file_paths
                    }
                  }
                },
                required: ['file_paths']
              }
            }
          } : nil,
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
        ].compact,
        tool_choice: 'required'
      )

      tool_calls = response.dig('choices', 0, 'message', 'tool_calls')
      function_name = tool_calls.dig(0, 'function', 'name')
      arguments = JSON.parse(tool_calls.dig(0, 'function', 'arguments')).transform_keys(&:to_sym)
      if function_name == 'collect_contents' && count < 10
        count += 1
        generate(user_prompt, collect_contents(**arguments), count)
      elsif function_name == 'generate_readme'
        puts "Tried count: #{count}"

        generate_readme(**arguments)
      else
        raise "Max count error #{tool_calls}"
      end
    end

    def generate_readme(content:)
      File.open('README.md', 'w') { _1.write(content) }
      # count の数だけ試行したことを示す
      puts "README.md generated"
    end

    def collect_contents(file_paths:)
      paths = file_paths - @loaded_file_paths
      paths.each do |path|
        if File.exist?(path)
          puts "- #{path}"
          @loaded_file_paths << path
        end
      end
      Tsukuru::FileInspector.contents(@loaded_file_paths).map do
        <<~CONTENT

          #{_1.path} の内容
          ```
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
