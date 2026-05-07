# =============================================================================
# tokens.rb — Definición de todos los tipos de tokens del lenguaje
#
# Un TOKEN es la unidad mínima de significado para el lenguaje.
# Por ejemplo: una palabra clave (if), un número (42), un operador (+), etc.
# El Lexer convierte el código fuente (texto plano) en una lista de tokens.
# =============================================================================


module TokenType
  PLUS       = :PLUS
  MINUS      = :MINUS
  MULTIPLY   = :MULTIPLY
  DIVISION   = :DIVISION
  MOD        = :MOD
  POW        = :POW

  EQ         = :EQ
  DIF        = :DIF
  LT         = :LT
  LTE        = :LTE
  GT         = :GT
  GTE        = :GTE

  AND        = :AND
  OR         = :OR
  NEGATION   = :NEGATION

  ASSIGN     = :ASSIGN

  COMMA      = :COMMA
  SEMICOLON  = :SEMICOLON
  LPAREN     = :LPAREN
  RPAREN     = :RPAREN
  LBRACE     = :LBRACE
  RBRACE     = :RBRACE

  INTEGER    = :INTEGER
  FLOAT      = :FLOAT
  STRING     = :STRING
  TRUE       = :TRUE
  FALSE      = :FALSE

  IDENTIFIER = :IDENTIFIER

  FUNCTION   = :FUNCTION
  LET        = :LET
  RETURN     = :RETURN
  IF         = :IF
  ELSEIF     = :ELSEIF
  ELSE       = :ELSE
  WHILE      = :WHILE
  FOR        = :FOR
  BREAK      = :BREAK
  CONTINUE   = :CONTINUE
  PRINT      = :PRINT

  EOF        = :EOF
  ILLEGAL    = :ILLEGAL

  # Extras
  SQRT = :SQRT
  ROOT = :ROOT

end

    """
    Representa un token individual producido por el Lexer.

    Cada token tiene:
      - token_type: su categoría (TokenType)
      - literal:    el texto original del código fuente que lo generó

    Por ejemplo, para el código `let x = 5;`:
      Token(LET, 'let')
      Token(IDENTIFIER, 'x')
      Token(ASSIGN, '=')
      Token(INTEGER, '5')
      Token(SEMICOLON, ';')
    """
# Aqui defino la estructura del token y digo que tiene token_type y pues la info
# Es como crear una clase en java con metodos y eso
Token = Struct.new(:token_type, :literal) do
  # Metodo que define como imprimir el token
  def to_s
    # token_type.to_s.ljust(12) == llama al token y lo alinea a la izquierda con 12 espacios
    # literal.inspect == mira que es lo que se ingresó
    "Type: #{token_type.to_s.ljust(12)}  Literal: #{literal.inspect}"
  end

end



    """
    Determina si una cadena es una palabra reservada (keyword) o un identificador.

    El Lexer llama a esta función cada vez que termina de leer un identificador.
    Si el texto pertenece al lenguaje (e.g. 'if', 'while'), retorna su TokenType.
    Si no, lo trata como un nombre de variable/función → IDENTIFIER.

    Ejemplos:
      lookup_token_type('if')       → TokenType.IF
      lookup_token_type('function') → TokenType.FUNCTION
      lookup_token_type('miVar')    → TokenType.IDENTIFIER
    """
# Aqui van las palabras reservadas del lenguaje
def lookup_token_type(literal)
  keywords = {
    'mousekeherramienta_misteriosa' => TokenType::FUNCTION,
    'asignoasigno'      => TokenType::LET,
    'retornable_como_la_cocacola_retornable'   => TokenType::RETURN,
    'si_se_porta_bien_hacemos...'       => TokenType::IF,
    'si_no_se_porta_bien_entonces_hacemos_otra_cosa...'   => TokenType::ELSEIF,
    'si_no_se_porta_bien_nunca...'     => TokenType::ELSE,
    'primero_miremos_aver_sisi'    => TokenType::WHILE,
    'parapapapa'      => TokenType::FOR,
    'detente_jochis'    => TokenType::BREAK,
    'noparesiguesigue_noparesiguesigue' => TokenType::CONTINUE,
    'sipirili'     => TokenType::TRUE,
    'noporolo'    => TokenType::FALSE,
    'Y_un_guarito'      => TokenType::AND,
    'O_una_polita'       => TokenType::OR,
    'imprimiendoendo'    => TokenType::PRINT,

    #Cosas de chavos
    'divisao' => TokenType::DIVISION,
    'adicao' => TokenType::PLUS,
    'subtracao' => TokenType::MINUS,
    'lamamadelamamadelamamadelamamadelamama' => TokenType::POW,
    'lahijadelahijadelahijadelahijadelahija' => TokenType::ROOT,
    'lahijadelahija' => TokenType::SQRT,
    'no_me_importa_que_usted_sea_mayor_que_yo_yo_la_quiero_en_mi_cama' => TokenType::GT,
    'no_me_importa_que_usted_sea_menor_que_yo' => TokenType::LT,


  }
    # Busca el literal en el arreglo? diccionario? idk, si no existe devuelve IDENTIFIER
    keywords.fetch(literal, TokenType::IDENTIFIER)
end