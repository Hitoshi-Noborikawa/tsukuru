require 'rails/generators'
require 'tty-reader'

module Tsukuru
  class RspecGenerator < Rails::Generators::Base
    def create_rspec_file
      reader = TTY::Reader.new
      puts <<~MSG

        RSpecテストケースの内容を詳しく記述してください
        例: 管理者が商品の本をCRUDする。

        Ctrl+d: 続行
        Ctrl+c: キャンセル

      MSG
      prompt = ""
      while prompt == "" do
        prompt = reader.read_multiline('> ')
      end

      puts ""
      puts prompt
    rescue TTY::Reader::InputInterrupt
    end
  end
end
