# =============================================================================
# object.rb — Sistema de Tipos del Evaluador
#
# Cuando el evaluador procesa el AST, cada expresión produce un "objeto".
# Estos objetos son los valores que viven en memoria durante la ejecución.
#
# Jerarquía:
#   BaseObject (clase abstracta)
#   ├── IntegerObject       ← valor entero:        42
#   ├── FloatObject         ← valor flotante:       3.14
#   ├── StringObject        ← valor string:         "hola"
#   ├── BooleanObject       ← valor booleano:       true / false
#   ├── NullObject          ← ausencia de valor:    null
#   ├── FunctionObject      ← función con clausura: function(x) { ... }
#   ├── ReturnValue         ← señal de return:      envuelve otro objeto
#   ├── ErrorObject         ← error en tiempo de ejecución
#   ├── BreakSignal         ← señal de break
#   └── ContinueSignal      ← señal de continue
#
# Singletons globales (se reusan para no crear objetos innecesarios):
#   TRUE_OBJ, FALSE_OBJ, NULL_OBJ, BREAK_OBJ, CONTINUE_OBJ
# =============================================================================


# ─────────────────────────────────────────────────────────────────────────────
# TIPOS DE OBJETOS
# ─────────────────────────────────────────────────────────────────────────────
module ObjectType
  INTEGER  = :INTEGER
  FLOAT    = :FLOAT
  STRING   = :STRING
  BOOLEAN  = :BOOLEAN
  NULL     = :NULL
  FUNCTION = :FUNCTION
  RETURN_VALUE = :RETURN_VALUE
  ERROR    = :ERROR
  BREAK    = :BREAK
  CONTINUE = :CONTINUE
end


# ─────────────────────────────────────────────────────────────────────────────
# CLASE BASE
# ─────────────────────────────────────────────────────────────────────────────
class BaseObject
  # Retorna el tipo del objeto (ObjectType)
  def object_type
    raise NotImplementedError, "Debes implementar object_type"
  end

  # Representación legible del objeto (para print y debug)
  def inspect_value
    raise NotImplementedError, "Debes implementar inspect_value"
  end
end


# ─────────────────────────────────────────────────────────────────────────────
# ENTERO
# ─────────────────────────────────────────────────────────────────────────────
class IntegerObject < BaseObject
  attr_accessor :value

  def initialize(value)
    @value = value    # El entero como Integer de Ruby
  end

  def object_type
    ObjectType::INTEGER
  end

  def inspect_value
    @value.to_s
  end
end


# ─────────────────────────────────────────────────────────────────────────────
# FLOTANTE
# ─────────────────────────────────────────────────────────────────────────────
class FloatObject < BaseObject
  attr_accessor :value

  def initialize(value)
    @value = value    # El flotante como Float de Ruby
  end

  def object_type
    ObjectType::FLOAT
  end

  def inspect_value
    @value.to_s
  end
end


# ─────────────────────────────────────────────────────────────────────────────
# STRING
# ─────────────────────────────────────────────────────────────────────────────
class StringObject < BaseObject
  attr_accessor :value

  def initialize(value)
    @value = value    # El contenido del string (sin comillas)
  end

  def object_type
    ObjectType::STRING
  end

  def inspect_value
    @value
  end
end


# ─────────────────────────────────────────────────────────────────────────────
# BOOLEANO
# ─────────────────────────────────────────────────────────────────────────────
class BooleanObject < BaseObject
  attr_accessor :value

  def initialize(value)
    @value = value    # true o false (Boolean de Ruby)
  end

  def object_type
    ObjectType::BOOLEAN
  end

  def inspect_value
    @value.to_s
  end
end

# Singletons: en vez de crear new BooleanObject en cada evaluación,
# siempre retornamos el mismo objeto (más eficiente y comparables con ==)
TRUE_OBJ  = BooleanObject.new(true)
FALSE_OBJ = BooleanObject.new(false)


# ─────────────────────────────────────────────────────────────────────────────
# NULL
# ─────────────────────────────────────────────────────────────────────────────
class NullObject < BaseObject
  def object_type
    ObjectType::NULL
  end

  def inspect_value
    "null"
  end
end

NULL_OBJ = NullObject.new


# ─────────────────────────────────────────────────────────────────────────────
# FUNCIÓN (con clausura)
# ─────────────────────────────────────────────────────────────────────────────
class FunctionObject < BaseObject
  attr_accessor :parameters, :body, :env

  # parameters → Lista de nodos Identifier (parámetros formales del AST)
  # body       → Nodo BlockStatement (cuerpo de la función del AST)
  # env        → El entorno donde fue DEFINIDA la función (clausura)
  def initialize(parameters, body, env)
    @parameters = parameters
    @body       = body
    @env        = env
  end

  def object_type
    ObjectType::FUNCTION
  end

  def inspect_value
    params = @parameters.map(&:to_s).join(", ")
    "function(#{params}) #{@body}"
  end
end


# ─────────────────────────────────────────────────────────────────────────────
# SEÑAL DE RETURN
# ─────────────────────────────────────────────────────────────────────────────
# Envuelve el valor retornado para que pueda "burbujear" por el AST
# hasta llegar a la llamada de función que lo captura.
class ReturnValue < BaseObject
  attr_accessor :value

  def initialize(value)
    @value = value    # El objeto que se retorna
  end

  def object_type
    ObjectType::RETURN_VALUE
  end

  def inspect_value
    @value.inspect_value
  end
end


# ─────────────────────────────────────────────────────────────────────────────
# ERROR EN TIEMPO DE EJECUCIÓN
# ─────────────────────────────────────────────────────────────────────────────
# Se retorna (no se lanza como excepción) cuando ocurre algo malo.
# Se propaga hacia arriba por el evaluador hasta ser reportado.
class ErrorObject < BaseObject
  attr_accessor :message

  def initialize(message)
    @message = message
  end

  def object_type
    ObjectType::ERROR
  end

  def inspect_value
    "ERROR: #{@message}"
  end
end


# ─────────────────────────────────────────────────────────────────────────────
# SEÑALES DE CONTROL DE FLUJO
# ─────────────────────────────────────────────────────────────────────────────

# break → interrumpe el bucle actual
class BreakSignal < BaseObject
  def object_type
    ObjectType::BREAK
  end

  def inspect_value
    "break"
  end
end

# continue → salta a la siguiente iteración del bucle
class ContinueSignal < BaseObject
  def object_type
    ObjectType::CONTINUE
  end

  def inspect_value
    "continue"
  end
end

# Singletons de control de flujo
BREAK_OBJ    = BreakSignal.new
CONTINUE_OBJ = ContinueSignal.new
