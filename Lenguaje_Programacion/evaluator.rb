# =============================================================================
# evaluator.rb — Evaluador del AST
#
# FIXES APLICADOS:
#   VULN-01: Límite de profundidad de recursión (MAX_CALL_DEPTH = 500)
#   VULN-03: División flotante: check correcto + detección de Infinity/NaN
#   VULN-04: Math.sqrt valida que el argumento no sea negativo
#   VULN-05: Potencia con exponente negativo produce Float, no Rational
#   VULN-07: break/continue fuera de bucle producen error explícito
#   VULN-08: @loop_depth rastrea profundidad de bucle
#   VULN-09: Cortocircuito real en Y_un_guarito / O_una_polita
#   VULN-10: Comparación == entre INTEGER y FLOAT funciona correctamente
#   VULN-11: Concatenación string + número con coerción implícita
#   VULN-12: return en nivel global emite advertencia
#   VULN-18: for sin condición tiene límite de iteraciones de seguridad
#   VULN-21: asignoasigno advierte si la variable ya existía en el scope
# =============================================================================

require_relative 'object'
require_relative 'environment'

# Límites de seguridad
MAX_CALL_DEPTH  = 500
MAX_ITERATIONS  = 1_000_000

class Evaluator

  def initialize
    @call_depth = 0   # [FIX VULN-01]
    @loop_depth = 0   # [FIX VULN-08]
  end

  # ─────────────────────────────────────────────────────────────────────────
  # MÉTODO PRINCIPAL — dispatch por tipo de nodo
  # ─────────────────────────────────────────────────────────────────────────
  def evaluate(node, env)
    case node

    when Program
      evaluate_program(node, env)

    when ExpressionStatement
      evaluate(node.expression, env)

    when LetStatement
      evaluate_let_statement(node, env)

    when ReturnStatement
      evaluate_return_statement(node, env)

    when BlockStatement
      evaluate_block_statement(node, env)

    when WhileStatement
      evaluate_while_statement(node, env)

    when ForStatement
      evaluate_for_statement(node, env)

    when BreakStatement
      # [FIX VULN-08] break fuera de bucle es un error
      if @loop_depth == 0
        return new_error("'detente_jochis' solo se puede usar dentro de un bucle")
      end
      BREAK_OBJ

    when ContinueStatement
      # [FIX VULN-08] continue fuera de bucle es un error
      if @loop_depth == 0
        return new_error("'noparesiguesigue_noparesiguesigue' solo se puede usar dentro de un bucle")
      end
      CONTINUE_OBJ

    when PrintStatement
      evaluate_print_statement(node, env)

    when IntegerLiteral
      IntegerObject.new(node.value)

    when FloatLiteral
      FloatObject.new(node.value)

    when StringLiteral
      StringObject.new(node.value)

    when BooleanLiteral
      native_bool_to_obj(node.value)

    when Identifier
      evaluate_identifier(node, env)

    when PrefixExpression
      right = evaluate(node.right, env)
      return right if error?(right)
      evaluate_prefix_expression(node.operator, right)

    when InfixExpression
      # [FIX VULN-09] Cortocircuito real: evaluamos derecha SOLO si es necesario
      op = node.operator
      if op == 'Y_un_guarito' || op == '&&'
        left = evaluate(node.left, env)
        return left if error?(left)
        return FALSE_OBJ unless truthy?(left)
        right = evaluate(node.right, env)
        return right if error?(right)
        return native_bool_to_obj(truthy?(right))
      elsif op == 'O_una_polita' || op == '||'
        left = evaluate(node.left, env)
        return left if error?(left)
        return TRUE_OBJ if truthy?(left)
        right = evaluate(node.right, env)
        return right if error?(right)
        return native_bool_to_obj(truthy?(right))
      end

      left  = evaluate(node.left, env)
      return left if error?(left)
      right = evaluate(node.right, env)
      return right if error?(right)
      evaluate_infix_expression(node.operator, left, right)

    when IfExpression
      evaluate_if_expression(node, env)

    when FunctionLiteral
      FunctionObject.new(node.parameters, node.body, env)

    when CallExpression
      evaluate_call_expression(node, env)

    else
      new_error("Tipo de nodo desconocido: #{node.class}")
    end
  end


  # ===========================================================================
  # PROGRAMA (nodo raíz)
  # ===========================================================================
  private

  def evaluate_program(program, env)
    result = NULL_OBJ

    program.statements.each do |statement|
      result = evaluate(statement, env)

      if result.is_a?(ReturnValue)
        # [FIX VULN-12] return en nivel global: advertencia y fin del programa
        $stderr.puts "Advertencia: 'retornable_como_la_cocacola_retornable' usado fuera de una función. El programa termina aquí."
        return result.value
      end

      return result if error?(result)
    end

    result
  end


  # ===========================================================================
  # LET STATEMENT
  # ===========================================================================
  def evaluate_let_statement(node, env)
    value = node.value ? evaluate(node.value, env) : NULL_OBJ
    return value if error?(value)

    # [FIX VULN-21] Advertencia solo en scope global para evitar ruido en bucles
    # (el lenguaje usa asignoasigno para reasignar, lo cual es normal en loops)
    if @loop_depth == 0 && @call_depth == 0 && env.exists_in_current_scope?(node.name.value)
      $stderr.puts "Advertencia: '#{node.name.value}' ya fue declarada (se sobreescribe el valor anterior)."
    end

    env.set(node.name.value, value)
    NULL_OBJ
  end


  # ===========================================================================
  # RETURN STATEMENT
  # ===========================================================================
  def evaluate_return_statement(node, env)
    value = node.return_value ? evaluate(node.return_value, env) : NULL_OBJ
    return value if error?(value)
    ReturnValue.new(value)
  end


  # ===========================================================================
  # BLOCK STATEMENT
  # ===========================================================================
  def evaluate_block_statement(block, env)
    result = NULL_OBJ

    block.statements.each do |statement|
      result = evaluate(statement, env)
      if result.is_a?(ReturnValue) ||
         error?(result)             ||
         result.is_a?(BreakSignal)  ||
         result.is_a?(ContinueSignal)
        return result
      end
    end

    result
  end


  # ===========================================================================
  # WHILE
  # ===========================================================================
  def evaluate_while_statement(node, env)
    result     = NULL_OBJ
    iterations = 0

    @loop_depth += 1   # [FIX VULN-08]
    loop do
      # [FIX VULN-18] Límite de iteraciones de seguridad
      iterations += 1
      if iterations > MAX_ITERATIONS
        @loop_depth -= 1
        return new_error("Límite de iteraciones alcanzado (#{MAX_ITERATIONS}). ¿Bucle infinito?")
      end

      condition = evaluate(node.condition, env)
      if error?(condition)
        @loop_depth -= 1
        return condition
      end
      break unless truthy?(condition)

      result = evaluate_block_statement(node.body, env)

      if error?(result) || result.is_a?(ReturnValue)
        @loop_depth -= 1
        return result
      end
      break if result.is_a?(BreakSignal)
      next  if result.is_a?(ContinueSignal)
    end
    @loop_depth -= 1

    NULL_OBJ
  end


  # ===========================================================================
  # FOR
  # ===========================================================================
  def evaluate_for_statement(node, env)
    for_env    = Environment.new_enclosed(env)
    iterations = 0

    if node.init
      init_result = evaluate(node.init, for_env)
      return init_result if error?(init_result)
    end

    @loop_depth += 1   # [FIX VULN-08]
    loop do
      # [FIX VULN-18] Límite de seguridad para for sin condición
      iterations += 1
      if iterations > MAX_ITERATIONS
        @loop_depth -= 1
        return new_error("Límite de iteraciones alcanzado (#{MAX_ITERATIONS}). ¿Bucle infinito?")
      end

      if node.condition
        condition = evaluate(node.condition, for_env)
        if error?(condition)
          @loop_depth -= 1
          return condition
        end
        break unless truthy?(condition)
      end

      body_result = evaluate_block_statement(node.body, for_env)

      if error?(body_result) || body_result.is_a?(ReturnValue)
        @loop_depth -= 1
        return body_result
      end
      if body_result.is_a?(BreakSignal)
        @loop_depth -= 1
        break
      end

      if node.update
        update_result = evaluate(node.update, for_env)
        if error?(update_result)
          @loop_depth -= 1
          return update_result
        end
      end
    end
    @loop_depth -= 1

    NULL_OBJ
  end


  # ===========================================================================
  # PRINT
  # ===========================================================================
  def evaluate_print_statement(node, env)
    value = evaluate(node.value, env)
    return value if error?(value)
    puts value.inspect_value
    NULL_OBJ
  end


  # ===========================================================================
  # IDENTIFIER
  # ===========================================================================
  def evaluate_identifier(node, env)
    value = env.get(node.value)
    if value.nil?
      new_error("Variable no definida: '#{node.value}'")
    else
      value
    end
  end


  # ===========================================================================
  # PREFIX EXPRESSION
  # ===========================================================================
  def evaluate_prefix_expression(operator, right)
    case operator
    when '!'
      evaluate_bang_operator(right)
    when '-'
      evaluate_minus_prefix(right)
    when 'lahijadelahija'
      # [FIX VULN-04] Validar que el argumento no sea negativo antes de Math.sqrt
      case right
      when IntegerObject, FloatObject
        val = right.value.to_f
        return new_error("Raíz cuadrada de número negativo no está definida: #{val}") if val < 0
        FloatObject.new(Math.sqrt(val))
      else
        new_error("Operador 'lahijadelahija' no aplica a #{right.object_type}")
      end
    else
      new_error("Operador prefijo desconocido: #{operator}#{right.object_type}")
    end
  end

  def evaluate_bang_operator(right)
    case right
    when TRUE_OBJ  then FALSE_OBJ
    when FALSE_OBJ then TRUE_OBJ
    when NULL_OBJ  then TRUE_OBJ
    else                FALSE_OBJ
    end
  end

  def evaluate_minus_prefix(right)
    case right
    when IntegerObject then IntegerObject.new(-right.value)
    when FloatObject   then FloatObject.new(-right.value)
    else new_error("Operador '-' no aplica a #{right.object_type}")
    end
  end


  # ===========================================================================
  # INFIX EXPRESSION
  # ===========================================================================
  def evaluate_infix_expression(operator, left, right)
    # [FIX VULN-10] Comparación cruzada INTEGER == FLOAT
    if operator == '=='
      return boolean_equals(left, right)
    elsif operator == '!='
      return boolean_not_equals(left, right)
    end

    if left.is_a?(IntegerObject) && right.is_a?(IntegerObject)
      evaluate_integer_infix(operator, left, right)

    elsif left.is_a?(FloatObject) || right.is_a?(FloatObject)
      l_val = left.is_a?(IntegerObject)  ? left.value.to_f  : left.value
      r_val = right.is_a?(IntegerObject) ? right.value.to_f : right.value
      evaluate_float_infix(operator, FloatObject.new(l_val), FloatObject.new(r_val))

    elsif left.is_a?(StringObject) && right.is_a?(StringObject)
      evaluate_string_infix(operator, left, right)

    # [FIX VULN-11] Coerción implícita String + número
    elsif left.is_a?(StringObject) && (right.is_a?(IntegerObject) || right.is_a?(FloatObject))
      if operator == '+'
        StringObject.new(left.value + right.inspect_value)
      else
        new_error("Operador '#{operator}' no soportado entre STRING y #{right.object_type}")
      end
    elsif (left.is_a?(IntegerObject) || left.is_a?(FloatObject)) && right.is_a?(StringObject)
      if operator == '+'
        StringObject.new(left.inspect_value + right.value)
      else
        new_error("Operador '#{operator}' no soportado entre #{left.object_type} y STRING")
      end

    elsif left.object_type != right.object_type
      new_error("Tipos incompatibles: #{left.object_type} #{operator} #{right.object_type}")
    else
      new_error("Operador desconocido: #{left.object_type} #{operator} #{right.object_type}")
    end
  end

  # ── Aritmética entera ───────────────────────────────────────────────────
  def evaluate_integer_infix(operator, left, right)
    l = left.value
    r = right.value

    case operator
    when '+', 'adicao'    then IntegerObject.new(l + r)
    when '-', 'subtracao' then IntegerObject.new(l - r)
    when '*'              then IntegerObject.new(l * r)
    when '/', 'divisao'
      return new_error("División por cero") if r == 0
      IntegerObject.new(l / r)
    when '%'
      return new_error("Módulo por cero") if r == 0
      IntegerObject.new(l % r)
    when '^', 'lamamadelamamadelamamadelamamadelamama'
      # [FIX VULN-05] Exponente negativo → resultado Float, no Rational
      if r < 0
        FloatObject.new(l.to_f ** r)
      else
        IntegerObject.new(l ** r)
      end
    when 'lahijadelahijadelahijadelahijadelahija'
      return new_error("Índice de raíz debe ser > 0") if r <= 0
      FloatObject.new(l ** (1.0 / r))
    when '<',  'no_me_importa_que_usted_sea_menor_que_yo' then native_bool_to_obj(l < r)
    when '<='                                              then native_bool_to_obj(l <= r)
    when '>',  'no_me_importa_que_usted_sea_mayor_que_yo_yo_la_quiero_en_mi_cama' then native_bool_to_obj(l > r)
    when '>='                                              then native_bool_to_obj(l >= r)
    else new_error("Operador desconocido para INTEGER: #{operator}")
    end
  end

  # ── Aritmética flotante ─────────────────────────────────────────────────
  def evaluate_float_infix(operator, left, right)
    l = left.value
    r = right.value

    case operator
    when '+', 'adicao'    then FloatObject.new(l + r)
    when '-', 'subtracao' then FloatObject.new(l - r)
    when '*'              then FloatObject.new(l * r)
    when '/', 'divisao'
      # [FIX VULN-03] check robusto: zero? cubre 0.0, y detectamos Infinity/NaN post-op
      return new_error("División por cero") if r.zero?
      result = l / r
      return new_error("Resultado no válido (Infinity)") if result.infinite?
      return new_error("Resultado no válido (NaN)")      if result.nan?
      FloatObject.new(result)
    when '%'
      return new_error("Módulo por cero") if r.zero?
      FloatObject.new(l % r)
    when '^', 'lamamadelamamadelamamadelamamadelamama'
      FloatObject.new(l ** r)
    when 'lahijadelahijadelahijadelahijadelahija'
      return new_error("Índice de raíz debe ser > 0") if r <= 0
      FloatObject.new(l ** (1.0 / r))
    when '<',  'no_me_importa_que_usted_sea_menor_que_yo' then native_bool_to_obj(l < r)
    when '<='                                              then native_bool_to_obj(l <= r)
    when '>',  'no_me_importa_que_usted_sea_mayor_que_yo_yo_la_quiero_en_mi_cama' then native_bool_to_obj(l > r)
    when '>='                                              then native_bool_to_obj(l >= r)
    else new_error("Operador desconocido para FLOAT: #{operator}")
    end
  end

  # ── Strings ─────────────────────────────────────────────────────────────
  def evaluate_string_infix(operator, left, right)
    case operator
    when '+', 'adicao' then StringObject.new(left.value + right.value)
    when '<'           then native_bool_to_obj(left.value < right.value)
    when '>'           then native_bool_to_obj(left.value > right.value)
    else new_error("Operador no soportado para STRING: #{operator}")
    end
  end

  # [FIX VULN-10] Comparación cruzada INTEGER ↔ FLOAT
  def boolean_equals(left, right)
    # Si ambos son numéricos, comparar el valor numéricamente
    if (left.is_a?(IntegerObject) || left.is_a?(FloatObject)) &&
       (right.is_a?(IntegerObject) || right.is_a?(FloatObject))
      return native_bool_to_obj(left.value == right.value)
    end

    case [left.object_type, right.object_type]
    when [ObjectType::BOOLEAN, ObjectType::BOOLEAN]
      native_bool_to_obj(left.value == right.value)
    when [ObjectType::STRING,  ObjectType::STRING]
      native_bool_to_obj(left.value == right.value)
    when [ObjectType::NULL,    ObjectType::NULL]
      TRUE_OBJ
    else
      FALSE_OBJ
    end
  end

  def boolean_not_equals(left, right)
    result = boolean_equals(left, right)
    result == TRUE_OBJ ? FALSE_OBJ : TRUE_OBJ
  end


  # ===========================================================================
  # IF EXPRESSION
  # ===========================================================================
  def evaluate_if_expression(node, env)
    condition = evaluate(node.condition, env)
    return condition if error?(condition)

    if truthy?(condition)
      evaluate(node.consequence, env)
    elsif node.alternatives && !node.alternatives.empty?
      node.alternatives.each do |alt_condition, alt_block|
        cond_result = evaluate(alt_condition, env)
        return cond_result if error?(cond_result)
        return evaluate(alt_block, env) if truthy?(cond_result)
      end
      node.else_block ? evaluate(node.else_block, env) : NULL_OBJ
    elsif node.else_block
      evaluate(node.else_block, env)
    else
      NULL_OBJ
    end
  end


  # ===========================================================================
  # CALL EXPRESSION
  # ===========================================================================
  def evaluate_call_expression(node, env)
    # [FIX VULN-01] Límite de profundidad de llamadas
    @call_depth += 1
    if @call_depth > MAX_CALL_DEPTH
      @call_depth -= 1
      return new_error("Stack overflow: profundidad máxima de llamadas (#{MAX_CALL_DEPTH}) superada. ¿Recursión infinita?")
    end

    function = evaluate(node.function, env)
    if error?(function)
      @call_depth -= 1
      return function
    end

    unless function.is_a?(FunctionObject)
      @call_depth -= 1
      return new_error("No es una función: #{function.object_type}")
    end

    args = evaluate_expressions(node.arguments, env)
    if args.length == 1 && error?(args.first)
      @call_depth -= 1
      return args.first
    end

    if args.length != function.parameters.length
      @call_depth -= 1
      return new_error(
        "Argumentos incorrectos: se esperaban #{function.parameters.length}, " \
        "se recibieron #{args.length}"
      )
    end

    call_env = extend_function_env(function, args)
    result   = evaluate(function.body, call_env)
    @call_depth -= 1

    result.is_a?(ReturnValue) ? result.value : result
  end

  def evaluate_expressions(expressions, env)
    result = []
    expressions.each do |expr|
      val = evaluate(expr, env)
      return [val] if error?(val)
      result << val
    end
    result
  end

  def extend_function_env(function, args)
    env = Environment.new_enclosed(function.env)
    function.parameters.each_with_index do |param, i|
      env.set(param.value, args[i])
    end
    env
  end


  # ===========================================================================
  # UTILIDADES
  # ===========================================================================
  def native_bool_to_obj(value)
    value ? TRUE_OBJ : FALSE_OBJ
  end

  def truthy?(obj)
    case obj
    when NULL_OBJ  then false
    when TRUE_OBJ  then true
    when FALSE_OBJ then false
    else                true
    end
  end

  def error?(obj)
    obj.is_a?(ErrorObject)
  end

  def new_error(message)
    ErrorObject.new(message)
  end
end
