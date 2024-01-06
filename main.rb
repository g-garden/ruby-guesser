require "js"

class Quiz
    attr_reader :hints, :is_corrected, :answer_log, :point

    KLASSES = [Array, Dir, File, Hash, Integer, Float, Random, Range, Regexp, String, Symbol, Thread, Time]
    EXCLUDE_KLASSES = [Module, Object, Class]
    ANSWER_COST = 100
    private_constant :KLASSES, :EXCLUDE_KLASSES, :ANSWER_COST

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
