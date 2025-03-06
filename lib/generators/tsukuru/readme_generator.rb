require 'rails/generators'
require 'readline'

module Tsukuru
  class ReadmeGenerator < Rails::Generators::Base
    INITIAL_FILES = [
      'README.md',
      'Gemfile',
      'config/application.rb',
      'config/environments/production.rb',
      'config/environments/staging.rb',
      'config/environments/development.rb',
      'config/environments/test.rb',
      'db/schema.rb',
      'app/models/user.rb',
      'app/models/admin.rb',
      'app/models/administrator.rb',
    ]

    def call
      puts <<~MSG
        プロジェクトについてのREADMEを作成します。
      MSG

      contents = FileInspector.contents(INITIAL_FILES).map do
        <<~CONTENT

          ```#{_1.path}
          #{_1.body}
          ```
        CONTENT
      end
      puts "実行中..."
      response = client.chat(
        messages: [
          { role: 'system', content: <<~CONTENT },
            あなたは README を作成するためのツールです。
            このプロジェクトについてのREADMEを作成してください。

            以下にこのプロジェクトの基本的な情報が含まれているファイルの内容を示します。
            このファイルに従って README に書くべき内容を作成してください。
            既存の README がある場合は、それを参考にしてください。
            無闇に書き換えず、実際のファイルの内容と違う点のみ修正してください。

            #{contents}
          CONTENT
          { role: 'user', content: 'READMEを記載してください。' },
        ]
      )
      puts response.dig('choices', 0, 'message', 'content')
    end

    private

    def client
      @client ||= Tsukuru::OpenAiClient.new
    end
  end
end
