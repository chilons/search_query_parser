Parser = require './basic_parser'

class SearchQueryParser

  @TOKEN_TO_OPERATOR:
    less_than: '<'
    less_than_or_equals: '<='
    greater_than: '>'
    greater_than_or_equals: '>='
    equals: ''
    not_equals: ''

  @OPERATOR_TO_TOKEN: {}

  for token, operator of @TOKEN_TO_OPERATOR
    @OPERATOR_TO_TOKEN[operator] = token

  @NOT_TOKEN:
    greater_than: 'less_than'
    less_than: 'greater_than'
    equals: 'not_equals'
    not_equals: 'equals'
    greater_than_or_equals: 'less_than_or_equals'
    less_than_or_equals: 'greater_than_or_equals'

  @tokenize: (input) ->
    tree = Parser.parse(input)

    results = []
    word = positiveMatch = key = operator = undefined

    if tree.children.length < 1
      throw new Error("Couldn't parse search query!")

    tree.traverse
      traversesTextNodes: false
      enteredNode: (node) =>
        if node.error
          throw new Error(node.message())
        return switch node.name
          when "Definition"
            positiveMatch = true
            key = 'default'
            operator = 'equals'
            true
          when "MatchMode"
            positiveMatch = node.innerText() == '+'
            true
          when "Integer"
            word = parseInt(node.innerText(), 10)
            false
          when "Float"
            word = parseFloat(node.innerText())
            false
          when "Date"
            innerText = node.innerText().split('-').map (val) ->
              parseInt(val, 10)
            word = new Date innerText[0], innerText[1] - 1, innerText[2]
            false
          when "String"
            if node.children[0].name == 'BareWord'
              word = node.innerText()
            else
              # Lop off quotes from the quoted strings
              word = node.innerText().slice(1, -1)
              word = word.trim()
            false
          when "Operator"
            operator = @OPERATOR_TO_TOKEN[node.innerText()]
            false
          else
            true

      exitedNode: (node) =>
        switch node.name
          when "Pair"
            key = node.children[0].innerText()
          when "Definition"
            operator = @NOT_TOKEN[operator] if !positiveMatch
            results.push [key, operator, word]

    results

  @build: (tokens) ->
    results = for [key, operator, value] in tokens
      component = "#{@TOKEN_TO_OPERATOR[operator]}#{@format(value)}"

      unless key is 'default'
        component = "#{key}:#{component}"

      if operator == 'not_equals'
        component = "-#{component}"
      component

    results.join ' '

  pad = (val) ->
    val = "#{val}"
    if val.length == 1
      val = "0#{val}"
    val

  @format: (value) ->
    if value instanceof Date
      return "#{value.getUTCFullYear()}-#{pad value.getUTCMonth()+1}-#{pad value.getUTCDate()}"

    if value.indexOf? && value.indexOf(' ') != -1
      startChar = value.slice(0, 1)
      endChar = value.slice(-1)
      if startChar == endChar && startChar in ['"', "'"]
        coreValue = value.slice(1, -1)
        startChar + coreValue.replace(/#{startChar}/, "\\" + startChar) + startChar
      else
        '"' + value.replace(/"/g, '\"') + '"'
    else
      value
module.exports = SearchQueryParser
