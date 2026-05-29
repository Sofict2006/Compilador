# =============================================================================
# tokens.rb — Definición de todos los tipos de tokens del lenguaje
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

  SQRT = :SQRT
  ROOT = :ROOT
end

# [FIX VULN-20] Token ahora guarda número de línea para mensajes de error útiles
Token = Struct.new(:token_type, :literal, :line) do
  def to_s
    "Type: #{token_type.to_s.ljust(12)}  Literal: #{literal.inspect}  [L#{line || '?'}]"
  end
end

# Palabras reservadas del lenguaje
def lookup_token_type(literal)
  keywords = {
    'mousekeherramienta_misteriosa'                            => TokenType::FUNCTION,
    'asignoasigno'                                            => TokenType::LET,
    'retornable_como_la_cocacola_retornable'                  => TokenType::RETURN,
    'si_se_porta_bien_hacemos...'                             => TokenType::IF,
    'si_no_se_porta_bien_entonces_hacemos_otra_cosa...'       => TokenType::ELSEIF,
    'si_no_se_porta_bien_nunca...'                            => TokenType::ELSE,
    'primero_miremos_aver_sisi'                               => TokenType::WHILE,
    'parapapapa'                                              => TokenType::FOR,
    'detente_jochis'                                          => TokenType::BREAK,
    'noparesiguesigue_noparesiguesigue'                       => TokenType::CONTINUE,
    'sipirili'                                                => TokenType::TRUE,
    'noporolo'                                                => TokenType::FALSE,
    'Y_un_guarito'                                            => TokenType::AND,
    'O_una_polita'                                            => TokenType::OR,
    'imprimiendoendo'                                         => TokenType::PRINT,
    'divisao'                                                 => TokenType::DIVISION,
    'adicao'                                                  => TokenType::PLUS,
    'subtracao'                                               => TokenType::MINUS,
    'lamamadelamamadelamamadelamamadelamama'                   => TokenType::POW,
    'lahijadelahijadelahijadelahijadelahija'                   => TokenType::ROOT,
    'lahijadelahija'                                          => TokenType::SQRT,
    'no_me_importa_que_usted_sea_mayor_que_yo_yo_la_quiero_en_mi_cama' => TokenType::GT,
    'no_me_importa_que_usted_sea_menor_que_yo'                => TokenType::LT,
  }
  keywords.fetch(literal, TokenType::IDENTIFIER)
end