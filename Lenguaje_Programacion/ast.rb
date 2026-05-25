# =============================================================================
# ast.rb — Árbol Sintáctico Abstracto (AST)
#
# El AST es la representación intermedia del programa.
# El Parser toma la secuencia de tokens producida por el Lexer y construye
# este árbol. Luego el Evaluador recorre el árbol para ejecutar el programa.
#
# Jerarquía de clases:
#   Node
#   ├── Statement (sentencias: declaraciones, control de flujo)
#   │   ├── Program              ← nodo raíz de todo el programa
#   │   ├── LetStatement         ← let x = expr;
#   │   ├── ReturnStatement      ← return expr;
#   │   ├── ExpressionStatement  ← expr;  (una expresión usada como sentencia)
#   │   ├── BlockStatement       ← { stmt; stmt; ... }
#   │   ├── WhileStatement       ← while (cond) { ... }
#   │   └── ForStatement         ← for (init; cond; update) { ... }
#   │
#   └── Expression (expresiones: producen un valor)
#       ├── Identifier           ← nombre de variable
#       ├── IntegerLiteral       ← 42
#       ├── FloatLiteral         ← 3.14
#       ├── StringLiteral        ← "hola"
#       ├── BooleanLiteral       ← true / false
#       ├── PrefixExpression     ← !expr  o  -expr
#       ├── InfixExpression      ← expr OP expr
#       ├── IfExpression         ← if (cond) { } elseif (c) { } else { }
#       ├── FunctionLiteral      ← function(params) { body }
#       └── CallExpression       ← función(args)
# =============================================================================

# ─────────────────────────────────────────────────────────────────────────────
# CLASES BASE
# ─────────────────────────────────────────────────────────────────────────────
class Node
  def token_literal
     # Si una clase hija NO implementa esto → error
    raise NotImplementedError, "Debes implementar token_literal"
  end

  def to_s
     # Si una clase hija NO implementa esto → error
    raise NotImplementedError, "Debes implementar to_s"
  end
end

# ─────────────────────────────────────────────
# SENTENCIAS
# ─────────────────────────────────────────────
class Statement < Node
  # No necesita nada por ahora.
  # Sirve como "tipo base" para identificar sentencias.

    """
    Nodo base para SENTENCIAS.

    Las sentencias NO producen un valor por sí mismas; ejecutan una acción.
    Ejemplos: let x = 5;  return x;  while (...) { ... }
    """
end


# ─────────────────────────────────────────────
# EXPRESIONES
# ─────────────────────────────────────────────
class Expression < Node
  # Igual que Statement, es solo una clase base.
    """
    Nodo base para EXPRESIONES.

    Las expresiones SÍ producen un valor.
    Ejemplos: 5 + 3,  miFuncion(x),  x == y
    """
end

# ─────────────────────────────────────────────────────────────────────────────
# NODO RAÍZ
# ─────────────────────────────────────────────────────────────────────────────
class Program < Node
  attr_accessor :statements # Crea solito getter y setter

  def initialize
    # Lista de todas las sentencias del programa
    @statements = []
  end

  # Retorna el literal del primer token del programa
  def token_literal
    if @statements.any?
      @statements.first.token_literal
    else
      ""
    end
  end

  # Representación en string del programa completo
  def to_s
    @statements.map(&:to_s).join("\n")
  end
end

# ─────────────────────────────────────────────────────────────────────────────
# SENTENCIAS (Statements)
# ─────────────────────────────────────────────────────────────────────────────

# ─────────────────────────────────────────────
# LET STATEMENT
# ─────────────────────────────────────────────
class LetStatement < Statement
  attr_accessor :token, :name, :value

  def initialize(token, name, value = nil)
    @token = token
    @name = name
    @value = value
  end

  def token_literal
    @token.literal
  end

  def to_s
    value_str = @value ? @value.to_s : ""
    "let #{@name} = #{value_str};"
  end
end


# ─────────────────────────────────────────────
# RETURN STATEMENT
# ─────────────────────────────────────────────
class ReturnStatement < Statement
  attr_accessor :token, :return_value

  def initialize(token, return_value = nil)
    @token = token
    @return_value = return_value
  end

  def token_literal
    @token.literal
  end

  def to_s
    value_str = @return_value ? @return_value.to_s : ""
    "return #{value_str};"
  end
end


# ─────────────────────────────────────────────
# EXPRESSION STATEMENT
# ─────────────────────────────────────────────
class ExpressionStatement < Statement
  attr_accessor :token, :expression

  def initialize(token, expression = nil)
    @token = token
    @expression = expression
  end

  def token_literal
    @token.literal
  end

  def to_s
    @expression ? @expression.to_s : ""
  end
end


# ─────────────────────────────────────────────
# BLOCK STATEMENT
# ─────────────────────────────────────────────
class BlockStatement < Statement
  attr_accessor :token, :statements

  def initialize(token)
    @token = token      # El token '{' que abre el bloque
    @statements = []    # Sentencias dentro del bloque
  end

  def token_literal
    @token.literal
  end

  def to_s
    stmts = @statements.map { |s| "  #{s}" }.join("\n")
    "{\n#{stmts}\n}"
  end
end


# ─────────────────────────────────────────────
# WHILE STATEMENT
# ─────────────────────────────────────────────
class WhileStatement < Statement
  attr_accessor :token, :condition, :body

  def initialize(token, condition, body)
    @token = token                  # El token WHILE ('while')
    @condition = condition          # Expresión que se evalúa en cada iteración
    @body = body                    # Bloque de sentencias del cuerpo
  end

  def token_literal
    @token.literal
  end

  def to_s
    "while (#{@condition}) #{@body}"
  end
end


# ─────────────────────────────────────────────
# FOR STATEMENT
# ─────────────────────────────────────────────
class ForStatement < Statement
  attr_accessor :token, :init, :condition, :update, :body

  def initialize(token, init = nil, condition = nil, update = nil, body)
    @token = token              # El token FOR ('for')
    @init = init                # Inicialización (puede ser None)
    @condition = condition      # Condición (puede ser None → bucle infinito)
    @update = update            # Actualización (puede ser None)
    @body = body                # Cuerpo del bucle
  end

  def token_literal
    @token.literal
  end

  def to_s
    "for (#{@init}; #{@condition}; #{@update}) #{@body}"
  end
end


# ─────────────────────────────────────────────
# BREAK
# ─────────────────────────────────────────────
class BreakStatement < Statement
  attr_accessor :token

  def initialize(token)
    @token = token      # El token BREAK ('break')
  end

  def token_literal
    @token.literal
  end

  def to_s
    "break;"
  end
end


# ─────────────────────────────────────────────
# CONTINUE
# ─────────────────────────────────────────────
class ContinueStatement < Statement
  attr_accessor :token

  def initialize(token)
    @token = token          # El token CONTINUE ('continue')
  end

  def token_literal
    @token.literal
  end

  def to_s
    "continue;"
  end
end

# ─────────────────────────────────────────────────────────────────────────────
# EXPRESIONES (Expressions)
# ─────────────────────────────────────────────────────────────────────────────

# ─────────────────────────────────────────────
# IDENTIFIER
# ─────────────────────────────────────────────
class Identifier < Expression
  attr_accessor :token, :value

  def initialize(token, value)
    @token = token      # El token IDENTIFIER
    @value = value      # El nombre como string
  end

  def token_literal
    @token.literal
  end

  def to_s
    @value
  end
end


# ─────────────────────────────────────────────
# INTEGER
# ─────────────────────────────────────────────
class IntegerLiteral < Expression
  attr_accessor :token, :value

  def initialize(token, value)
    @token = token      # El token INTEGER
    @value = value      # El valor entero ya convertido (int)
  end

  def token_literal
    @token.literal
  end

  def to_s
    @value.to_s
  end
end


# ─────────────────────────────────────────────
# FLOAT
# ─────────────────────────────────────────────
class FloatLiteral < Expression
  attr_accessor :token, :value

  def initialize(token, value)
    @token = token      # El token FLOAT
    @value = value      # El valor flotante ya convertido (float)
  end

  def token_literal
    @token.literal
  end

  def to_s
    @value.to_s
  end
end


# ─────────────────────────────────────────────
# STRING
# ─────────────────────────────────────────────
class StringLiteral < Expression
  attr_accessor :token, :value

  def initialize(token, value)
    @token = token      # El token STRING
    @value = value      # El contenido del string (sin comillas)
  end

  def token_literal
    @token.literal
  end

  def to_s
    "\"#{@value}\"" #Esto para que el bro sepa que los string van dentro de comillas y lo muestre bien
  end
end


# ─────────────────────────────────────────────
# BOOLEAN
# ─────────────────────────────────────────────
class BooleanLiteral < Expression
  attr_accessor :token, :value

  def initialize(token, value)
    @token = token      # El token TRUE o FALSE
    @value = value      # True o False (Python bool)
  end

  def token_literal
    @token.literal
  end

  def to_s
    @value ? "true" : "false"
  end
end


# ─────────────────────────────────────────────
# PREFIX EXPRESSION
# ─────────────────────────────────────────────
class PrefixExpression < Expression
    """
    Nodo para expresiones con operador PREFIJO: <operador><expresión>

    Ejemplos:
      !verdadero   →  PrefixExpression(operator='!', right=BooleanLiteral(true))
      -5           →  PrefixExpression(operator='-', right=IntegerLiteral(5))
    """

  attr_accessor :token, :operator, :right

  def initialize(token, operator, right = nil)
    @token = token              # El token del operador ('!' o '-')
    @operator = operator        # El símbolo del operador como string
    @right = right              #La expresión a la derecha del operador
  end

  def token_literal
    @token.literal
  end

  def to_s
    "(#{@operator}#{@right})"
  end
end

# ─────────────────────────────────────────────
# INFIX EXPRESSION
# ─────────────────────────────────────────────
class InfixExpression < Expression
    """
    Nodo para expresiones con operador INFIJO: <izquierda> <operador> <derecha>

    Ejemplos:
      5 + 3     →  InfixExpression(left=5, operator='+', right=3)
      x == y    →  InfixExpression(left=x, operator='==', right=y)
      a and b   →  InfixExpression(left=a, operator='and', right=b)
    """

  attr_accessor :token, :left, :operator, :right

  def initialize(token, left, operator, right = nil)
    @token = token              # El token del operador
    @left = left                # Expresión del lado izquierdo
    @operator = operator        # El símbolo del operador como string
    @right = right              # Expresión del lado derecho
  end

  def token_literal
    @token.literal
  end

  def to_s
    "(#{@left} #{@operator} #{@right})"
  end
end

# ─────────────────────────────────────────────
# IF EXPRESSION
# ─────────────────────────────────────────────
class IfExpression < Expression
    """
    Nodo para condicionales: if (...) { } elseif (...) { } else { }

    Soporta múltiples ramas elseif como lista de pares (condición, bloque).

    Ejemplo:
        if (x > 0) {
            print("positivo");
        } elseif (x == 0) {
            print("cero");
        } else {
            print("negativo");
        }
    """
  attr_accessor :token, :condition, :consequence, :alternatives, :else_block

  def initialize(token, condition, consequence, alternatives = [], else_block = nil)
    @token = token                              # El token IF ('if')
    @condition = condition                      # Condición del if principal
    @consequence = consequence                  # Bloque si la condición es verdadera
    @alternatives = alternatives || []          # Lista de ramas elseif
    @else_block = else_block                    # Bloque else final (opcional)
  end

  def token_literal
    @token.literal
  end

  def to_s
    result = "if (#{@condition}) #{@consequence}"

    @alternatives.each do |cond, block|
      result += " elseif (#{cond}) #{block}"
    end

    if @else_block
      result += " else #{@else_block}"
    end

    result
  end
end

# ─────────────────────────────────────────────
# FUNCTION LITERAL
# ─────────────────────────────────────────────
class FunctionLiteral < Expression
    """
    Nodo para la DEFINICIÓN de una función: function(<parámetros>) { <cuerpo> }

    Ejemplo:
        function(x, y) {
            return x + y;
        }

    Las funciones en este lenguaje son valores de primera clase:
    se pueden asignar a variables, pasar como argumentos, etc.
    La recursión funciona porque el entorno (Environment) guarda
    la referencia al propio objeto función.
    """
  attr_accessor :token, :parameters, :body, :name

  def initialize(token, parameters, body, name = "")
    @token = token              # El token FUNCTION ('function')
    @parameters = parameters    # Lista de Identifier (parámetros formales)
    @body = body                # Bloque de sentencias del cuerpo
    @name = name                # Nombre (si fue asignada con let)
  end

  def token_literal
    @token.literal
  end

  def to_s
    params = @parameters.map(&:to_s).join(", ")
    name_str = @name.empty? ? "" : " #{@name}"
    "function#{name_str}(#{params}) #{@body}"
  end
end

# ─────────────────────────────────────────────
# CALL EXPRESSION
# ─────────────────────────────────────────────
class CallExpression < Expression
    """
    Nodo para la LLAMADA a una función: <función>(<argumentos>)

    Ejemplo:
        factorial(5)
        suma(x, y + 1)

    La función puede ser un identificador (nombre) o una expresión
    que produce una función (e.g. una lambda inmediata).
    """
  attr_accessor :token, :function, :arguments

  def initialize(token, function, arguments)
    @token = token            # El token '(' de la llamada
    @function = function      # La función (Identifier o FunctionLiteral)
    @arguments = arguments    # Lista de expresiones (argumentos reales)
  end

  def token_literal
    @token.literal
  end

  def to_s
    args = @arguments.map(&:to_s).join(", ")
    "#{@function}(#{args})"
  end
end

# ─────────────────────────────────────────────
# PRINT STATEMENT
# ─────────────────────────────────────────────
class PrintStatement < Statement
    """
    Nodo para la sentencia de impresión: print(<expresión>);

    Ejemplo: print(x + 1);
    """
  attr_accessor :token, :value

  def initialize(token, value)
    @token = token        # El token PRINT ('print')
    @value = value        # La expresión a imprimir
  end

  def token_literal
    @token.literal
  end

  def to_s
    "print(#{@value});"
  end
end