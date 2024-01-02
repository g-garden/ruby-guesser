require "js"

class Quiz
    attr_reader :hints, :is_corrected, :answer_log, :point

    KLASSES = [Array, Dir, File, Hash, Integer, Float, Random, Range, Regexp, String, Symbol, Thread, Time]
    EXCLUDE_KLASSES = [Module, Object, Class]
    private_constant :KLASSES

    Hint = Data.define(:cost, :desc, :content)

    def initialize
        @answer = generate_answer
        @hints = generate_hints
        @answer_log = []
        @point = 3000
    end

    def answer!(answer_text)
        @is_corrected ||= is_correct?(answer_text)
        @answer_log << answer_text
        @point -= 100 unless is_correct?(answer_text)
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
            Hint.new(200, 'is_instance_method?', @answer[:is_instance]),
            Hint.new(200, 'class', @answer[:klass]),
            Hint.new(300, '#owner', @answer[:method].owner),
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
        @quiz.hints.each do |hint|
            document.createElement('div').tap do |div|
                div[:className] = 'hint'
                document.createElement('button').tap do |button|
                    button[:className] = 'hint-button'
                    button[:innerText] = "#{hint.desc} <#{hint.cost}>"
                    button.addEventListener('click') do
                        @quiz.hint!(hint)
                        update_score!
                        document.createElement('p').tap do |p|
                            p[:className] = 'hint-text'
                            p[:innerText] = hint.content.to_s
                            div.appendChild(p)
                        end
                    end
                    div.appendChild(button)
                end
                document.getElementById('hints-container').appendChild(div)
            end
        end
    end

    def add_answer_event
        document.getElementById('answer-button').addEventListener('click') do
            input_answer = document.getElementById('answer-input')[:value]
            @quiz.answer!(input_answer)
            update_score!
            log_text = "#{@quiz.is_corrected ? '✅' : '❌'} #{input_answer}"

            document.createElement('li').tap do |li|
                li[:innerText] = log_text
                document.getElementById('answer-log').prepend(li)
            end
        end
    end

    def set_ruby_version
        document.getElementById('ruby-version')[:innerText] = "RUBY_VERSION: #{RUBY_VERSION}"
    end
end

quiz = Quiz.new
quiz_view = QuizView.new(quiz)
