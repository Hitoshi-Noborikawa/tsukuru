require 'rails/generators'
require 'readline'

module Tsukuru
  class RspecGenerator < Rails::Generators::Base
    IGNORED_DIRS = %w[
      node_modules log tmp storage bin db/migrate public/assets public/uploads coverage copilot .*
    ]
    IGNORED_PATTERNS = %w[*.png *.jpg .keep *.log]
    INITIAL_FILES = ['Gemfile', 'package.json', 'routes.rb', 'ja.yml']

    def create_rspec_file
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

      puts ""
      puts "実行中・・・"


      loop_count = 0;
      generated_rspec = analyze_needs_source_file_contents(prompt, INITIAL_FILES, loop_count)

      puts "\nGenerated RSpec Test Cases:\n"
      generated_rspec.each do |rspec|
        puts "#{rspec['code']}\n\n"
      end
    rescue Interrupt
    end

    private

    def all_files
      files = []
      Find.find('.') do |path|
        if File.directory?(path) && IGNORED_DIRS.any? { File.fnmatch?("./#{_1}*", path) }
          Find.prune
        elsif IGNORED_PATTERNS.any? { File.fnmatch?(_1, File.basename(path)) }
          next
        elsif File.basename(path).start_with?('.')
          next
        elsif File.file?(path)
          files << path.sub(/^\.\//, '')
        end
      end
      files
    end

    def file_contents(file_names)
      results = []
      puts "参照しているファイル"
      file_names.each do |file_name|
        file_path = Dir.glob("#{Rails.root}/**/#{file_name}").first
        puts file_path
        if file_name && file_path.present? && File.exist?(file_path)
          content = File.read(file_path)
          results << { file_name:, content: }
        else
          results << { file_name:, content: nil }
        end
      end
      results
    end

    def analyze_needs_source_file_contents(prompt, source_files, loop_count)
      loop_count += 1

      if loop_count > 3
        unique_source_files = source_files.uniq
        result_file_contents = file_contents(unique_source_files)
        puts 'テスト作成中・・・'
        generate_rspec(result_file_contents, prompt)
      else
        add_files = []
        response = call_open_ai(prompt, source_files)
        if response && response[0]['function']
          file_contents = response

          file_contents.each do |file_content|
            function_name = file_content['function']['name']
            arguments = JSON.parse(file_content['function']['arguments'])
            if function_name == 'additional_file_contents' && arguments['file_name'].present?
              puts "追加要求: #{arguments['file_name']}"
              add_files << arguments['file_name']
            end
          end

          if add_files.present?
            source_files.concat(add_files)
            analyze_needs_source_file_contents(prompt, source_files, loop_count)
          end
        end
      end
    end

    def call_open_ai(prompt, source_file_contents)
      user_prompt = <<~TEXT
      rspecとCapybaraを使って#{prompt}のテストを書いてください
      プロジェクト全体のファイル一覧を書きます。
      以下に参考にすべきソースコードと、プロジェクト全体のファイル一覧を書きます。
      ファイル一覧からテストを書くのに参考にしたいファイルを教えてください。
      必要なファイルは出来るだけ一度に全部教えてください。

      教えてくれたら、そのファイルの中身を私から教えます

      回答は必ず有効な 配列をJSON形式で出力してください。配列には必要なファイル名のみ含めてください。追加の解説や余計なテキストは一切含めず、JSON オブジェクトのみを返してください。

      # プロジェクト全体のファイル一覧
      #{all_files}

      # 参考にするソースコード
      #{source_file_contents}

      TEXT
      system_prompt = "あなたはrspecとCapybaraを使って#{prompt}のテストを作成するアシスタントです"

      client = OpenAI::Client.new

      response = client.chat(
        parameters: {
          model: 'gpt-4o-mini',
          messages: [
            { role: 'system', content: system_prompt },
            { role: 'user', content: user_prompt }
          ],
          tools: [
            {
              type: 'function',
              function: {
                name: 'additional_file_contents',
                description: '追加で必要なファイルの内容を取得する',
                parameters: {
                  type: :object,
                  properties: {
                    file_name: {
                      type: :string,
                      description: "不足しているファイル名",
                    },
                  },
                  required: ['file_name'],
                },
              },
            }
          ],
          tool_choice: 'required'
        },
      )
      response.dig('choices', 0, 'message', 'tool_calls')
      # row_data = response.dig('choices', 0, 'message', 'content')
      # json_data = row_data.gsub(/```json\s*/, '').gsub(/\s*```/, '')
      # JSON.parse(json_data)
    end

    def generate_rspec(files, prompt)
      user_prompt = <<~TEXT
      RSpec と Capybara を使って#{prompt}のテストを書いて下さい。
      下記にテスト対象のソースコードがあります。それを参考にしてください

      以下の内容について、回答は必ず有効な 配列をJSON形式で出力してください。追加の解説や余計なテキストは一切含めず、JSON オブジェクトのみを返してください。
      # JSONオブジェクトの形式
      [{ 'description'=>'', 'code'=>'' }]

        #{files}
      TEXT

      client = OpenAI::Client.new

      rule_file_path = Rails.root.join('.tsukururules')
      rule_content = if File.exist?(rule_file_path)
                       <<~PROMPT
                         以下はこのプロジェクト固有のルールです。必ず従ってください。

                         #{File.read(rule_file_path)}
                       PROMPT
                     end
      response = client.chat(
        parameters: {
          model: 'gpt-4o-mini',
          messages: [
            { role: 'system', content: <<~CONTENT },
              RSpec と Capybara を使ってテストコードを書いてください。
              #{rule_content}
            CONTENT
            { role: 'user', content: user_prompt },
          ]
        }
      )
      row_data = response.dig('choices', 0, 'message', 'content')
      json_data = row_data.gsub(/```json\s*/, '').gsub(/\s*```/, '')
      JSON.parse(json_data)
    end
  end
end
