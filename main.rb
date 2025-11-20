require "js"

class Quiz
    attr_reader :hints, :is_corrected, :answer_log, :point

    KLASSES = [Array, Dir, File, Hash, Integer, Float, Random, Range, Regexp, String, Symbol, Thread, Time]
    EXCLUDE_KLASSES = [Module, Object, Class]
    ANSWER_COST = 100
    
    # メソッドの説明辞書（主要なメソッドのみ）
    METHOD_DESCRIPTIONS = {
      'Array' => {
        'push' => '配列の末尾に要素を追加する',
        'pop' => '配列の末尾の要素を削除して返す',
        'shift' => '配列の先頭の要素を削除して返す',
        'unshift' => '配列の先頭に要素を追加する',
        'first' => '配列の最初の要素を返す',
        'last' => '配列の最後の要素を返す',
        'length' => '配列の要素数を返す',
        'size' => '配列の要素数を返す',
        'empty?' => '配列が空かどうかを返す',
        'include?' => '指定した値が配列に含まれるかを返す',
        'join' => '配列の要素を連結して文字列にする',
        'reverse' => '配列を逆順にする',
        'sort' => '配列を並び替える',
        'uniq' => '配列から重複を削除する',
        'compact' => '配列からnilを削除する',
        'flatten' => 'ネストした配列を平坦化する',
        'map' => '各要素に処理を適用して新しい配列を返す',
        'select' => '条件に合う要素だけを選んで新しい配列を返す',
        'reject' => '条件に合わない要素だけを選んで新しい配列を返す',
        'each' => '各要素に対して繰り返し処理を行う',
        'find' => '条件に合う最初の要素を返す',
        'any?' => 'いずれかの要素が条件を満たすかを返す',
        'all?' => 'すべての要素が条件を満たすかを返す',
        'count' => '条件に合う要素の数を返す',
        'sum' => '配列の要素の合計を返す',
        'max' => '配列の最大値を返す',
        'min' => '配列の最小値を返す',
        'take' => '配列の先頭からn個の要素を返す',
        'drop' => '配列の先頭からn個の要素を削除した配列を返す',
        'slice' => '配列の一部を取り出す',
        'sample' => '配列からランダムに要素を選ぶ',
        'shuffle' => '配列の要素をランダムに並び替える',
        'zip' => '複数の配列を組み合わせる',
      },
      'String' => {
        'length' => '文字列の長さを返す',
        'size' => '文字列の長さを返す',
        'empty?' => '文字列が空かどうかを返す',
        'upcase' => '文字列を大文字にする',
        'downcase' => '文字列を小文字にする',
        'capitalize' => '先頭文字を大文字にする',
        'swapcase' => '大文字と小文字を入れ替える',
        'reverse' => '文字列を逆順にする',
        'include?' => '指定した文字列が含まれるかを返す',
        'start_with?' => '指定した文字列で始まるかを返す',
        'end_with?' => '指定した文字列で終わるかを返す',
        'gsub' => '文字列を置換する',
        'sub' => '最初にマッチした文字列を置換する',
        'strip' => '前後の空白を削除する',
        'chomp' => '末尾の改行を削除する',
        'split' => '文字列を分割して配列にする',
        'chars' => '文字列を1文字ずつの配列にする',
        'bytes' => '文字列をバイト配列にする',
        'lines' => '文字列を行ごとの配列にする',
        'slice' => '文字列の一部を取り出す',
        'concat' => '文字列を連結する',
        'index' => '指定した文字列の位置を返す',
        'match?' => '正規表現にマッチするかを返す',
        'scan' => '正規表現にマッチした部分を配列で返す',
        'tr' => '文字を置換する',
        'delete' => '指定した文字を削除する',
        'count' => '指定した文字の数を返す',
        'to_i' => '文字列を整数に変換する',
        'to_f' => '文字列を浮動小数点数に変換する',
        'to_sym' => '文字列をシンボルに変換する',
      },
      'Hash' => {
        'keys' => 'ハッシュのキーの配列を返す',
        'values' => 'ハッシュの値の配列を返す',
        'each' => 'ハッシュの各要素に対して繰り返し処理を行う',
        'map' => 'ハッシュの各要素に処理を適用して配列を返す',
        'select' => '条件に合う要素だけを選んで新しいハッシュを返す',
        'reject' => '条件に合わない要素だけを選んで新しいハッシュを返す',
        'merge' => 'ハッシュを結合する',
        'fetch' => 'キーに対応する値を取得する',
        'dig' => 'ネストしたハッシュから値を取得する',
        'key?' => '指定したキーが存在するかを返す',
        'has_key?' => '指定したキーが存在するかを返す',
        'value?' => '指定した値が存在するかを返す',
        'empty?' => 'ハッシュが空かどうかを返す',
        'length' => 'ハッシュの要素数を返す',
        'size' => 'ハッシュの要素数を返す',
        'delete' => '指定したキーの要素を削除する',
        'clear' => 'ハッシュを空にする',
        'invert' => 'キーと値を入れ替える',
        'transform_keys' => 'キーを変換して新しいハッシュを返す',
        'transform_values' => '値を変換して新しいハッシュを返す',
        'compact' => 'nilの値を削除する',
        'flatten' => 'ハッシュを配列に変換する',
        'to_a' => 'ハッシュを配列に変換する',
      },
      'Integer' => {
        'times' => '指定回数だけ繰り返し処理を行う',
        'upto' => '指定した値まで増加しながら繰り返す',
        'downto' => '指定した値まで減少しながら繰り返す',
        'abs' => '絶対値を返す',
        'even?' => '偶数かどうかを返す',
        'odd?' => '奇数かどうかを返す',
        'zero?' => 'ゼロかどうかを返す',
        'positive?' => '正の数かどうかを返す',
        'negative?' => '負の数かどうかを返す',
        'succ' => '次の整数を返す',
        'pred' => '前の整数を返す',
        'to_s' => '整数を文字列に変換する',
        'to_f' => '整数を浮動小数点数に変換する',
        'chr' => '整数を文字に変換する',
        'digits' => '整数の各桁を配列で返す',
        'pow' => 'べき乗を計算する',
        'gcd' => '最大公約数を返す',
        'lcm' => '最小公倍数を返す',
        'next' => '次の整数を返す',
      },
      'Float' => {
        'round' => '四捨五入する',
        'ceil' => '切り上げる',
        'floor' => '切り捨てる',
        'truncate' => '整数部分を返す',
        'abs' => '絶対値を返す',
        'finite?' => '有限の数かどうかを返す',
        'infinite?' => '無限大かどうかを返す',
        'nan?' => '非数(NaN)かどうかを返す',
        'zero?' => 'ゼロかどうかを返す',
        'positive?' => '正の数かどうかを返す',
        'negative?' => '負の数かどうかを返す',
        'to_i' => '浮動小数点数を整数に変換する',
        'to_s' => '浮動小数点数を文字列に変換する',
      },
      'Range' => {
        'first' => '範囲の最初の値を返す',
        'last' => '範囲の最後の値を返す',
        'begin' => '範囲の開始値を返す',
        'end' => '範囲の終了値を返す',
        'size' => '範囲の要素数を返す',
        'include?' => '指定した値が範囲に含まれるかを返す',
        'cover?' => '指定した値が範囲に含まれるかを返す',
        'each' => '範囲の各要素に対して繰り返し処理を行う',
        'map' => '範囲の各要素に処理を適用して配列を返す',
        'to_a' => '範囲を配列に変換する',
        'step' => '指定した間隔で範囲を繰り返す',
        'min' => '範囲の最小値を返す',
        'max' => '範囲の最大値を返す',
      },
      'Regexp' => {
        'match' => '文字列が正規表現にマッチするか調べる',
        'match?' => '文字列が正規表現にマッチするかを返す',
        'source' => '正規表現のパターン文字列を返す',
        'options' => '正規表現のオプションを返す',
        'names' => '名前付きキャプチャの名前を返す',
        'casefold?' => '大文字小文字を区別しないかを返す',
      },
      'Time' => {
        'now' => '現在時刻を返す',
        'year' => '年を返す',
        'month' => '月を返す',
        'day' => '日を返す',
        'hour' => '時を返す',
        'min' => '分を返す',
        'sec' => '秒を返す',
        'wday' => '曜日を数値で返す',
        'yday' => '年初からの日数を返す',
        'zone' => 'タイムゾーンを返す',
        'utc' => '協定世界時に変換する',
        'strftime' => '時刻を指定した書式で文字列にする',
        'to_i' => 'Unix時間を返す',
        'to_s' => '時刻を文字列に変換する',
      },
      'Symbol' => {
        'to_s' => 'シンボルを文字列に変換する',
        'to_sym' => 'シンボルを返す',
        'length' => 'シンボルの長さを返す',
        'size' => 'シンボルの長さを返す',
        'empty?' => 'シンボルが空かどうかを返す',
        'upcase' => 'シンボルを大文字にする',
        'downcase' => 'シンボルを小文字にする',
        'capitalize' => 'シンボルの先頭文字を大文字にする',
        'swapcase' => 'シンボルの大文字と小文字を入れ替える',
      },
      'File' => {
        'read' => 'ファイルの内容を読み込む',
        'write' => 'ファイルに書き込む',
        'open' => 'ファイルを開く',
        'exist?' => 'ファイルが存在するかを返す',
        'file?' => 'ファイルかどうかを返す',
        'directory?' => 'ディレクトリかどうかを返す',
        'size' => 'ファイルサイズを返す',
        'basename' => 'ファイル名を返す',
        'dirname' => 'ディレクトリ名を返す',
        'extname' => '拡張子を返す',
        'expand_path' => '絶対パスに変換する',
        'join' => 'パスを結合する',
        'delete' => 'ファイルを削除する',
        'rename' => 'ファイル名を変更する',
      },
      'Dir' => {
        'entries' => 'ディレクトリ内のエントリを配列で返す',
        'exist?' => 'ディレクトリが存在するかを返す',
        'empty?' => 'ディレクトリが空かどうかを返す',
        'mkdir' => 'ディレクトリを作成する',
        'pwd' => 'カレントディレクトリを返す',
        'chdir' => 'カレントディレクトリを変更する',
        'glob' => 'パターンにマッチするファイルを検索する',
        'foreach' => 'ディレクトリ内の各エントリに対して処理を行う',
      },
      'Random' => {
        'rand' => '乱数を生成する',
        'bytes' => 'ランダムなバイト列を生成する',
        'seed' => '乱数生成器のシード値を返す',
      },
      'Thread' => {
        'new' => '新しいスレッドを作成する',
        'current' => '現在のスレッドを返す',
        'join' => 'スレッドの終了を待つ',
        'kill' => 'スレッドを強制終了する',
        'stop' => 'スレッドを停止する',
        'run' => 'スレッドを実行する',
        'alive?' => 'スレッドが実行中かを返す',
        'status' => 'スレッドの状態を返す',
        'priority' => 'スレッドの優先度を返す',
      },
    }.freeze
    
    private_constant :KLASSES, :EXCLUDE_KLASSES, :ANSWER_COST, :METHOD_DESCRIPTIONS

    Hint = Data.define(:cost, :desc, :content)

    def initialize
        @answer = generate_answer
        @hints = generate_hints
        @answer_log = []
        @point = @hints.sum(&:cost) + ANSWER_COST # ヒントを全て使ってちょうど 0 になるように
    end

    def answer!(answer_text)
        @is_corrected ||= is_correct?(answer_text)
        @answer_log << answer_text
        @point -= ANSWER_COST unless is_correct?(answer_text)
    end

    def hint!(hint)
        @point -= hint.cost
    end

    private

    def generate_answer
        klass = KLASSES.sample
        puts klass # Debug
        is_instance = klass.singleton_methods.size.zero? ? true : [true, false].sample
        puts is_instance # Debug
        methods = (is_instance ? klass.instance_methods : klass.methods) - EXCLUDE_KLASSES.flat_map(&:instance_methods)
        method = methods.sample
        puts method # Debug
        method = is_instance ? klass.instance_method(method) : klass.method(method)
        { klass: klass, method: method, method_str: method.name.to_s, is_instance: is_instance }
    end

    def is_correct?(input_answer)
        input_answer.to_s == @answer[:method_str]
    end

    def generate_hints
        hints = [
            Hint.new(200, 'class', @answer[:klass]),
            Hint.new(300, '#owner', @answer[:method].owner),
            Hint.new(200, 'is_instance_method?', @answer[:is_instance]),
            Hint.new(100, '#arity', @answer[:method].arity),
            Hint.new(200, '#parameters', @answer[:method].parameters),
            Hint.new(100, '#length', @answer[:method_str].length),
            Hint.new(200, '#chars.first', @answer[:method_str].chars.first),
            Hint.new(300, '#chars.last', @answer[:method_str].chars.last),
            Hint.new(200, '#chars.count(\'_\')', @answer[:method_str].chars.count('_')),
            Hint.new(500, '#chars.shuffle', @answer[:method_str].chars.shuffle),
            Hint.new(800, 'underbar_position', @answer[:method_str].gsub(/[^_]/, '○')),
        ]
        
        # メソッドの説明を取得してヒントに追加
        if description = get_method_description
            hints << Hint.new(400, 'メソッドの説明', description)
        end
        
        hints.sort_by(&:cost)
    end
    
    def get_method_description
        klass_name = @answer[:klass].name
        method_name = @answer[:method_str]
        METHOD_DESCRIPTIONS.dig(klass_name, method_name)
    end
end

class QuizView
    def initialize(quiz)
        @quiz = quiz
        update_score!

        create_hints
        add_answer_event
        set_ruby_version
    end

    private

    def document
        JS.global['document']
    end

    def update_score!
        document.getElementById('score')[:innerText] = "SCORE: #{@quiz.point}"
    end

    def create_hints
        hints_container = document.getElementById('hints-container')
        template = document.querySelector('#hint-template')
        @quiz.hints.each do |hint|
            clone = template[:content].cloneNode(true)
            button = clone.querySelector('.hint-button')
            button[:innerText] = "#{hint.desc} <#{hint.cost}>"
            hint_content = clone.querySelector('.hint-content')
            button.addEventListener('click') do
                @quiz.hint!(hint)
                update_score!
                button[:disabled] = true
                hint_content[:innerText] = hint.content.to_s
            end
            hints_container.appendChild(clone)
        end
    end

    def add_answer_event
        answer_button = document.getElementById('answer-button')
        answer_button.addEventListener('click') do
            input_answer = document.getElementById('answer-input')[:value]
            @quiz.answer!(input_answer)
            update_score!
            log_text = "#{@quiz.is_corrected ? '✅' : '❌'} #{input_answer}"

            document.createElement('li').tap do |li|
                li[:innerText] = log_text
                document.getElementById('answer-log-list').prepend(li)
            end

            if @quiz.is_corrected
                answer_button[:disabled] = true
                document.getElementById('answer-input')[:disabled] = true
                document.createElement('button').tap do |button|
                    button[:className] = 'restart-button'
                    button[:innerText] = 'restart!'
                    button.addEventListener('click') do
                        JS.global[:location].reload
                    end
                    document.getElementById('answer-form').appendChild(button)
                end
            end
        end
    end

    def set_ruby_version
        document.getElementById('ruby-version')[:innerText] = "RUBY_VERSION: #{RUBY_VERSION}"
    end
end

class QuizController
    def initialize
        @quiz = Quiz.new
        @quiz_view = QuizView.new(@quiz)
    end
end

QuizController.new
