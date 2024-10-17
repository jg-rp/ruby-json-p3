# frozen_string_literal: true

require_relative "function"

module JSONPathRFC9535
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
    attr_reader :expression

    def initialize(token, expression)
      super(token)
      @expression = expression
    end

    def evaluate(context)
      JSONPathRFC9535.truthy?(@expression.evaluate(context))
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
    attr_reader :value

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
    attr_reader :expression

    def initialize(token, expression)
      super(token)
      @expression = expression
    end

    def evaluate(context)
      !JSONPathRFC9535.truthy?(@expression.evaluate(context))
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
    attr_reader :left, :right

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
      JSONPathRFC9535.truthy?(@left.evaluate(context)) && JSONPathRFC9535.truthy?(@right.evaluate(context))
    end

    def to_s
      "#{@left} && #{@right}"
    end
  end

  # A logical `||` expression.
  class LogicalOrExpression < InfixExpression
    def evaluate(context)
      JSONPathRFC9535.truthy?(@left.evaluate(context)) || JSONPathRFC9535.truthy?(@right.evaluate(context))
    end

    def to_s
      "#{@left} || #{@right}"
    end
  end

  # An `==` expression.
  class EqExpression < InfixExpression
    def evaluate(context)
      JSONPathRFC9535.eq?(@left.evaluate(context), @right.evaluate(context))
    end

    def to_s
      "#{@left} == #{@right}"
    end
  end

  # A `!=` expression.
  class NeExpression < InfixExpression
    def evaluate(context)
      !JSONPathRFC9535.eq?(@left.evaluate(context), @right.evaluate(context))
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
      JSONPathRFC9535.eq?(left, right) || JSONPathRFC9535.lt?(left, right)
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
      JSONPathRFC9535.eq?(left, right) || JSONPathRFC9535.lt?(right, left)
    end

    def to_s
      "#{@left} >= #{@right}"
    end
  end

  # A `<` expression.
  class LtExpression < InfixExpression
    def evaluate(context)
      JSONPathRFC9535.lt?(@left.evaluate(context), @right.evaluate(context))
    end

    def to_s
      "#{@left} < #{@right}"
    end
  end

  # A `>` expression.
  class GtExpression < InfixExpression
    def evaluate(context)
      JSONPathRFC9535.lt?(@right.evaluate(context), @left.evaluate(context))
    end

    def to_s
      "#{@left} > #{@right}"
    end
  end

  # Base class for all embedded filter queries
  class QueryExpression < Expression
    attr_reader :query

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
  class RelativeQueryExpression < QueryExpression
    def evaluate(context)
      unless context.current.is_a?(Array) || context.current.is_a?(Hash)
        return @query.empty? ? context.current : JSONPathNodeList.new
      end

      @query.find(context.current)
    end

    def to_s
      "@#{@query.to_s[1..]}"
    end
  end

  # An embedded query starting at the root node.
  class RootQueryExpression < QueryExpression
    def evaluate(context)
      @query.find(context.root)
    end

    def to_s
      @query.to_s
    end
  end

  # A filter function call.
  class FunctionExpression < Expression
    attr_reader :name, :args

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
      unpacked_args = unpack_node_lists(func, args)
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

    private

    # @param func [Proc]
    # @param args [Array<Object>]
    # @return [Array<Object>]
    def unpack_node_lists(func, args) # rubocop:disable Metrics/MethodLength
      unpacked_args = []
      args.each_with_index do |arg, i|
        unless arg.is_a?(JSONPathNodeList) && func.class::ARG_TYPES[i] != ExpressionType::NODES
          unpacked_args << arg
          next
        end

        unpacked_args << case arg.length
                         when 0
                           :nothing
                         when 1
                           arg.first.value
                         else
                           arg
                         end
      end
      unpacked_args
    end
  end

  def self.truthy?(obj)
    return !obj.empty? if obj.is_a?(JSONPathNodeList)
    return false if obj == :nothing

    obj == true
  end

  def self.eq?(left, right) # rubocop:disable Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/AbcSize
    left = left.first.value if left.is_a?(JSONPathNodeList) && left.length == 1
    right = right.first.value if right.is_a?(JSONPathNodeList) && right.length == 1

    right, left = left, right if right.is_a?(JSONPathNodeList)

    if left.is_a? JSONPathNodeList
      return left == right if right.is_a? JSONPathNodeList
      return right == :nothing if left.empty?
      return left.first == right if left.length == 1

      return false
    end

    return true if left == :nothing && right == :nothing

    left == right
  end

  def self.lt?(left, right) # rubocop:disable Metrics/CyclomaticComplexity, Metrics/AbcSize, Metrics/PerceivedComplexity
    left = left.first.value if left.is_a?(JSONPathNodeList) && left.length == 1
    right = right.first.value if right.is_a?(JSONPathNodeList) && right.length == 1
    return left < right if left.is_a?(String) && right.is_a?(String)
    return left < right if (left.is_a?(Integer) || left.is_a?(Float)) &&
                           (right.is_a?(Integer) || right.is_a?(Float))

    false
  end

  # Contextural information and data used for evaluating a filter expression.
  class FilterContext
    attr_reader :env, :current, :root

    def initialize(env, current, root)
      @env = env
      @current = current
      @root = root
    end
  end
end
