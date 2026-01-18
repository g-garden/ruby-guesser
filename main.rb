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

    def level
        (@total_correct / 3) + 1
    end

    def streak_bonus
        @streak * 50
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

class Quiz
    attr_reader :hints, :is_corrected, :answer_log, :point, :game_stats

    KLASSES = [Array, Dir, File, Hash, Integer, Float, Random, Range, Regexp, String, Symbol, Thread, Time]
    EXCLUDE_KLASSES = [Module, Object, Class]
    ANSWER_COST = 100
    private_constant :KLASSES, :EXCLUDE_KLASSES, :ANSWER_COST

    Hint = Data.define(:cost, :desc, :content)

    def initialize
        @game_stats = GameStats.new
        @answer = generate_answer
        @hints = generate_hints
        @answer_log = []
        @point = @hints.sum(&:cost) + ANSWER_COST + @game_stats.streak_bonus
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
        end
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
        [
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
        ].sort_by(&:cost)
    end
end

class QuizView
    def initialize(quiz)
        @quiz = quiz
        update_all_stats!
        create_hints
        add_answer_event
        set_ruby_version
    end

    private

    def document
        JS.global['document']
    end

    def update_all_stats!
        update_score!
        update_best_score!
        update_streak!
        update_level!
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

    def update_level!
        document.getElementById('level')[:innerText] = @quiz.game_stats.level.to_s
    end

    def animate_score!(is_up)
        # アニメーションを一時的に無効化してエラー原因を特定
        # score_element = document.getElementById('score')
        # score_element[:classList].remove('score-up')
        # score_element[:classList].remove('score-down')
        # class_name = is_up ? 'score-up' : 'score-down'
        # JS.eval("setTimeout(function() { document.getElementById('score').classList.add('#{class_name}'); }, 10);")
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
            end
        end
    end

    def trigger_confetti
        JS.eval(<<~JS)
            (function() {
                const canvas = document.getElementById('confetti-canvas');
                const ctx = canvas.getContext('2d');
                canvas.width = window.innerWidth;
                canvas.height = window.innerHeight;

                const confetti = [];
                const confettiCount = 150;
                const gravity = 0.5;
                const terminalVelocity = 5;
                const colors = ['#667eea', '#764ba2', '#f093fb', '#f5576c', '#4facfe', '#00f2fe'];

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
                            confetti[i] = {
                                x: Math.random() * canvas.width,
                                y: -10,
                                r: c.r,
                                d: c.d,
                                color: c.color,
                                tilt: c.tilt,
                                tiltAngleIncremental: c.tiltAngleIncremental,
                                tiltAngle: c.tiltAngle
                            };
                        }
                    });

                    requestAnimationFrame(draw);
                }

                draw();

                setTimeout(() => {
                    ctx.clearRect(0, 0, canvas.width, canvas.height);
                }, 5000);
            })();
        JS
    end

    def add_answer_event
        answer_button = document.getElementById('answer-button')
        answer_button.addEventListener('click') do
            input_answer = document.getElementById('answer-input')[:value]

            return if input_answer.empty?

            @quiz.answer!(input_answer)
            update_all_stats!

            is_correct = @quiz.is_corrected && @quiz.answer_log.last == input_answer

            if is_correct
                animate_score!(true)
            else
                animate_score!(false)
            end

            log_text = "#{is_correct ? '✅' : '❌'} #{input_answer}"

            document.createElement('li').tap do |li|
                li[:innerText] = log_text
                document.getElementById('answer-log-list').prepend(li)
            end

            if @quiz.is_corrected
                trigger_confetti
                answer_button[:disabled] = true
                document.getElementById('answer-input')[:disabled] = true

                document.createElement('button').tap do |button|
                    button[:className] = 'restart-button'
                    button[:innerText] = '🎉 Next Challenge! 🎉'
                    button.addEventListener('click') do
                        JS.global[:location].reload
                    end
                    document.querySelector('.input-group').appendChild(button)
                end
            end

            document.getElementById('answer-input')[:value] = ''
        end
    end

    def set_ruby_version
        document.getElementById('ruby-version')[:innerText] = "Ruby #{RUBY_VERSION}"
    end
end

class QuizController
    def initialize
        @quiz = Quiz.new
        @quiz_view = QuizView.new(@quiz)
    end
end

QuizController.new
