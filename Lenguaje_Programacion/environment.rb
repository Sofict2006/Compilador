# =============================================================================
# environment.rb — Entorno de Variables (Scope)
#
# El Environment es la "memoria" del programa: guarda el nombre de cada
# variable y su valor actual.
#
# Soporta CLAUSURAS (closures) mediante una cadena de entornos:
#   - Cada función crea su propio entorno local (enclosed).
#   - Si una variable no se encuentra en el entorno local, se busca
#     automáticamente en el entorno exterior (outer).
#
# Ejemplo de cadena de entornos:
#
#   Global env: { x: 10 }
#       └── Función env: { y: 5 }
#               └── La función puede leer x = 10 del entorno global
#
# Uso típico:
#   env = Environment.new                   ← entorno global vacío
#   env.set("x", IntegerObject.new(10))     ← asignar variable
#   env.get("x")                            ← recuperar variable
#
#   inner = Environment.new_enclosed(env)   ← nuevo scope (ej: dentro de función)
#   inner.get("x")                          ← encuentra x en el padre
# =============================================================================


class Environment
  def initialize(outer = nil)
    @store = {}       # Hash: nombre → BaseObject
    @outer = outer    # Entorno padre (nil si es el entorno global)
  end


  # ─────────────────────────────────────────────────────────────────────────
  # GET — Buscar una variable por nombre
  # ─────────────────────────────────────────────────────────────────────────
  # Busca primero en el scope actual; si no la encuentra, busca en el padre.
  # Retorna nil si la variable no existe en ningún nivel de la cadena.
  def get(name)
    value = @store[name]

    # Si no está en este scope y hay un entorno padre, lo buscamos allá
    if value.nil? && @outer
      value = @outer.get(name)
    end

    value
  end


  # ─────────────────────────────────────────────────────────────────────────
  # SET — Asignar una variable en el scope ACTUAL
  # ─────────────────────────────────────────────────────────────────────────
  # Siempre guarda en el scope actual (no sube a entornos padres).
  # Retorna el valor asignado (conveniente para encadenamiento).
  def set(name, value)
    @store[name] = value
    value
  end


  # ─────────────────────────────────────────────────────────────────────────
  # UPDATE — Actualizar una variable ya existente (para reasignación)
  # ─────────────────────────────────────────────────────────────────────────
  # Busca el scope donde la variable fue definida y la actualiza ahí.
  # Si no existe en ningún nivel, la crea en el scope actual.
  # Esto permite que un bucle for actualice su variable de iteración.
  def update(name, value)
    if @store.key?(name)
      @store[name] = value
    elsif @outer
      @outer.update(name, value)
    else
      # Si no existe en ningún nivel, la creamos aquí
      @store[name] = value
    end
    value
  end


  # ─────────────────────────────────────────────────────────────────────────
  # NEW_ENCLOSED — Crear un nuevo scope anidado (para funciones y bloques)
  # ─────────────────────────────────────────────────────────────────────────
  # Retorna un nuevo Environment cuyo padre es el entorno actual.
  # Se usa al llamar una función: la función obtiene su propio scope
  # pero puede leer variables del scope donde fue DEFINIDA (clausura).
  def self.new_enclosed(outer)
    new(outer)
  end


  # ─────────────────────────────────────────────────────────────────────────
  # TO_S — Representación del entorno (útil para debug)
  # ─────────────────────────────────────────────────────────────────────────
  def to_s
    pairs = @store.map { |k, v| "#{k} = #{v.inspect_value}" }
    "{#{pairs.join(', ')}}"
  end
end
