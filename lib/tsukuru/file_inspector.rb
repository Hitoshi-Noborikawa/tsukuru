# frozen_string_literal: true

require 'find'

module Tsukuru
  class FileInspector
    class << self
      IGNORED_DIRS = %w[
        node_modules log tmp storage bin db/migrate public/assets public/uploads coverage copilot .*
      ].freeze
      IGNORED_PATTERNS = %w[*.png *.jpg .keep *.log *.lock].freeze
      # TODO: ja.ymlは後方一致で取得できるようにしたい
      INITIAL_FILES = ['Gemfile', 'package.json', 'routes.rb', 'ja.yml'].freeze

      def all_paths
        paths = []
        Find.find('.') do |path|
          if File.directory?(path) && IGNORED_DIRS.any? { File.fnmatch?("./#{_1}*", path) }
            Find.prune
          elsif IGNORED_PATTERNS.any? { File.fnmatch?(_1, File.basename(path)) }
            next
          elsif File.basename(path).start_with?('.')
            next
          elsif File.file?(path)
            paths << path.sub(%r{^\./}, '')
          end
        end
        paths
      end

      FileContent = Struct.new(:path, :body)
      def contents(file_paths)
        results = []
        file_paths.each do |file_path|
          if File.exist?(file_path)
            results << FileContent.new(path: file_path, body: File.read(file_path))
          end
        end
        results
      end
    end
  end
end
