# =============================================================================
# environment.rb — Entorno de Variables (Scope)
#
# FIXES APLICADOS:
#   VULN-21: exists_in_current_scope? para detectar redeclaraciones
# =============================================================================

class Environment
  def initialize(outer = nil)
    @store = {}
    @outer = outer
  end

  def get(name)
    value = @store[name]
    if value.nil? && @outer
      value = @outer.get(name)
    end
    value
  end

  def set(name, value)
    @store[name] = value
    value
  end

  def update(name, value)
    if @store.key?(name)
      @store[name] = value
    elsif @outer
      @outer.update(name, value)
    else
      @store[name] = value
    end
    value
  end

  # [FIX VULN-21] Permite verificar si una variable ya existe en el scope ACTUAL
  # (sin subir a scopes padres), para detectar redeclaraciones
  def exists_in_current_scope?(name)
    @store.key?(name)
  end

  def self.new_enclosed(outer)
    new(outer)
  end

  def to_s
    pairs = @store.map { |k, v| "#{k} = #{v.inspect_value}" }
    "{#{pairs.join(', ')}}"
  end
end
