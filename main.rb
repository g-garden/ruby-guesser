require "js"

class Quiz
    attr_reader :hints, :is_corrected, :answer_log, :point

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
        @point -= hint[:cost]
    end

    private

    def generate_answer
        klasses = [String, Array]
        klass = klasses.sample
        methods = klass.instance_methods
        method = methods.sample
        puts method # Debug
        { klass: klass, method: method.to_s }
    end

    def generate_hints
        [
            { cost: 200, desc: '#class', content: @answer[:klass] },
            { cost: 300, desc: '#owner', content: @answer[:klass].new.method(@answer[:method]).owner },
            { cost: 100, desc: '#arity', content: @answer[:klass].new.method(@answer[:method]).arity },
            { cost: 200, desc: '#parameters', content: @answer[:klass].new.method(@answer[:method]).parameters },
            { cost: 100, desc: '#length', content: @answer[:method].length },
            { cost: 200, desc: '#chars.first', content: @answer[:method].chars.first },
            { cost: 300, desc: '#chars.last', content: @answer[:method].chars.last },
            { cost: 200, desc: '#chars.count(\'_\')', content: @answer[:method].chars.count('_') },
            { cost: 500, desc: '#chars.shuffle', content: @answer[:method].chars.shuffle },
            { cost: 800, desc: 'underbar_position', content: @answer[:method].gsub(/[^_]/, '○') },
        ]
    end

    def is_correct?(input_answer)
        input_answer.to_s == @answer[:method]
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
                    button[:innerText] = "#{hint[:desc]} <#{hint[:cost]}>"
                    button.addEventListener('click') do
                        @quiz.hint!(hint)
                        update_score!
                        document.createElement('p').tap do |p|
                            p[:className] = 'hint-text'
                            p[:innerText] = hint[:content].to_s
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
