require 'rails/generators'
require 'readline'

module Tsukuru
  class RspecGenerator < Rails::Generators::Base
    INITIAL_FILES = ['Gemfile', 'package.json', 'config/routes.rb', 'config/locales/ja.yml'].freeze

    def create_rspec_file
      @loaded_file_paths = []
      puts <<~MSG

        RSpecテストケースの内容を詳しく記述してください
        例: 管理者が商品の本をCRUDする

        続行: 空行で改行
        終了: Ctrl+C

      MSG

      lines = []
      loop do
        lines << Readline.readline('> ', true)
        break if lines.compact_blank.size > 0 && lines.last == ''
      end

      prompt = lines.join("\n").strip

      puts ''
      puts 'Generating...'
      generate(prompt, contents(file_paths: INITIAL_FILES))
    rescue Interrupt
    end

    private

    def generate(prompt, file_contents, count = 0)
      response = client.chat(
        messages: [
          { role: 'system', content: <<~CONTENT },
            あなたはRspecとCapybaraを使って#{prompt}のテストを書くツールです。
            このプロジェクトについてのRspecとCapybaraを使った#{prompt}のテストを作成してください。
            以下に参考にすべきソースコードと、プロジェクト全体のファイル一覧を書きます。

            # プロジェクト全体のファイル一覧
            #{Tsukuru::FileInspector.all_paths - @loaded_file_paths}

            # 参考にするファイルとソースコード
            #{file_contents}

            #{rule_content}
            CONTENT
          { role: 'user', content: "RspecとCapybaraを使って#{prompt}のテストを作成してください。" }
        ],
        tools: [
          count < 3 ? {
            type: 'function',
            function: {
              name: 'additional_file_contents',
              description: <<~DESCRIPTION,
                RspecとCapybaraを使って#{prompt}のテストを正確に書くため、プロジェクトのファイル内容を把握するための関数です。
                引数には必要なファイルのパスを渡します。
              DESCRIPTION
              parameters: {
                type: :object,
                properties: {
                  file_paths: {
                    type: 'array',
                    description: <<~DESCRIPTION,
                      ファイルパスを Rails.root からの相対パスで指定してください。
                      複数指定できます。
                    DESCRIPTION
                    items: {
                      type: 'string',
                      enum: Tsukuru::FileInspector.all_paths - @loaded_file_paths
                    },
                  },
                },
              required: ['file_paths'],
              },
            },
          } : nil,
          {
            type: 'function',
            function: {
              name: 'generate_rspec',
              description: <<~DESCRIPTION,
                RspecとCapybaraを使って#{prompt}をテストするコードを実際に生成するための関数です。
                引数codeにはRspecコードを返します。
                引数code_pathには引数codeのRspecコードを作成するファイルパスを返します。
              DESCRIPTION
              parameters: {
                type: :object,
                properties: {
                  code: {
                    type: 'string',
                    description: <<~DESCRIPTION,
                      #{prompt}をテストするRspecのコードを返してください。
                      RailsのI18nの日本語ファイルはja.ymlを使用しています。
                      これを元に画面を作成しているので、Rspecのコードを書く際にはja.ymlを値を使用してください。
                    DESCRIPTION
                  },
                  file_path: {
                    type: 'string',
                    description: "#{prompt}をテストするRspecのファイルパスを返してください。",
                  },
                },
                required: ['code', 'file_path'],
              },
            },
          }.compact,
        ],
        tool_choice: 'required'
      )
      tool_calls = response.dig('choices', 0, 'message', 'tool_calls')
      function_name = tool_calls.dig(0, 'function', 'name')
      arguments = JSON.parse(tool_calls.dig(0, 'function', 'arguments')).transform_keys(&:to_sym)
      if function_name == 'additional_file_contents' && count < 4
        count += 1
        generate(prompt, contents(**arguments), count)
      elsif function_name == 'generate_rspec'
        generate_rspec(arguments[:code], arguments[:file_path])
      else
        raise '問題が発生しました。もう一度やり直してください。'
      end
    end

    def generate_rspec(code, rspec_path)
      FileUtils.mkdir_p(File.dirname(rspec_path))
      File.open(rspec_path, 'w') { _1.write(code) }
      puts "#{rspec_path} Generated"
    end

    def contents(file_paths:)
      paths = file_paths - @loaded_file_paths
      paths.each do |path|
        puts "- #{path}"
      end
      @loaded_file_paths += paths
      Tsukuru::FileInspector.contents(@loaded_file_paths).map do
        <<~CONTENT

          ```#{_1.path}
          #{_1.body}
          ```
        CONTENT
      end
    end

    def rule_content
      rule_file_path = Rails.root.join('.tsukururules')
      if File.exist?(rule_file_path)
        <<~PROMPT
          以下はこのプロジェクト固有のルールです。必ず従ってください。

          #{File.read(rule_file_path)}
        PROMPT
      else
        ''
      end
    end

    def client
      @client ||= Tsukuru::OpenAiClient.new
    end
  end
end
