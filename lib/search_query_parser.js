(function() {
  var Parser, SearchQueryParser;

  Parser = require('./basic_parser');

  SearchQueryParser = (function() {
    var operator, pad, token, _ref;

    function SearchQueryParser() {}

    SearchQueryParser.TOKEN_TO_OPERATOR = {
      less_than: '<',
      less_than_or_equals: '<=',
      greater_than: '>',
      greater_than_or_equals: '>=',
      equals: '',
      not_equals: ''
    };

    SearchQueryParser.OPERATOR_TO_TOKEN = {};

    _ref = SearchQueryParser.TOKEN_TO_OPERATOR;
    for (token in _ref) {
      operator = _ref[token];
      SearchQueryParser.OPERATOR_TO_TOKEN[operator] = token;
    }

    SearchQueryParser.NOT_TOKEN = {
      greater_than: 'less_than',
      less_than: 'greater_than',
      equals: 'not_equals',
      not_equals: 'equals',
      greater_than_or_equals: 'less_than_or_equals',
      less_than_or_equals: 'greater_than_or_equals'
    };

    SearchQueryParser.parse = function(input) {
      var tree;
      tree = Parser.parse(input.trim());
      if (tree.children.length < 1) {
        throw new Error("Couldn't parse search query!");
      }
      return this.transform(tree);
    };

    SearchQueryParser.transform = function(node) {
      var attr, b, c0, c1, current, elems, field, next, op, opToken, sep, word, _ref1, _ref2;
      if (node.error) {
        throw new Error(node.message());
      }
      switch (node.name) {
        case "#document":
          return SearchQueryParser.transform(node.children[0]);
        case "start":
          if (node.children.length > 1) {
            return SearchQueryParser.transform(node.children[0]);
          } else {
            return [];
          }
          break;
        case "Query":
          elems = node.children.filter(function(c) {
            return c.name !== "Whitespace";
          }).reverse();
          current = SearchQueryParser.transform(elems.pop());
          while (true) {
            next = elems.pop();
            if (!next) {
              break;
            }
            if (next.name === "Connective") {
              op = next.innerText() === "AND" ? "and" : "or";
              b = elems.pop();
            } else {
              op = "and";
              b = next;
            }
            current = [op, current, SearchQueryParser.transform(b)];
          }
          return current;
        case "Term":
          _ref1 = node.children, c0 = _ref1[0], c1 = _ref1[1];
          if (c0.name === "MatchMode") {
            if (c0.innerText() === "-" || c0.innerText() === "NOT") {
              return ["not", SearchQueryParser.transform(c1)];
            } else {
              return SearchQueryParser.transform(c1);
            }
          } else {
            return SearchQueryParser.transform(c0);
          }
          break;
        case "Subquery":
          return SearchQueryParser.transform(node.children[1]);
        case "Keyword":
          return ["search", SearchQueryParser.transform(node.children[0])];
        case "Pair":
          _ref2 = node.children, field = _ref2[0], sep = _ref2[1], operator = _ref2[2], attr = _ref2[3];
          opToken = null;
          if (!attr) {
            attr = operator;
            opToken = "equals";
          } else {
            opToken = SearchQueryParser.OPERATOR_TO_TOKEN[operator.innerText()];
          }
          return ["attr", [SearchQueryParser.transform(field), opToken, SearchQueryParser.transform(attr)]];
        case "Attribute":
          return SearchQueryParser.transform(node.children[0]);
        case "AnyValue":
          return SearchQueryParser.transform(node.children[0]);
        case "BareWord":
          return node.innerText();
        case "String":
          return SearchQueryParser.transform(node.children[0]);
        case "SingleQuotedString":
        case "DoubleQuotedString":
          word = node.innerText().slice(1, -1);
          return word.trim();
        case "Numeric":
          return SearchQueryParser.transform(node.children[0]);
        case "Integer":
          return parseInt(node.innerText(), 10);
        case "Float":
          return parseFloat(node.innerText());
        case "QuotedString":
          return SearchQueryParser.transform(node.children[0]);
        case "Date":
          return new Date(SearchQueryParser.transform(node.children[1]));
        case void 0:
          return node;
        default:
          return node.name;
      }
    };

    SearchQueryParser.build = function(tokens) {
      var component, key, results, value;
      results = (function() {
        var _i, _len, _ref1, _results;
        _results = [];
        for (_i = 0, _len = tokens.length; _i < _len; _i++) {
          _ref1 = tokens[_i], key = _ref1[0], operator = _ref1[1], value = _ref1[2];
          component = "" + this.TOKEN_TO_OPERATOR[operator] + (this.format(value));
          if (key !== 'default') {
            component = "" + key + ":" + component;
          }
          if (operator === 'not_equals') {
            component = "-" + component;
          }
          _results.push(component);
        }
        return _results;
      }).call(this);
      return results.join(' ');
    };

    pad = function(val) {
      val = "" + val;
      if (val.length === 1) {
        val = "0" + val;
      }
      return val;
    };

    SearchQueryParser.format = function(value) {
      var coreValue, endChar, startChar;
      if (value instanceof Date) {
        return "" + (value.getUTCFullYear()) + "-" + (pad(value.getUTCMonth() + 1)) + "-" + (pad(value.getUTCDate()));
      }
      if ((value.indexOf != null) && value.indexOf(' ') !== -1) {
        startChar = value.slice(0, 1);
        endChar = value.slice(-1);
        if (startChar === endChar && (startChar === '"' || startChar === "'")) {
          coreValue = value.slice(1, -1);
          return startChar + coreValue.replace(/#{startChar}/, "\\" + startChar) + startChar;
        } else {
          return '"' + value.replace(/"/g, '\"') + '"';
        }
      } else {
        return value;
      }
    };

    return SearchQueryParser;

  }).call(this);

  module.exports = SearchQueryParser;

}).call(this);
