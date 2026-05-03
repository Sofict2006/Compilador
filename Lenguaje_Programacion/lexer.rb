# =============================================================================
# lexer.rb — Analizador Léxico (Lexer / Scanner)
#
# El Lexer es la primera etapa del intérprete. Su trabajo es leer el código
# fuente carácter a carácter y agruparlos en TOKENS significativos.
#
# Ejemplo de transformación:
#   Código fuente: let x = 10 + 5;
#   Tokens:  [LET 'let'] [IDENT 'x'] [ASSIGN '='] [INT '10']
#            [PLUS '+'] [INT '5'] [SEMICOLON ';'] [EOF '']
# =============================================================================

require_relative 'tokens'

class Lexer

  def initialize(source)
    @source = source
    @character = ''
    @position = 0
    @read_position = 0

    _read_character
  end


  # ─────────────────────────────────────────────────────────────────────────
  # MÉTODO PRINCIPAL
  # ─────────────────────────────────────────────────────────────────────────
  def next_token
    _skip_whitespace_and_comments

    # nil en ruby es como vacio, asi sin nada
    token = nil

    case @character

    when ''
      token = Token.new(TokenType::EOF, '')

    when '+'
      token = Token.new(TokenType::PLUS, @character)

    when '-'
      token = Token.new(TokenType::MINUS, @character)

    when '*'
      token = Token.new(TokenType::MULTIPLY, @character)

    when '/'
      token = Token.new(TokenType::DIVISION, @character)

    when '%'
      token = Token.new(TokenType::MOD, @character)

    when '^'
      token = Token.new(TokenType::POW, @character)

    when '='
      if _peek_character == '='
        token = _make_two_character_token(TokenType::EQ)
      else
        token = Token.new(TokenType::ASSIGN, @character)
      end

    when '!'
      if _peek_character == '='
        token = _make_two_character_token(TokenType::DIF)
      else
        token = Token.new(TokenType::NEGATION, @character)
      end

    when '<'
      if _peek_character == '='
        token = _make_two_character_token(TokenType::LTE)
      else
        token = Token.new(TokenType::LT, @character)
      end

    when '>'
      if _peek_character == '='
        token = _make_two_character_token(TokenType::GTE)
      else
        token = Token.new(TokenType::GT, @character)
      end

    when ','
      token = Token.new(TokenType::COMMA, @character)

    when ';'
      token = Token.new(TokenType::SEMICOLON, @character)

    when '('
      token = Token.new(TokenType::LPAREN, @character)

    when ')'
      token = Token.new(TokenType::RPAREN, @character)

    when '{'
      token = Token.new(TokenType::LBRACE, @character)

    when '}'
      token = Token.new(TokenType::RBRACE, @character)

    when '"'
      str_content = _read_string
      return Token.new(TokenType::STRING, str_content)

    else
      if _is_letter(@character)
        literal = _read_identifier
        token_type = lookup_token_type(literal)
        return Token.new(token_type, literal)

      #Este condicional raro dice: Si el caracter es un digito del 0-9 (/\d/) entonces que lea el numero completo
      elsif @character =~ /\d/
        literal, token_type = _read_number
        return Token.new(token_type, literal)

      else
        token = Token.new(TokenType::ILLEGAL, @character)
      end
    end

    _read_character
    token
  end


  # ─────────────────────────────────────────────────────────────────────────
  # MÉTODOS AUXILIARES
  # ─────────────────────────────────────────────────────────────────────────
  def _read_character
    if @read_position >= @source.length
      @character = ''
    else
      @character = @source[@read_position]
    end

    @position = @read_position
    @read_position += 1
  end

  def _peek_character
    return '' if @read_position >= @source.length
    @source[@read_position]
  end

  def _make_two_character_token(token_type)
    prefix = @character
    _read_character
    suffix = @character
    Token.new(token_type, "#{prefix}#{suffix}")
  end

  def _skip_whitespace_and_comments
    loop do
      if @character =~ /\s/
        _read_character

      elsif @character == '/' && _peek_character == '/'
        while @character != "\n" && @character != ''
          _read_character
        end

      else
        break
      end
    end
  end

  def _is_letter(ch)
    ch =~ /[a-zA-Z]/ || ch == '_'
  end

  def _read_identifier
    start = @position
    while _is_letter(@character) || @character =~ /\d/
      _read_character
    end
    @source[start...@position]
  end

  def _read_number
    start = @position
    token_type = TokenType::INTEGER

    while @character =~ /\d/
      _read_character
    end

    if @character == '.' && _peek_character =~ /\d/
      token_type = TokenType::FLOAT
      _read_character
      while @character =~ /\d/
        _read_character
      end
    end

    literal = @source[start...@position]
    [literal, token_type]
  end

  def _read_string
    _read_character
    start = @position

    while @character != '"' && @character != ''
      _read_character
    end

    literal = @source[start...@position]
    _read_character
    literal
  end
  
end