require "js"

class Quiz
    attr_reader :hints, :is_corrected, :answer_log
    def initialize
        @answer = generate_answer
        @hints = generate_hints
        @answer_log = []
    end

    def answer!(answer_text)
        @is_corrected ||= is_correct?(answer_text) # 一度正解したら、正解フラグを立てる
        @answer_log << answer_text
    end

    private

    def generate_answer
        klasses = [String, Array]
        klass = klasses.sample
        methods = klass.methods
        method = methods.sample
        puts method # Debug
        {klass: klass, method: method.to_s}
    end

    def generate_hints
        [
            { desc: '#class', content: @answer[:klass] },
            { desc: '#arity', content: @answer[:klass].method(@answer[:method]).arity },
            { desc: '#owner', content: @answer[:klass].method(@answer[:method]).owner },
            { desc: '#parameters', content: @answer[:klass].method(@answer[:method]).parameters },
            { desc: '#length', content: @answer[:method].length },
            { desc: '[0]', content: @answer[:method][0] },
            { desc: '[-1]', content: @answer[:method][-1] },
            { desc: 'underbar_count', content: @answer[:method].chars.count('_') },
            { desc: 'underbar_position', content: @answer[:method].gsub(/[^_]/, '○') },
        ]
    end

    def is_correct?(input_answer)
        input_answer.to_s == @answer[:method]
    end
end

quiz = Quiz.new
document = JS.global['document']

hints_container = document.getElementById('hints-container')
quiz.hints.each do |hint|
    document.createElement('div').tap do |div|
        div[:className] = 'hint'
        document.createElement('button').tap do |button|
            button[:className] = 'hint-button'
            button[:innerText] = hint[:desc].to_s
            button.addEventListener('click') do
                document.createElement('p').tap do |p|
                    p[:className] = 'hint-text'
                    p[:innerText] = hint[:content].to_s
                    div.appendChild(p)
                end
            end
            div.appendChild(button)
        end
        hints_container.appendChild(div)
    end
end

document.getElementById('answer-button').addEventListener('click') do
    input_answer = document.getElementById('answer-input')[:value]
    quiz.answer!(input_answer)
    log_text = "#{quiz.is_corrected ? '✅' : '❌'} #{input_answer}"

    document.createElement('li').tap do |li|
        li[:innerText] = log_text
        document.getElementById('answer-log').prepend(li)
    end
end
