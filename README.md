# Tsukuru
RSpecテストとREADMEファイルを簡単に作成できるジェネレーター

Tsukuruは OpenAIの gpt-4o-mini モデル を使用してRSpecとREADMEを生成します。

ファイルを生成する際、品質を向上させるため 最大4回のリクエスト をOpenAIに送信します。

## インストール

アプリケーションの `Gemfile` に以下の行を追加してください：
```ruby
gem 'tsukuru', github: 'Hitoshi-Noborikawa/tsukuru', branch: 'main'
```

``` bash
bundle install
```

.env ファイルに以下の環境変数を追加してください：
``` bash
TSUKURU_OPEN_AI_ACCESS_TOKEN=
```

## 使い方
### RSpecの生成
以下のコマンドを実行すると、Railsアプリケーション用のRSpecテストのひな形を生成できます：
```
rails g tsukuru:rspec
```
- RSpecを作成するために必要なファイルを選別し、そのファイルを元にテストを生成します。
- 生成対象のRSpecファイルが 存在しない場合 は新規作成されます。
- 生成対象のRSpecファイルが 既に存在する場合 は上書きされます。

### READMEの生成
以下のコマンドを実行すると、READMEファイルを自動生成できます：
```
rails g tsukuru:readme
```
- READMEを作成するために必要なファイルを選別し、そのファイルを元にREADMEを生成します。
- READMEファイルが 存在しない場合 は新規作成されます。
- READMEファイルが 既に存在する場合 は上書きされます。

#### .tsukururules を使ったカスタマイズ
生成時のプロンプトをカスタマイズするには、 .tsukururules にルールを追加できます。

##### .tsukururules の作成手順

1. プロジェクトのルートディレクトリに .tsukururules ファイルを作成します。
2. RSpecやREADMEの生成をカスタマイズするためのプロンプトを追加します

##### .tsukururules の例
.tsukururules
``` bash
作成するテストはsystemスペックのみ作成してください。
準備するデータはインスタンス変数ではなく、できるだけletを使用してください。
visitの後は1行インデントを開けてください。

トラブルシューティングのセクションを含めてください。
```

### Contributing
バグを発見した場合や改善の提案がある場合は、プルリクエストを送ってください。

### License
The gem is available as open source under the terms of the MIT License.
