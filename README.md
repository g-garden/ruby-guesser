# RubyGuesser

https://g-garden.github.io/ruby-guesser/
This was created for fun during the New Year's holiday.

## Motivation

- I want to make a quick game to play with my colleagues.
- I want to play on https://github.com/ruby/ruby.wasm

## Development policy

- Keep it simple except for ruby.wasm
- Make it easy to deploy. Use GithubPages
- Make it easy to develop. Use GithubCodeSpaces

## Updating Method Descriptions

Method descriptions are extracted from Ruby's `ri` documentation tool. To update the descriptions:

```bash
# Generate method descriptions from ri documentation
ruby generate_descriptions.rb > method_descriptions_generated.rb

# Review the generated descriptions
# Then update main.rb with the new descriptions
```

The `generate_descriptions.rb` script automatically extracts descriptions for all methods in the supported classes (Array, String, Hash, etc.) from Ruby's built-in documentation.

**Note:** The generated descriptions are in English (from ri). You may want to translate them to Japanese or customize them for better gameplay experience.
