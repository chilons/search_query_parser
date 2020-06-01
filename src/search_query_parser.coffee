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

  @parse: (input) ->
    tree = Parser.parse(input.trim())
    if tree.children.length < 1
      throw new Error("Couldn't parse search query!")
    return @transform(tree)

  @transform: (node) =>
    if node.error
      throw new Error(node.message())
    return switch node.name
      when "#document"
        @transform(node.children[0])
      when "start"
        if (node.children.length > 1) then @transform(node.children[0]) else []
      when "Query"
        elems = node.children.filter((c) => c.name != "Whitespace").reverse()
        current = @transform(elems.pop())
        loop
          next = elems.pop()
          break if !next
          if next.name == "Connective"
            op = if (next.innerText() == "AND") then "and" else "or"
            b = elems.pop()
          else
            op = "and"
            b = next
          current = [op, current, @transform(b)]
        current
      when "Term"
        [c0, c1] = node.children
        if c0.name == "MatchMode"
          if (c0.innerText() == "-" || c0.innerText() == "NOT") then ["not", @transform(c1)] else @transform(c1)
        else
          @transform(c0)
      when "Subquery"
        @transform(node.children[1])
      when "Keyword"
        ["search", @transform(node.children[0])]
      when "Pair"
        [field, sep, operator, attr] = node.children
        opToken = null
        if !attr
          attr = operator
          opToken = "equals"
        else
          opToken = @OPERATOR_TO_TOKEN[operator.innerText()]
        ["attr", [@transform(field), opToken, @transform(attr)]]
      when "Attribute"
        @transform(node.children[0])
      when "AnyValue"
        @transform(node.children[0])
      when "BareWord"
        node.innerText()
      when "String"
        @transform(node.children[0])
      when "SingleQuotedString", "DoubleQuotedString"
        # Lop off quotes from the quoted strings
        word = node.innerText().slice(1, -1)
        word
      when "Numeric"
        @transform(node.children[0])
      when "Integer"
        parseInt(node.innerText(), 10)
      when "Float"
        parseFloat(node.innerText())
      when "QuotedString"
        @transform(node.children[0])
      when "Date"
        new Date(@transform(node.children[1]))
      when undefined
        node
      else
        node.name

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
