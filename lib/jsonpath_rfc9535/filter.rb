# frozen_string_literal: true

module JsonpathRfc9535
  # Base class for all filter expression nodes.
  class Expression
    # @dynamic token
    attr_reader :token

    def initialize(token)
      @token = token
    end

    # Evaluate the filter expressin in the given context.
    def evaluate(_context)
      raise "filter expressions must implement `evaluate(context)`"
    end
  end

  # An expression that evaluates to true or false.
  class FilterExpression < Expression
    def initialize(token, expression)
      super(token)
      @expression = expression
    end

    def evaluate(context)
      is_truthy(@expression.evaluate(context))
    end

    def to_s
      @expression.to_s
    end

    def ==(other)
      self.class == other.class &&
        @expression == other.expression &&
        @token == other.token
    end

    alias eql? ==

    def hash
      @expression.hash ^ @token.hash
    end
  end

  # Base class for expression literals.
  class FilterExpressionLiteral < Expression
    def initialize(token, value)
      super(token)
      @value = value
    end

    def evaluate(_context)
      @value
    end

    def to_s
      @value.to_s
    end

    def ==(other)
      self.class == other.class &&
        @value == other.value &&
        @token == other.token
    end

    alias eql? ==

    def hash
      @value.hash ^ @token.hash
    end
  end

  # Literal true or false.
  class BooleanLiteral < FilterExpressionLiteral; end

  # A double or single quoted string literal.
  class StringLiteral < FilterExpressionLiteral
    def to_s
      # TODO: escape double quotes?
      "\"#{@value}\""
    end
  end

  # A literal integer.
  class IntegerLiteral < FilterExpressionLiteral; end

  # A literal float
  class FloatLiteral < FilterExpressionLiteral; end

  # A literal null
  class NullLiteral < FilterExpressionLiteral
    def to_s
      "null"
    end
  end

  # An expression prefixed with the logical not operator.
  class LogicalNotExpression < Expression
    def initialize(token, expression)
      super(token)
      @expression = expression
    end

    def evaluate(_context)
      !is_truthy(@expression.evaluate(context))
    end

    def to_s
      "!#{@expreession}"
    end

    def ==(other)
      self.class == other.class &&
        @expression == other.expression &&
        @token == other.token
    end

    alias eql? ==

    def hash
      @expression.hash ^ @token.hash
    end
  end

  # Base class for expression with a left expression, operator and right expression.
  class InfixExpression < Expression
    def initialize(token, left, right)
      super(token)
      @left = left
      @right = right
    end

    def evaluate(_context)
      raise "infix expressions must implement `evaluate(context)`"
    end

    def to_s
      raise "infix expressions must impleent `to_s`"
    end

    def ==(other)
      self.class == other.class &&
        @left == other.left &&
        @right == other.right &&
        @token == other.token
    end

    alias eql? ==

    def hash
      @left.hash ^ @right.hash ^ @token.hash
    end
  end

  # A logical `&&` expression.
  class LogicalAndExpression < InfixExpression
    def evaluate(context)
      is_truthy(@left.evaluate(context)) && is_truthy(@right.evaluate(context))
    end

    def to_s
      "#{@left} && #{@right}"
    end
  end

  # A logical `||` expression.
  class LogicalOrExpression < InfixExpression
    def evaluate(context)
      is_truthy(@left.evaluate(context)) || is_truthy(@right.evaluate(context))
    end

    def to_s
      "#{@left} || #{@right}"
    end
  end

  # An `==` expression.
  class EqExpression < InfixExpression
    def evaluate(context)
      eq?(@left.evaluate(context), @right.evaluate(context))
    end

    def to_s
      "#{@left} == #{@right}"
    end
  end

  # A `!=` expression.
  class NeExpression < InfixExpression
    def evaluate(context)
      !eq?(@left.evaluate(context), @right.evaluate(context))
    end

    def to_s
      "#{@left} != #{@right}"
    end
  end

  # A `<=` expression.
  class LeExpression < InfixExpression
    def evaluate(context)
      left = @left.evaluate(context)
      right = @right.evaluate(context)
      eq?(left, right) || lt?(left, right)
    end

    def to_s
      "#{@left} <= #{@right}"
    end
  end

  # A `>=` expression.
  class GeExpression < InfixExpression
    def evaluate(context)
      left = @left.evaluate(context)
      right = @right.evaluate(context)
      eq?(left, right) || lt?(right, left)
    end

    def to_s
      "#{@left} >= #{@right}"
    end
  end

  # A `<` expression.
  class LtExpression < InfixExpression
    def evaluate(context)
      lt?(@left.evaluate(context), @right.evaluate(context))
    end

    def to_s
      "#{@left} < #{@right}"
    end
  end

  # A `>` expression.
  class GtExpression < InfixExpression
    def evaluate(context)
      lt?(@right.evaluate(context), @left.evaluate(context))
    end

    def to_s
      "#{@left} > #{@right}"
    end
  end

  # Base class for all embedded filter queries
  class QueryExpression < Expression
    def initialize(token, query)
      super(token)
      @query = query
    end

    def evaluate(_context)
      raise "query expressions must implement `evaluate(context)`"
    end

    def to_s
      raise "query expressions must impleent `to_s`"
    end

    def ==(other)
      self.class == other.class &&
        @query == other.query &&
        @token == other.token
    end

    alias eql? ==

    def hash
      @query.hash ^ @token.hash
    end
  end

  # An embedded query starting at the current node.
  class RelativeQueryExpression < Expression
    def evaluate(context)
      unless context.current.is_a?(Array) || context.current.is_a?(Hash)
        return @query.empty? ? context.current : []
      end

      @query.find(context.current)
    end
  end

  # An embedded query starting at the root node.
  class RootQueryExpression < Expression
    def evaluate(context)
      @query.find(context.root)
    end
  end

  # A filter function call.
  class FunctionExpression < Expression
    # @param name [String]
    # @param args [Array<Expression>]
    def initialize(token, name, args)
      super(token)
      @name = name
      @args = args
    end

    def evaluate(context)
      func = context.env.function_extensions.fetch(@name)
      args = @args.map { |arg| arg.evaluate(context) }
      unpacked_args = unpack_node_lists(args)
      func.call(*unpacked_args)
    rescue KeyError
      :nothing
    end

    def to_s
      args = @args.map(&:to_s).join(", ")
      "#{@name}(#{args})"
    end

    def ==(other)
      self.class == other.class &&
        @name == other.name &&
        @args == other.args &&
        @token == other.token
    end

    alias eql? ==

    def hash
      @name.hash ^ @args.hash ^ @token.hash
    end
  end

  # TODO: private module function (without a class)
  # TODO: is_truthy -> truthy?
  # TODO: eq?
  # TODO: lt?
  # TODO: unpack_node_lists()
  # TODO: FilterContext
end
