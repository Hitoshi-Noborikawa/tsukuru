require 'rails/generators'
require 'tty-reader'

module Tsukuru
  class RspecGenerator < Rails::Generators::Base
    IGNORED_DIRS = %w[
      node_modules log tmp storage bin db/migrate public/assets public/uploads coverage copilot .*
    ]
    IGNORED_PATTERNS = %w[*.png *.jpg .keep *.log]

    def create_rspec_file
      reader = TTY::Reader.new
      puts <<~MSG

        RSpecテストケースの内容を詳しく記述してください
        例: 管理者が商品の本をCRUDする。

        Ctrl+d: 続行
        Ctrl+c: キャンセル

      MSG

      # NOTE: 空文字で抜けるのを防ぐためにループしている
      prompt = ""
      while prompt == "" do
        prompt = reader.read_multiline('> ')
      end

      puts ""
      puts "実行中..."

      created_rspec = create_rspec(prompt)

      puts "\nGenerated RSpec Test Cases:\n"
      created_rspec.each do |rspec|
        puts "【#{rspec['description']}】"
        puts "#{rspec['code']}\n\n"
      end
    rescue TTY::Reader::InputInterrupt
    end

    private

    def create_rspec(prompt, max_loop_count = 3)
      files = required_files(all_files, prompt)
      file_contents = file_contents(files)
      rspec_code = generate_rspec(file_contents, prompt)

      loop_count = 0

      loop do
        loop_count += 1
        break if loop_count > max_loop_count

        response = analyze_missing_dependencies(rspec_code, file_contents)

        if response && response['function_call']
          function_name = response['function_call']['name']
          arguments = JSON.parse(response['function_call']['arguments'])

          if function_name == 'additional_file_contents' && arguments['file_name'].present?
            additional_content = additional_file_contents(arguments['file_name'])

            if additional_content.present?
              file_contents << additional_content
              rspec_code = generate_rspec(file_contents)
            else
              break
            end
          else
            break
          end
        else
          break
        end
      end

      rspec_code
    end

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

    def required_files(files, prompt)
      user_prompt = <<~TEXT
      rspec と Capybara を使って#{prompt}のテストを書きます。
      プロジェクト全体のファイル一覧を書きます。
      ファイル一覧からテストを書くのに参考にしたいファイルを教えてください。
      ファイル一覧にはないファイルは提供できません。
      教えてくれたら、そのファイルの中身を私から教えます。

      以下の内容について、回答は必ず有効な 配列をJSON形式で出力してください。追加の解説や余計なテキストは一切含めず、JSON オブジェクトのみを返してください。

      #{files}
      TEXT

      client = OpenAI::Client.new

      response = client.chat(
        parameters: {
          model: 'gpt-4o-mini',
          messages: [
            { role: 'user', content: user_prompt },
          ]
        }
      )
      row_data = response.dig('choices', 0, 'message', 'content')
      json_data = row_data.gsub(/```json\s*/, '').gsub(/\s*```/, '')
      JSON.parse(json_data)
    end

    def file_contents(file_names)
      results = {}
      file_names.each do |file_name|
        file_path = Dir.glob("#{Rails.root}/**/#{file_name}").first

        if file_name && file_path.present? && File.exist?(file_path)
          results[file_name] = File.read(file_path)
        else
          results[file_name] = nil
        end
      end
      results
    end

    def generate_rspec(files, prompt)
      user_prompt = <<~TEXT
      rspec と Capybara を使って#{prompt}のテストを書いて下さい。
      下記にテスト対象のソースコードがあります。それを参考にしてください

      以下の内容について、回答は必ず有効な 配列をJSON形式で出力してください。追加の解説や余計なテキストは一切含めず、JSON オブジェクトのみを返してください。
      # JSONオブジェクトの形式
      [{ 'description'=>'', 'code'=>'' }]

        #{files}
      TEXT

      client = OpenAI::Client.new

      response = client.chat(
        parameters: {
          model: 'gpt-4o-mini',
          messages: [
            { role: 'user', content: user_prompt },
          ]
        }
      )
      row_data = response.dig('choices', 0, 'message', 'content')
      json_data = row_data.gsub(/```json\s*/, '').gsub(/\s*```/, '')
      JSON.parse(json_data)
    end

    def additional_file_contents(file_name)
      file_path = Dir.glob("#{Rails.root}/**/#{file_name}").first

      if file_name && file_path.present? && File.exist?(file_path)
        File.read(file_path)
      else
        nil
      end
    end

    def analyze_missing_dependencies(rspec_code, file_list)
      client = OpenAI::Client.new
      user_prompt = <<~TEXT
        以下のテストコードから、追加で必要なファイルがあれば、additional_file_content関数を呼び出す形で指示してください。
        必要な場合は、file_nameを引数として指定してください。
        テストコード: #{rspec_code} 対象ファイルリスト: #{file_list}
      TEXT

      response = client.chat(
        parameters: {
          model: 'gpt-4o-mini',
          messages: [
            { role: 'system', content: 'あなたはテストコードの依存関係解析を行うアシスタントです。' },
            { role: 'user', content: user_prompt }
          ],
          functions: [
            {
              name: 'additional_file_content',
              description: '追加で必要なファイルの内容を取得するための関数です',
              parameters: {
                type: 'object',
                properties: {
                  file_name: {
                    type: 'string',
                    description: '不足しているファイル名'
                  }
                },
                required: ['file_name']
              }
            }
          ],
          function_call: 'auto',
          temperature: 0
        }
      )
      response.dig('choices', 0, 'message')
    end
  end
end
