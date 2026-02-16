require "js"

class GameStats
    attr_accessor :streak, :total_correct, :best_score

    def initialize
        @streak = load_from_storage('streak').to_i
        @total_correct = load_from_storage('total_correct').to_i
        @best_score = load_from_storage('best_score').to_i
    end

    def increment_streak!
        @streak += 1
        save_to_storage('streak', @streak)
    end

    def reset_streak!
        @streak = 0
        save_to_storage('streak', 0)
    end

    def increment_total_correct!
        @total_correct += 1
        save_to_storage('total_correct', @total_correct)
    end

    def update_best_score!(score)
        if score > @best_score
            @best_score = score
            save_to_storage('best_score', score)
        end
    end

    def combo_multiplier
        case @streak
        when 0..2 then 1.0
        when 3..5 then 1.5
        when 6..9 then 2.0
        else 3.0
        end
    end

    def streak_bonus
        base_bonus = @streak * 50
        (base_bonus * combo_multiplier).to_i
    end

    private

    def load_from_storage(key)
        result = JS.eval("localStorage.getItem('rubyGuesser_#{key}')")
        result.nil? || result.to_s == 'null' ? '0' : result.to_s
    end

    def save_to_storage(key, value)
        JS.eval("localStorage.setItem('rubyGuesser_#{key}', '#{value}')")
    end
end

class GameLife
    attr_reader :current, :max

    def initialize(max_life = 3)
        @max = max_life
        @current = max_life
    end

    def decrease!
        @current = [@current - 1, 0].max
    end

    def recover!(amount = 1)
        @current = [@current + amount, @max].min
    end

    def alive?
        @current > 0
    end

    def game_over?
        @current <= 0
    end
end

class Quiz
    attr_reader :hints, :is_corrected, :answer_log, :point, :game_stats, :life, :answer_str
    attr_reader :answer_klass, :answer_is_instance, :answer_owner, :answer_doc_name

    KLASSES = [Array, Dir, File, Hash, Integer, Float, Random, Range, Regexp, String, Symbol, Thread, Time]
    EXCLUDE_KLASSES = [Module, Object, Class]
    ANSWER_COST = 100
    private_constant :KLASSES, :EXCLUDE_KLASSES, :ANSWER_COST

    Hint = Data.define(:cost, :desc, :content)

    def initialize(game_stats: nil, life: nil)
        @game_stats = game_stats || GameStats.new
        @life = life || GameLife.new(3)
        @answer = generate_answer
        @answer_str = @answer[:method_str]
        @answer_klass = @answer[:klass].to_s
        @answer_is_instance = @answer[:is_instance]
        owner_str = @answer[:method].owner.to_s
        @answer_owner = owner_str.match(/#<Class:(.+)>/) ? $1 : owner_str
        @answer_doc_name = @answer[:method].original_name.to_s
        @hints = generate_hints
        @answer_log = []
        @point = @hints.sum(&:cost) + ANSWER_COST + @game_stats.streak_bonus
        @is_corrected = false
    end

    def answer!(answer_text)
        was_correct = is_correct?(answer_text)
        @is_corrected ||= was_correct
        @answer_log << answer_text

        if was_correct
            @game_stats.increment_streak!
            @game_stats.increment_total_correct!
            @game_stats.update_best_score!(@point)
        else
            @point -= ANSWER_COST
            @game_stats.reset_streak!
            @life.decrease!
        end
    end

    def game_over?
        @life.game_over?
    end

    def hint!(hint)
        @point -= hint.cost
    end

    private

    def generate_answer
        klass = KLASSES.sample
        is_instance = klass.singleton_methods.size.zero? ? true : [true, false].sample
        methods = (is_instance ? klass.instance_methods : klass.methods) - EXCLUDE_KLASSES.flat_map(&:instance_methods)
        method = methods.sample
        method = is_instance ? klass.instance_method(method) : klass.method(method)
        { klass: klass, method: method, method_str: method.name.to_s, is_instance: is_instance }
    end

    def is_correct?(input_answer)
        input_answer.to_s == @answer[:method_str]
    end

    def generate_hints
        method_str = @answer[:method_str]
        [
            # 基本情報（低コスト）
            Hint.new(50, '#length', method_str.length),
            Hint.new(50, '#arity (引数の数)', @answer[:method].arity),
            Hint.new(80, 'is_instance_method?', @answer[:is_instance]),
            Hint.new(100, "ends_with?('?')", method_str.end_with?('?')),
            Hint.new(100, "ends_with?('!')", method_str.end_with?('!')),
            Hint.new(100, "ends_with?('=')", method_str.end_with?('=')),
            Hint.new(120, '#chars.count(\'_\')', method_str.chars.count('_')),

            # 中程度のヒント
            Hint.new(200, 'class', @answer[:klass]),
            Hint.new(250, '#owner', @answer[:method].owner),
            Hint.new(300, '#parameters', @answer[:method].parameters),

            # 強力なヒント（高コスト）
            Hint.new(400, '#chars.first', method_str.chars.first),
            Hint.new(450, '#chars.last', method_str.chars.last),
            Hint.new(500, '#chars[1] (2文字目)', method_str.length > 1 ? method_str[1] : '(なし)'),
            Hint.new(600, 'vowels_count (母音数)', method_str.downcase.count('aeiou')),
            Hint.new(800, '#chars.shuffle', method_str.chars.shuffle.join),
            Hint.new(1000, 'underbar_position', method_str.gsub(/[^_]/, '○')),
        ].sort_by(&:cost)
    end
end

class QuizView
    def initialize(quiz, controller = nil)
        @quiz = quiz
        @controller = controller
        reset_ui!
        update_all_stats!
        create_hints
        add_answer_event
        set_ruby_version
        setup_controller_bridge if @controller
        setup_debug!
    end

    def reset_ui!
        JS.eval(<<~JS)
            // フラグをリセット
            window.nextQuizReady = false;

            // ヒントをクリア
            document.getElementById('hints-container').innerHTML = '';

            // 回答ログをクリア
            document.getElementById('answer-log-list').innerHTML = '';

            // ボタンを複製して既存のイベントリスナーをすべて削除
            var oldBtn = document.getElementById('answer-button');
            var newBtn = oldBtn.cloneNode(false);
            newBtn.id = 'answer-button';
            newBtn.innerHTML = '<span class="button-text">Guess!</span><span class="button-icon">🚀</span>';
            oldBtn.parentNode.replaceChild(newBtn, oldBtn);

            // 入力を有効化・クリア
            var btn = document.getElementById('answer-button');
            btn.disabled = false;
            btn.classList.remove('next-button');

            document.getElementById('answer-input').disabled = false;
            document.getElementById('answer-input').value = '';
            document.getElementById('answer-input').focus();

            // Next Challengeボタンを削除
            var restartBtn = document.querySelector('.input-group .restart-button');
            if (restartBtn) restartBtn.remove();

            // 正解モーダルを閉じる
            document.getElementById('correct-modal').classList.add('hidden');
            document.getElementById('correct-modal-body').innerHTML = '';

            // Confettiを停止・クリア
            if (window.confettiAnimationId) {
                cancelAnimationFrame(window.confettiAnimationId);
                window.confettiAnimationId = null;
            }
            var canvas = document.getElementById('confetti-canvas');
            var ctx = canvas.getContext('2d');
            ctx.clearRect(0, 0, canvas.width, canvas.height);
        JS
    end

    def setup_controller_bridge
        JS.global[:window][:rubyController] = JS.global[:Object].new
        JS.global[:window][:rubyController][:nextQuiz] = proc do
            @controller.next_quiz!
        end.to_js
    end

    private

    def document
        JS.global['document']
    end

    def update_all_stats!
        update_score!
        update_best_score!
        update_streak!
        update_life!
    end

    def update_score!
        score_element = document.getElementById('score')
        score_element[:innerText] = @quiz.point.to_s
    end

    def update_best_score!
        document.getElementById('best-score')[:innerText] = @quiz.game_stats.best_score.to_s
    end

    def update_streak!
        document.getElementById('streak')[:innerText] = @quiz.game_stats.streak.to_s
    end

    def update_life!
        hearts = (1..@quiz.life.max).map do |i|
            if i <= @quiz.life.current
                '<span class="heart active">❤️</span>'
            else
                '<span class="heart inactive">🖤</span>'
            end
        end.join
        JS.eval("document.getElementById('life').innerHTML = '#{hearts}';")
    end

    def animate_life_damage!
        JS.eval(<<~JS)
            (function() {
                var hearts = document.querySelectorAll('.heart.active');
                if (hearts.length > 0) {
                    var lastHeart = hearts[hearts.length - 1];
                    lastHeart.classList.add('damage');
                    setTimeout(function() {
                        lastHeart.classList.remove('damage');
                    }, 500);
                }
            })();
        JS
    end

    def show_game_over!
        answer = @quiz.answer_str.gsub("'", "\\'")
        JS.eval(<<~JS)
            document.getElementById('final-score').innerText = '#{@quiz.point}';
            document.getElementById('correct-answer').innerText = '#{answer}';
            document.getElementById('game-over-overlay').classList.remove('hidden');
        JS
    end

    def show_correct_notification!
        answer = @quiz.answer_str.gsub("'", "\\'")
        JS.eval(<<~JS)
            (function() {
                var existing = document.querySelector('.correct-notification');
                if (existing) existing.remove();

                var notification = document.createElement('div');
                notification.className = 'correct-notification';
                notification.innerHTML = '<span class="correct-icon">🎉</span><span class="correct-text">Correct!</span><span class="correct-answer">#{answer}</span>';
                document.body.appendChild(notification);

                setTimeout(function() {
                    notification.classList.add('fade-out');
                    setTimeout(function() {
                        notification.remove();
                    }, 500);
                }, 2500);
            })();
        JS
    end

    def show_combo_notification!
        streak = @quiz.game_stats.streak
        return if streak < 3

        multiplier = @quiz.game_stats.combo_multiplier
        JS.eval(<<~JS)
            (function() {
                var existing = document.querySelector('.combo-notification');
                if (existing) existing.remove();

                var notification = document.createElement('div');
                notification.className = 'combo-notification';
                notification.innerHTML = '<span class="combo-count">#{streak} COMBO!</span><span class="combo-multiplier">x#{multiplier}</span>';
                document.body.appendChild(notification);

                setTimeout(function() {
                    notification.classList.add('fade-out');
                    setTimeout(function() {
                        notification.remove();
                    }, 500);
                }, 2000);
            })();
        JS
    end

    def show_correct_modal!
        method_name = @quiz.answer_str.gsub("'", "\\'")
        doc_name = @quiz.answer_doc_name.gsub("'", "\\'")
        klass = @quiz.answer_klass
        owner = @quiz.answer_owner
        is_instance = @quiz.answer_is_instance
        method_type = is_instance ? 'i' : 's'

        JS.eval(<<~JS)
            (function() {
                var docName = '#{doc_name}';
                var anchor = ('#{method_type}' === 'i' ? 'I_' : 'S_') +
                    docName.replace(/[^a-zA-Z0-9_]/g, function(c) {
                        return '--' + c.charCodeAt(0).toString(16).toUpperCase().padStart(2, '0');
                    }).toUpperCase();
                var docUrl = 'https://docs.ruby-lang.org/ja/3.3/class/#{owner}.html#' + anchor;

                document.getElementById('correct-modal-body').innerHTML = `
                    <div class="correct-modal-method">
                        <div class="correct-modal-class">#{klass}</div>
                        <div class="correct-modal-type">#{is_instance ? 'instance' : 'class'} method</div>
                        <div class="correct-modal-method-name">#{method_name}</div>
                        <a href="${docUrl}" target="_blank" class="correct-modal-doc-link">
                            📚 Rubyドキュメントを見る
                        </a>
                    </div>
                `;
                document.getElementById('correct-modal').classList.remove('hidden');

                document.getElementById('correct-modal-next-btn').onclick = function() {
                    document.getElementById('correct-modal').classList.add('hidden');
                    if (window.rubyController && window.rubyController.nextQuiz) {
                        window.rubyController.nextQuiz();
                    } else {
                        location.reload();
                    }
                };
            })();
        JS
    end

    def animate_score!(is_up)
        class_name = is_up ? 'score-up' : 'score-down'
        JS.eval(<<~JS)
            (function() {
                var el = document.getElementById('score');
                el.classList.remove('score-up', 'score-down');
                void el.offsetWidth;
                el.classList.add('#{class_name}');
            })();
        JS
    end

    def flash_result!(is_correct)
        class_name = is_correct ? 'flash-correct' : 'flash-incorrect'
        JS.eval(<<~JS)
            (function() {
                document.body.classList.add('#{class_name}');
                setTimeout(function() {
                    document.body.classList.remove('#{class_name}');
                }, 500);
            })();
        JS
    end

    def create_hints
        hints_container = document.getElementById('hints-container')
        template = document.querySelector('#hint-template')
        @quiz.hints.each_with_index do |hint, index|
            clone = template[:content].cloneNode(true)
            button = clone.querySelector('.hint-button')
            hint_content = clone.querySelector('.hint-content')

            # 一意のIDを設定
            hint_content_id = "hint-content-#{index}"
            hint_content[:id] = hint_content_id
            button[:innerText] = "#{hint.desc} <#{hint.cost}>"

            # DOMに追加
            hints_container.appendChild(clone)

            # イベントリスナーを追加（DOM追加後）
            button.addEventListener('click') do
                @quiz.hint!(hint)
                update_score!
                animate_score!(false)
                button[:disabled] = true

                # DOMから直接取得
                content_element = document.getElementById(hint_content_id)
                content_element[:innerText] = hint.content.to_s
                content_element[:classList].add('visible')
            end
        end
    end

    def trigger_confetti
        JS.eval(<<~JS)
            (function() {
                // 既存のアニメーションを停止
                if (window.confettiAnimationId) {
                    cancelAnimationFrame(window.confettiAnimationId);
                }

                const canvas = document.getElementById('confetti-canvas');
                const ctx = canvas.getContext('2d');
                canvas.width = window.innerWidth;
                canvas.height = window.innerHeight;

                const confetti = [];
                const confettiCount = 150;
                const colors = ['#667eea', '#764ba2', '#f093fb', '#f5576c', '#4facfe', '#00f2fe'];
                let isRunning = true;

                for (let i = 0; i < confettiCount; i++) {
                    confetti.push({
                        x: Math.random() * canvas.width,
                        y: Math.random() * canvas.height - canvas.height,
                        r: Math.random() * 6 + 4,
                        d: Math.random() * confettiCount,
                        color: colors[Math.floor(Math.random() * colors.length)],
                        tilt: Math.floor(Math.random() * 10) - 10,
                        tiltAngleIncremental: Math.random() * 0.07 + 0.05,
                        tiltAngle: 0
                    });
                }

                function draw() {
                    if (!isRunning) return;

                    ctx.clearRect(0, 0, canvas.width, canvas.height);

                    confetti.forEach((c, i) => {
                        ctx.beginPath();
                        ctx.lineWidth = c.r / 2;
                        ctx.strokeStyle = c.color;
                        ctx.moveTo(c.x + c.tilt + c.r, c.y);
                        ctx.lineTo(c.x + c.tilt, c.y + c.tilt + c.r);
                        ctx.stroke();

                        c.tiltAngle += c.tiltAngleIncremental;
                        c.y += (Math.cos(c.d) + 3 + c.r / 2) / 2;
                        c.tilt = Math.sin(c.tiltAngle - i / 3) * 15;

                        if (c.y > canvas.height) {
                            confetti[i].y = -10;
                            confetti[i].x = Math.random() * canvas.width;
                        }
                    });

                    window.confettiAnimationId = requestAnimationFrame(draw);
                }

                draw();

                // 5秒後に停止
                setTimeout(() => {
                    isRunning = false;
                    ctx.clearRect(0, 0, canvas.width, canvas.height);
                    window.confettiAnimationId = null;
                }, 5000);
            })();
        JS
    end

    def add_answer_event
        JS.eval(<<~JS)
            window.nextQuizReady = false;
            document.getElementById('answer-button').addEventListener('click', function(e) {
                // 次へボタンとして動作
                if (window.nextQuizReady) {
                    window.nextQuizReady = false;
                    if (window.rubyController && window.rubyController.nextQuiz) {
                        window.rubyController.nextQuiz();
                    } else {
                        location.reload();
                    }
                    return;
                }

                const input = document.getElementById('answer-input');
                const inputAnswer = input.value.trim();

                if (inputAnswer === '') return;

                // RubyのメソッドをJavaScript経由で呼び出す
                window.rubyQuizView.processAnswer(inputAnswer);

                input.value = '';
            });
        JS

        # RubyのメソッドをJavaScriptから呼び出せるようにする
        JS.global[:window][:rubyQuizView] = JS.global[:Object].new
        JS.global[:window][:rubyQuizView][:processAnswer] = proc do |input_answer|
            @quiz.answer!(input_answer.to_s)
            update_all_stats!

            is_correct = @quiz.is_corrected && @quiz.answer_log.last.to_s == input_answer.to_s

            flash_result!(is_correct)

            if is_correct
                animate_score!(true)
                show_combo_notification!
            else
                animate_score!(false)
                animate_life_damage!
            end

            # 履歴に追加（不正解のみ）
            unless is_correct
                escaped_answer = input_answer.to_s.gsub("\\", "\\\\\\\\").gsub("'", "\\\\'").gsub('"', '\\"')
                JS.eval(<<~JS)
                    (function() {
                        var container = document.getElementById('answer-log-list');
                        var span = document.createElement('span');
                        span.className = 'answer-incorrect';
                        span.textContent = '✗ #{escaped_answer}';
                        container.appendChild(span);
                        while (container.children.length > 3) {
                            container.removeChild(container.firstChild);
                        }
                    })();
                JS
            end

            # ゲームオーバー判定
            if @quiz.game_over?
                show_game_over!
                JS.eval(<<~JS)
                    document.getElementById('answer-button').disabled = true;
                    document.getElementById('answer-input').disabled = true;
                JS
            elsif @quiz.is_corrected
                trigger_confetti
                show_correct_modal!
                JS.eval(<<~JS)
                    document.getElementById('answer-input').disabled = true;
                    document.getElementById('answer-button').disabled = true;
                JS
            end
        end.to_js
    end

    def set_ruby_version
        document.getElementById('ruby-version')[:innerText] = "Ruby #{RUBY_VERSION}"
    end

    def setup_debug!
        answer = @quiz.answer_str.gsub("'", "\\'")
        doc_name = @quiz.answer_doc_name.gsub("'", "\\'")
        klass = @quiz.answer_klass
        owner = @quiz.answer_owner
        is_instance = @quiz.answer_is_instance
        method_type = is_instance ? '#' : '.'

        # コンソールで常時確認可能
        JS.eval(<<~JS)
            window.__debug = {
                answer: '#{answer}',
                docName: '#{doc_name}',
                klass: '#{klass}',
                owner: '#{owner}',
                methodType: '#{method_type}',
                full: '#{owner}#{method_type}#{answer}'
            };
            console.log('[DEBUG] answer:', window.__debug.full, window.__debug.answer !== window.__debug.docName ? '(alias of: ' + window.__debug.docName + ')' : '');
        JS

        # ?debug がURLにある場合は画面にも表示
        JS.eval(<<~JS)
            if (new URLSearchParams(window.location.search).has('debug')) {
                var existing = document.getElementById('debug-badge');
                if (existing) existing.remove();
                var badge = document.createElement('div');
                badge.id = 'debug-badge';
                badge.style.cssText = 'position:fixed;bottom:16px;right:16px;background:#1a1a2e;border:1px solid #667eea;border-radius:8px;padding:8px 14px;font-family:monospace;font-size:13px;color:#f0f0f0;z-index:9999;opacity:0.9;';
                badge.innerHTML = '<span style="color:#aaa;font-size:11px;">answer</span><br><span style="color:#4facfe;font-weight:bold;">#{owner}#{method_type}#{answer}</span>';
                document.body.appendChild(badge);
            }
        JS
    end
end

class QuizController
    def initialize
        @game_stats = GameStats.new
        @life = GameLife.new(3)
        start_new_quiz
    end

    def start_new_quiz
        @quiz = Quiz.new(game_stats: @game_stats, life: @life)
        @quiz_view = QuizView.new(@quiz, self)
    end

    def next_quiz!
        start_new_quiz
    end
end

QuizController.new
