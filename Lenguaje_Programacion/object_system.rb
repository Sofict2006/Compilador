# =============================================================================
# object_system.py — Sistema de Objetos en Tiempo de Ejecución
#
# Cuando el Evaluador recorre el AST, cada expresión produce un "Object".
# Este módulo define todos los tipos de valores que el lenguaje puede manejar
# en tiempo de ejecución (runtime):
#
#   Integer     → 42, -7, 0
#   Float       → 3.14, -0.5
#   Boolean     → true, false
#   String      → "hola mundo"
#   Null        → ausencia de valor
#   ReturnValue → envuelve un valor para propagar un 'return'
#   Error       → encapsula un mensaje de error de ejecución
#   Function    → una función con parámetros, cuerpo y entorno de cierre
#
# Todos los objetos del lenguaje heredan de la clase abstracta `Object`.
# =============================================================================

# ─────────────────────────────────────────────────────────────────────────────
# TIPOS DE OBJETO
# ─────────────────────────────────────────────────────────────────────────────

# Categorías de valores del lenguaje en tiempo de ejecución.
module ObjectType
  INTEGER  = :INTEGER   # Entero
  FLOAT    = :FLOAT     # Número decimal
  BOOLEAN  = :BOOLEAN   # true / false
  STRING   = :STRING    # Cadena de texto
  NULL     = :NULL      # Valor nulo
  RETURN   = :RETURN    # Señal de control: return
  ERROR    = :ERROR     # Error en ejecución
  FUNCTION = :FUNCTION  # Función (closure)
  BREAK    = :BREAK     # break en loops
  CONTINUE = :CONTINUE  # continue en loops
end

# ─────────────────────────────────────────────────────────────────────────────
# CLASE BASE
# ─────────────────────────────────────────────────────────────────────────────

# Clase base para todos los valores del lenguaje.
# Cada subclase representa un tipo de dato concreto.

class ObjectBase
  # Retorna el tipo del objeto (debe implementarse en subclases)
  def type
    raise NotImplementedError, "Subclasses must implement 'type'"
  end

  # Representación legible del valor (para imprimir en el REPL)
  def inspect
    raise NotImplementedError, "Subclasses must implement 'inspect'"
  end

  # Equivalente a __str__ en Python
  def to_s
    inspect
  end
end

# ─────────────────────────────────────────────────────────────────────────────
# TIPOS CONCRETOS
# ─────────────────────────────────────────────────────────────────────────────

class IntegerObject < ObjectBase
  # Valor entero del lenguaje.
  # Ejemplo: 42, -7, 0
  # Internamente usa Integer de Ruby.

  attr_accessor :value

  def initialize(value)
    @value = value
  end

  def type
    ObjectType::INTEGER
  end

  def inspect
    @value.to_s
  end
end

class FloatObject < ObjectBase
  # Valor decimal (punto flotante) del lenguaje.    
  # Ejemplo: 3.14, -0.5, 2.0
  # Internamente usa Float de Ruby.

  attr_accessor :value

  def initialize(value)
    @value = value
  end

  def type
    ObjectType::FLOAT
  end

  def inspect
    # Formato similar a Python :g (evitar notación científica si es posible)
    formatted = @value.to_s

    # Si no tiene punto decimal ni notación científica, agregar ".0"
    if !formatted.include?('.') && !formatted.downcase.include?('e')
      formatted += '.0'
    end

    formatted
  end
end

class BooleanObject < ObjectBase
  # Valor booleano del lenguaje: true o false.
  # El evaluador puede reutilizar instancias (TRUE y FALSE)
  # en lugar de crear nuevos objetos cada vez.

  attr_accessor :value

  def initialize(value)
    @value = value
  end

  def type
    ObjectType::BOOLEAN
  end

  def inspect
    @value ? "true" : "false"
  end
end

class StringObject < ObjectBase
  # Valor de cadena de texto del lenguaje.
  # Ejemplo: "hola mundo", "resultado: "
  # Internamente usa String de Ruby.

  attr_accessor :value

  def initialize(value)
    @value = value
  end

  def type
    ObjectType::STRING
  end

  def inspect
    @value
  end
end

class NullObject < ObjectBase
  # Representa la ausencia de valor (null).
  # El evaluador retorna este objeto cuando una expresión
  # no produce valor (ej: if sin else falso).

  def type
    ObjectType::NULL
  end

  def inspect
    "null"
  end
end

class ReturnValue < ObjectBase
  # Señal de control para propagar un `return` a través del call stack.
  #
  # Envuelve el valor real que se retorna. El evaluador lo desenvuelve
  # al salir de la función.

  attr_accessor :value

  def initialize(value)
    @value = value  # El objeto real que se va a retornar
  end

  def type
    ObjectType::RETURN
  end

  def inspect
    @value.inspect
  end
end

class ErrorObject < ObjectBase
  # Representa un error en tiempo de ejecución.
  #
  # El evaluador propaga el error hacia arriba del call stack hasta que
  # alguien lo maneje, similar a cómo ReturnValue propaga return.

  attr_accessor :message

  def initialize(message)
    @message = message  # Descripción del error
  end

  def type
    ObjectType::ERROR
  end

  def inspect
    "ERROR: #{@message}"
  end
end

class Function < ObjectBase
  # Objeto función (closure) del lenguaje.
  # Guarda los parámetros, el cuerpo y el entorno léxico en el que
  # fue definida. Esto permite funciones de primera clase y closures.

  attr_accessor :parameters, :body, :env, :name

  def initialize(parameters, body, env, name = '')
    @parameters = parameters  # Lista de Identifier (parámetros formales)
    @body = body              # BlockStatement con el código de la función
    @env = env                # Entorno léxico en el momento de la definición
    @name = name              # Nombre (si fue asignada con let)
  end

  def type
    ObjectType::FUNCTION
  end

  def inspect
    params = @parameters.map(&:to_s).join(', ')
    name_str = @name.empty? ? '' : " #{@name}"
    "function#{name_str}(#{params}) { ... }"
  end
end

class BreakSignal < ObjectBase
  # Señal de control interna para propagar un `break` desde el cuerpo
  # de un bucle hasta el manejador de while/for.
  # No es un valor visible para el usuario.

  def type
    ObjectType::BREAK
  end

  def inspect
    'break'
  end
end

class ContinueSignal < ObjectBase
  # Señal de control interna para propagar un `continue` desde el cuerpo
  # de un bucle hasta el manejador de while/for.
  # No es un valor visible para el usuario.

  def type
    ObjectType::CONTINUE
  end

  def inspect
    'continue'
  end
end

# ─────────────────────────────────────────────────────────────────────────────
# SINGLETONS GLOBALES
# ─────────────────────────────────────────────────────────────────────────────

# Singleton para true: evita crear un nuevo objeto Boolean en cada evaluación
TRUE = BooleanObject.new(true)

# Singleton para false
FALSE = BooleanObject.new(false)

# Singleton para null
NULL = NullObject.new

# Singleton para break (señal de control)
BREAK_SIGNAL = BreakSignal.new

# Singleton para continue (señal de control)
CONTINUE_SIGNAL = ContinueSignal.new