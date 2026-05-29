# =============================================================================
# parser.rb — Analizador Sintáctico (Parser)
#
# FIXES APLICADOS:
#   VULN-06: parse_block_statement reporta error cuando falta '}'
#   VULN-16: parse_call_arguments da un solo error claro al faltar ')'
#   VULN-17: Guards contra nil en peek_token / current_token
#   VULN-20: Los mensajes de error incluyen número de línea
# =============================================================================

require_relative 'tokens'
require_relative 'lexer'
require_relative 'ast'

module Precedences
  LOWEST      = 1
  OR          = 2
  AND         = 3
  EQUALS      = 4
  LESSGREATER = 5
  SUM         = 6
  PRODUCT     = 7
  PREFIX      = 8
  POWER       = 9
  CALL        = 10
end

PRECEDENCES_TABLE = {
  TokenType::OR       => Precedences::OR,
  TokenType::AND      => Precedences::AND,
  TokenType::EQ       => Precedences::EQUALS,
  TokenType::DIF      => Precedences::EQUALS,
  TokenType::LT       => Precedences::LESSGREATER,
  TokenType::LTE      => Precedences::LESSGREATER,
  TokenType::GT       => Precedences::LESSGREATER,
  TokenType::GTE      => Precedences::LESSGREATER,
  TokenType::PLUS     => Precedences::SUM,
  TokenType::MINUS    => Precedences::SUM,
  TokenType::MULTIPLY => Precedences::PRODUCT,
  TokenType::DIVISION => Precedences::PRODUCT,
  TokenType::MOD      => Precedences::PRODUCT,
  TokenType::POW      => Precedences::POWER,
  TokenType::LPAREN   => Precedences::CALL,
}


class Parser
  attr_reader :errors

  def initialize(lexer)
    @lexer  = lexer
    @errors = []
    @current_token = nil
    @peek_token    = nil

    @prefix_parse_fns = {
      TokenType::IDENTIFIER => method(:parse_identifier),
      TokenType::INTEGER    => method(:parse_integer_literal),
      TokenType::FLOAT      => method(:parse_float_literal),
      TokenType::STRING     => method(:parse_string_literal),
      TokenType::TRUE       => method(:parse_boolean_literal),
      TokenType::FALSE      => method(:parse_boolean_literal),
      TokenType::MINUS      => method(:parse_prefix_expression),
      TokenType::NEGATION   => method(:parse_prefix_expression),
      TokenType::LPAREN     => method(:parse_grouped_expression),
      TokenType::IF         => method(:parse_if_expression),
      TokenType::FUNCTION   => method(:parse_function_literal),
    }

    @infix_parse_fns = {
      TokenType::PLUS     => method(:parse_infix_expression),
      TokenType::MINUS    => method(:parse_infix_expression),
      TokenType::MULTIPLY => method(:parse_infix_expression),
      TokenType::DIVISION => method(:parse_infix_expression),
      TokenType::MOD      => method(:parse_infix_expression),
      TokenType::POW      => method(:parse_infix_expression),
      TokenType::EQ       => method(:parse_infix_expression),
      TokenType::DIF      => method(:parse_infix_expression),
      TokenType::LT       => method(:parse_infix_expression),
      TokenType::LTE      => method(:parse_infix_expression),
      TokenType::GT       => method(:parse_infix_expression),
      TokenType::GTE      => method(:parse_infix_expression),
      TokenType::AND      => method(:parse_infix_expression),
      TokenType::OR       => method(:parse_infix_expression),
      TokenType::LPAREN   => method(:parse_call_expression),
    }

    advance_tokens
    advance_tokens
  end

  def parse_program
    program = Program.new

    # [FIX VULN-17] guard contra current_token nil
    while @current_token && @current_token.token_type != TokenType::EOF
      statement = parse_statement
      program.statements << statement if statement
      advance_tokens
    end

    program
  end

  private

  def parse_statement
    # [FIX VULN-17] guard contra current_token nil
    return nil if @current_token.nil?

    case @current_token.token_type
    when TokenType::LET      then parse_let_statement
    when TokenType::RETURN   then parse_return_statement
    when TokenType::PRINT    then parse_print_statement
    when TokenType::WHILE    then parse_while_statement
    when TokenType::FOR      then parse_for_statement
    when TokenType::BREAK    then parse_break_statement
    when TokenType::CONTINUE then parse_continue_statement
    else                          parse_expression_statement
    end
  end

  def parse_let_statement
    token = @current_token
    return nil unless expected_token(TokenType::IDENTIFIER)
    name = Identifier.new(@current_token, @current_token.literal)
    return nil unless expected_token(TokenType::ASSIGN)
    advance_tokens
    value = parse_expression(Precedences::LOWEST)
    value.name = name.value if value.is_a?(FunctionLiteral)
    advance_tokens if peek_token_is(TokenType::SEMICOLON)
    LetStatement.new(token, name, value)
  end

  def parse_return_statement
    token = @current_token
    advance_tokens
    return_value = parse_expression(Precedences::LOWEST)
    advance_tokens if peek_token_is(TokenType::SEMICOLON)
    ReturnStatement.new(token, return_value)
  end

  def parse_print_statement
    token = @current_token
    return nil unless expected_token(TokenType::LPAREN)
    advance_tokens
    value = parse_expression(Precedences::LOWEST)
    return nil unless expected_token(TokenType::RPAREN)
    advance_tokens if peek_token_is(TokenType::SEMICOLON)
    PrintStatement.new(token, value)
  end

  def parse_while_statement
    token = @current_token
    return nil unless expected_token(TokenType::LPAREN)
    advance_tokens
    condition = parse_expression(Precedences::LOWEST)
    return nil unless expected_token(TokenType::RPAREN)
    return nil unless expected_token(TokenType::LBRACE)
    body = parse_block_statement
    WhileStatement.new(token, condition, body)
  end

  def parse_for_statement
    token = @current_token
    return nil unless expected_token(TokenType::LPAREN)

    advance_tokens
    init = nil
    unless current_token_is(TokenType::SEMICOLON)
      init = parse_statement
    end
    unless current_token_is(TokenType::SEMICOLON)
      return nil unless expected_token(TokenType::SEMICOLON)
    end

    advance_tokens
    condition = nil
    unless current_token_is(TokenType::SEMICOLON)
      condition = parse_expression(Precedences::LOWEST)
    end
    return nil unless expected_token(TokenType::SEMICOLON)

    advance_tokens
    update = nil
    unless current_token_is(TokenType::RPAREN)
      update = parse_statement
    end
    unless current_token_is(TokenType::RPAREN)
      return nil unless expected_token(TokenType::RPAREN)
    end

    return nil unless expected_token(TokenType::LBRACE)
    body = parse_block_statement
    ForStatement.new(token, init, condition, update, body)
  end

  def parse_break_statement
    token = @current_token
    advance_tokens if peek_token_is(TokenType::SEMICOLON)
    BreakStatement.new(token)
  end

  def parse_continue_statement
    token = @current_token
    advance_tokens if peek_token_is(TokenType::SEMICOLON)
    ContinueStatement.new(token)
  end

  def parse_expression_statement
    token      = @current_token
    expression = parse_expression(Precedences::LOWEST)
    advance_tokens if peek_token_is(TokenType::SEMICOLON)
    ExpressionStatement.new(token, expression)
  end

  # [FIX VULN-06] Ahora reporta error si el bloque no tiene '}'
  def parse_block_statement
    open_token = @current_token   # guarda el '{' para el mensaje de error
    block      = BlockStatement.new(@current_token)
    advance_tokens

    while !current_token_is(TokenType::RBRACE) && !current_token_is(TokenType::EOF)
      statement = parse_statement
      block.statements << statement if statement
      advance_tokens
    end

    # [FIX VULN-06] Si terminamos en EOF sin encontrar '}', es un error
    if current_token_is(TokenType::EOF)
      line_info = open_token.line ? " (abierto en línea #{open_token.line})" : ''
      @errors << "Bloque sin cerrar: falta '}' al final del bloque#{line_info}"
    end

    block
  end

  def parse_expression(precedence)
    # [FIX VULN-17] guard contra current_token nil
    return nil if @current_token.nil?

    prefix_fn = @prefix_parse_fns[@current_token.token_type]

    if prefix_fn.nil?
      line_info = @current_token.line ? " en línea #{@current_token.line}" : ''
      @errors << "Token inesperado '#{@current_token.literal}'#{line_info}"
      return nil
    end

    left_expression = prefix_fn.call

    while @peek_token &&
          !peek_token_is(TokenType::SEMICOLON) &&
          precedence < peek_precedence
      infix_fn = @infix_parse_fns[@peek_token.token_type]
      return left_expression if infix_fn.nil?
      advance_tokens
      left_expression = infix_fn.call(left_expression)
    end

    left_expression
  end

  # ── Funciones PREFIX ────────────────────────────────────────────────────
  def parse_identifier
    Identifier.new(@current_token, @current_token.literal)
  end

  def parse_integer_literal
    value = Integer(@current_token.literal) rescue nil
    if value.nil?
      @errors << "No se pudo parsear \"#{@current_token.literal}\" como entero"
      return nil
    end
    IntegerLiteral.new(@current_token, value)
  end

  def parse_float_literal
    value = Float(@current_token.literal) rescue nil
    if value.nil?
      @errors << "No se pudo parsear \"#{@current_token.literal}\" como flotante"
      return nil
    end
    FloatLiteral.new(@current_token, value)
  end

  def parse_string_literal
    StringLiteral.new(@current_token, @current_token.literal)
  end

  def parse_boolean_literal
    BooleanLiteral.new(@current_token, @current_token.token_type == TokenType::TRUE)
  end

  def parse_prefix_expression
    token    = @current_token
    operator = @current_token.literal
    advance_tokens
    right = parse_expression(Precedences::PREFIX)
    PrefixExpression.new(token, operator, right)
  end

  def parse_grouped_expression
    advance_tokens
    expression = parse_expression(Precedences::LOWEST)
    return nil unless expected_token(TokenType::RPAREN)
    expression
  end

  def parse_if_expression
    token = @current_token
    return nil unless expected_token(TokenType::LPAREN)
    advance_tokens
    condition = parse_expression(Precedences::LOWEST)
    return nil unless expected_token(TokenType::RPAREN)
    return nil unless expected_token(TokenType::LBRACE)
    consequence = parse_block_statement

    alternatives = []
    while peek_token_is(TokenType::ELSEIF)
      advance_tokens
      return nil unless expected_token(TokenType::LPAREN)
      advance_tokens
      alt_condition = parse_expression(Precedences::LOWEST)
      return nil unless expected_token(TokenType::RPAREN)
      return nil unless expected_token(TokenType::LBRACE)
      alt_block = parse_block_statement
      alternatives << [alt_condition, alt_block]
    end

    else_block = nil
    if peek_token_is(TokenType::ELSE)
      advance_tokens
      return nil unless expected_token(TokenType::LBRACE)
      else_block = parse_block_statement
    end

    IfExpression.new(token, condition, consequence, alternatives, else_block)
  end

  def parse_function_literal
    token = @current_token
    return nil unless expected_token(TokenType::LPAREN)
    parameters = parse_function_parameters
    return nil unless expected_token(TokenType::LBRACE)
    body = parse_block_statement
    FunctionLiteral.new(token, parameters, body)
  end

  def parse_function_parameters
    parameters = []
    if peek_token_is(TokenType::RPAREN)
      advance_tokens
      return parameters
    end
    advance_tokens
    parameters << Identifier.new(@current_token, @current_token.literal)
    while peek_token_is(TokenType::COMMA)
      advance_tokens
      advance_tokens
      parameters << Identifier.new(@current_token, @current_token.literal)
    end
    unless expected_token(TokenType::RPAREN)
      return []
    end
    parameters
  end

  # ── Funciones INFIX ─────────────────────────────────────────────────────
  def parse_infix_expression(left)
    token      = @current_token
    operator   = @current_token.literal
    precedence = current_precedence
    advance_tokens
    right = parse_expression(precedence)
    InfixExpression.new(token, left, operator, right)
  end

  def parse_call_expression(function)
    token     = @current_token
    arguments = parse_call_arguments
    CallExpression.new(token, function, arguments)
  end

  # [FIX VULN-16] Error más claro y único cuando falta el ')' de cierre
  def parse_call_arguments
    arguments = []
    if peek_token_is(TokenType::RPAREN)
      advance_tokens
      return arguments
    end
    advance_tokens
    arg = parse_expression(Precedences::LOWEST)
    arguments << arg if arg
    while peek_token_is(TokenType::COMMA)
      advance_tokens
      advance_tokens
      arg = parse_expression(Precedences::LOWEST)
      arguments << arg if arg
    end
    unless expected_token(TokenType::RPAREN)
      line_info = @current_token.line ? " en línea #{@current_token.line}" : ''
      @errors << "Falta ')' al cerrar la lista de argumentos#{line_info}"
      # [FIX VULN-16] retornamos lo que parseamos hasta ahora, no lista vacía
      return arguments
    end
    arguments
  end

  # ── Utilidades ──────────────────────────────────────────────────────────
  def advance_tokens
    @current_token = @peek_token
    @peek_token    = @lexer.next_token
  end

  def current_token_is(token_type)
    @current_token && @current_token.token_type == token_type
  end

  def peek_token_is(token_type)
    @peek_token && @peek_token.token_type == token_type
  end

  # [FIX VULN-20] Mensajes de error incluyen número de línea
  def expected_token(token_type)
    if peek_token_is(token_type)
      advance_tokens
      true
    else
      peek_line = @peek_token&.line
      line_info = peek_line ? " (línea #{peek_line})" : ''
      peek_lit  = @peek_token&.literal || 'EOF'
      @errors << "Se esperaba #{token_type}, pero se obtuvo '#{peek_lit}'#{line_info}"
      false
    end
  end

  def current_precedence
    PRECEDENCES_TABLE.fetch(@current_token&.token_type, Precedences::LOWEST)
  end

  def peek_precedence
    PRECEDENCES_TABLE.fetch(@peek_token&.token_type, Precedences::LOWEST)
  end
end
