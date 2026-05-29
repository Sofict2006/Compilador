# =============================================================================
# lexer.rb — Analizador Léxico (Lexer / Scanner)
#
# FIXES APLICADOS:
#   VULN-13: '.' ya no es una letra válida en identificadores
#   VULN-13: Los sufijos '...' de keywords se manejan explícitamente
#   VULN-14: Soporte de escape sequences: \n \t \r \" \\
#   VULN-20: El lexer rastrea número de línea y lo pasa a cada token
# =============================================================================

require_relative 'tokens'

class Lexer

  def initialize(source)
    @source = source
    @character = ''
    @position  = 0
    @read_position = 0
    @line = 1   # [FIX VULN-20] rastreo de línea actual

    _read_character
  end

  # ─────────────────────────────────────────────────────────────────────────
  # MÉTODO PRINCIPAL
  # ─────────────────────────────────────────────────────────────────────────
  def next_token
    _skip_whitespace_and_comments

    current_line = @line   # [FIX VULN-20] capturamos la línea del token
    token = nil

    case @character

    when ''
      token = Token.new(TokenType::EOF, '', current_line)

    when '+'
      token = Token.new(TokenType::PLUS, @character, current_line)

    when '-'
      token = Token.new(TokenType::MINUS, @character, current_line)

    when '*'
      token = Token.new(TokenType::MULTIPLY, @character, current_line)

    when '/'
      token = Token.new(TokenType::DIVISION, @character, current_line)

    when '%'
      token = Token.new(TokenType::MOD, @character, current_line)

    when '^'
      token = Token.new(TokenType::POW, @character, current_line)

    when '='
      if _peek_character == '='
        token = _make_two_character_token(TokenType::EQ, current_line)
      else
        token = Token.new(TokenType::ASSIGN, @character, current_line)
      end

    when '!'
      if _peek_character == '='
        token = _make_two_character_token(TokenType::DIF, current_line)
      else
        token = Token.new(TokenType::NEGATION, @character, current_line)
      end

    when '<'
      if _peek_character == '='
        token = _make_two_character_token(TokenType::LTE, current_line)
      else
        token = Token.new(TokenType::LT, @character, current_line)
      end

    when '>'
      if _peek_character == '='
        token = _make_two_character_token(TokenType::GTE, current_line)
      else
        token = Token.new(TokenType::GT, @character, current_line)
      end

    when ','
      token = Token.new(TokenType::COMMA, @character, current_line)

    when ';'
      token = Token.new(TokenType::SEMICOLON, @character, current_line)

    when '('
      token = Token.new(TokenType::LPAREN, @character, current_line)

    when ')'
      token = Token.new(TokenType::RPAREN, @character, current_line)

    when '{'
      token = Token.new(TokenType::LBRACE, @character, current_line)

    when '}'
      token = Token.new(TokenType::RBRACE, @character, current_line)

    when '"'
      # [FIX VULN-14] _read_string ahora maneja escape sequences
      str_content = _read_string
      return Token.new(TokenType::STRING, str_content, current_line)

    else
      if _is_letter(@character)
        literal    = _read_identifier
        token_type = lookup_token_type(literal)
        return Token.new(token_type, literal, current_line)

      elsif @character =~ /\d/
        literal, token_type = _read_number
        return Token.new(token_type, literal, current_line)

      else
        token = Token.new(TokenType::ILLEGAL, @character, current_line)
      end
    end

    _read_character
    token
  end


  # ─────────────────────────────────────────────────────────────────────────
  # MÉTODOS AUXILIARES
  # ─────────────────────────────────────────────────────────────────────────
  private

  def _read_character
    # [FIX VULN-20] incrementamos la línea cuando PASAMOS una nueva línea
    @line += 1 if @character == "\n"

    if @read_position >= @source.length
      @character = ''
    else
      @character = @source[@read_position]
    end

    @position      = @read_position
    @read_position += 1
  end

  def _peek_character
    return '' if @read_position >= @source.length
    @source[@read_position]
  end

  # Para detectar el sufijo '...' necesitamos ver 2 posiciones adelante
  def _peek_next_character
    return '' if @read_position + 1 >= @source.length
    @source[@read_position + 1]
  end

  def _make_two_character_token(token_type, line)
    prefix = @character
    _read_character
    suffix = @character
    Token.new(token_type, "#{prefix}#{suffix}", line)
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

  # [FIX VULN-13] El punto '.' ya NO es una letra válida en identificadores
  def _is_letter(ch)
    ch =~ /[a-zA-Z]/ || ch == '_'
  end

  def _read_identifier
    start = @position
    while _is_letter(@character) || (@character =~ /\d/ && @position > start)
      _read_character
    end
    literal = @source[start...@position]

    # [FIX VULN-13] Detectamos el sufijo '...' de keywords como
    # si_se_porta_bien_hacemos... sin permitir puntos arbitrarios
    if @character == '.' && _peek_character == '.' && _peek_next_character == '.'
      3.times { _read_character }
      literal += '...'
    end

    literal
  end

  def _read_number
    start      = @position
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

  # [FIX VULN-14] Soporte de escape sequences: \n \t \r \" \\
  def _read_string
    _read_character   # saltar la comilla de apertura
    result = ''

    while @character != '"' && @character != ''
      if @character == '\\'
        _read_character
        case @character
        when 'n'  then result += "\n"
        when 't'  then result += "\t"
        when 'r'  then result += "\r"
        when '"'  then result += '"'
        when '\\' then result += '\\'
        else           result += "\\#{@character}"
        end
      else
        result += @character
      end
      _read_character
    end

    _read_character   # saltar la comilla de cierre
    result
  end

end