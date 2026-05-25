# =============================================================================
# evaluator.rb — Evaluador del AST
#
# El Evaluador es la última etapa del intérprete. Recibe el AST producido
# por el Parser y lo "ejecuta" recorriéndolo de forma recursiva.
#
# Cada nodo del AST produce un BaseObject como resultado.
#
# Flujo general:
#   código fuente
#     → Lexer  → tokens
#     → Parser → AST
#     → Evaluator + Environment → resultado
#
# Nodos soportados:
#   Program, LetStatement, ReturnStatement, ExpressionStatement,
#   BlockStatement, WhileStatement, ForStatement, BreakStatement,
#   ContinueStatement, PrintStatement, Identifier,
#   IntegerLiteral, FloatLiteral, StringLiteral, BooleanLiteral,
#   PrefixExpression, InfixExpression,
#   IfExpression, FunctionLiteral, CallExpression
# =============================================================================

require_relative 'object'
require_relative 'environment'


class Evaluator

  # ─────────────────────────────────────────────────────────────────────────
  # MÉTODO PRINCIPAL — dispatch por tipo de nodo
  # ─────────────────────────────────────────────────────────────────────────
  def evaluate(node, env)
    case node

    # ── Nodo raíz ──────────────────────────────────────────────────────────
    when Program
      evaluate_program(node, env)

    # ── Sentencias ─────────────────────────────────────────────────────────
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
      BREAK_OBJ

    when ContinueStatement
      CONTINUE_OBJ

    when PrintStatement
      evaluate_print_statement(node, env)

    # ── Literales ──────────────────────────────────────────────────────────
    when IntegerLiteral
      IntegerObject.new(node.value)

    when FloatLiteral
      FloatObject.new(node.value)

    when StringLiteral
      StringObject.new(node.value)

    when BooleanLiteral
      native_bool_to_obj(node.value)

    # ── Expresiones ────────────────────────────────────────────────────────
    when Identifier
      evaluate_identifier(node, env)

    when PrefixExpression
      right = evaluate(node.right, env)
      return right if error?(right)
      evaluate_prefix_expression(node.operator, right)

    when InfixExpression
      left = evaluate(node.left, env)
      return left if error?(left)
      right = evaluate(node.right, env)
      return right if error?(right)
      evaluate_infix_expression(node.operator, left, right)

    when IfExpression
      evaluate_if_expression(node, env)

    when FunctionLiteral
      # La función captura el entorno actual → clausura
      FunctionObject.new(node.parameters, node.body, env)

    when CallExpression
      evaluate_call_expression(node, env)

    else
      new_error("Tipo de nodo desconocido: #{node.class}")
    end
  end


  # ===========================================================================
  # EVALUACIÓN DEL PROGRAMA (nodo raíz)
  # ===========================================================================
  private

  def evaluate_program(program, env)
    result = NULL_OBJ

    program.statements.each do |statement|
      result = evaluate(statement, env)

      # Si encontramos un return, desenvolvemos el valor y detenemos
      return result.value if result.is_a?(ReturnValue)

      # Si hay un error, lo propagamos inmediatamente
      return result if error?(result)
    end

    result
  end


  # ===========================================================================
  # LET STATEMENT — asignoasigno x = expr;
  # ===========================================================================
  def evaluate_let_statement(node, env)
    value = if node.value
              evaluate(node.value, env)
            else
              NULL_OBJ
            end

    return value if error?(value)

    env.set(node.name.value, value)
    NULL_OBJ    # let no produce un valor visible
  end


  # ===========================================================================
  # RETURN STATEMENT — retornable_como_la_cocacola_retornable expr;
  # ===========================================================================
  def evaluate_return_statement(node, env)
    value = if node.return_value
              evaluate(node.return_value, env)
            else
              NULL_OBJ
            end

    return value if error?(value)

    ReturnValue.new(value)
  end


  # ===========================================================================
  # BLOCK STATEMENT — { stmt; stmt; ... }
  # ===========================================================================
  # A diferencia de evaluate_program, NO desenvuelve el ReturnValue,
  # lo deja burbujear hasta que llega al nivel de la función.
  def evaluate_block_statement(block, env)
    result = NULL_OBJ

    block.statements.each do |statement|
      result = evaluate(statement, env)

      # Dejamos que ReturnValue, ErrorObject, BreakSignal y ContinueSignal
      # se propaguen sin procesarlos aquí
      if result.is_a?(ReturnValue)  ||
         error?(result)             ||
         result.is_a?(BreakSignal)  ||
         result.is_a?(ContinueSignal)
        return result
      end
    end

    result
  end


  # ===========================================================================
  # WHILE — primero_miremos_aver_sisi (cond) { body }
  # ===========================================================================
  def evaluate_while_statement(node, env)
    result = NULL_OBJ

    loop do
      condition = evaluate(node.condition, env)
      return condition if error?(condition)

      break unless truthy?(condition)

      result = evaluate_block_statement(node.body, env)

      # Propagamos errores y returns
      return result if error?(result) || result.is_a?(ReturnValue)

      # break detiene el bucle
      break if result.is_a?(BreakSignal)

      # continue simplemente salta a la siguiente iteración (el loop continúa)
      next if result.is_a?(ContinueSignal)
    end

    NULL_OBJ
  end


  # ===========================================================================
  # FOR — parapapapa (init; cond; update) { body }
  # ===========================================================================
  def evaluate_for_statement(node, env)
    # El for tiene su propio scope para que la variable de init no escape
    for_env = Environment.new_enclosed(env)

    # 1. Inicialización (puede ser nil)
    if node.init
      init_result = evaluate(node.init, for_env)
      return init_result if error?(init_result)
    end

    loop do
      # 2. Condición (si es nil, bucle infinito hasta break/return)
      if node.condition
        condition = evaluate(node.condition, for_env)
        return condition if error?(condition)
        break unless truthy?(condition)
      end

      # 3. Cuerpo
      body_result = evaluate_block_statement(node.body, for_env)

      return body_result if error?(body_result) || body_result.is_a?(ReturnValue)
      break             if body_result.is_a?(BreakSignal)
      # continue: no hacemos break ni return, solo dejamos que llegue el update

      # 4. Actualización (puede ser nil)
      if node.update
        update_result = evaluate(node.update, for_env)
        return update_result if error?(update_result)
      end
    end

    NULL_OBJ
  end


  # ===========================================================================
  # PRINT — imprimiendoendo(expr);
  # ===========================================================================
  def evaluate_print_statement(node, env)
    value = evaluate(node.value, env)
    return value if error?(value)

    puts value.inspect_value
    NULL_OBJ
  end


  # ===========================================================================
  # IDENTIFIER — buscar variable en el entorno
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
  # PREFIX EXPRESSION — !expr  o  -expr  o  sqrt(expr)
  # ===========================================================================
  def evaluate_prefix_expression(operator, right)
    case operator
    when '!'
      evaluate_bang_operator(right)

    when '-'
      evaluate_minus_prefix(right)

    # Raíz cuadrada: lahijadelahija
    when 'lahijadelahija'
      case right
      when IntegerObject
        FloatObject.new(Math.sqrt(right.value))
      when FloatObject
        FloatObject.new(Math.sqrt(right.value))
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
    else                FALSE_OBJ   # Cualquier valor no-nulo es "truthy"
    end
  end

  def evaluate_minus_prefix(right)
    case right
    when IntegerObject
      IntegerObject.new(-right.value)
    when FloatObject
      FloatObject.new(-right.value)
    else
      new_error("Operador '-' no aplica a #{right.object_type}")
    end
  end


  # ===========================================================================
  # INFIX EXPRESSION — left OP right
  # ===========================================================================
  def evaluate_infix_expression(operator, left, right)
    # Operadores lógicos con cortocircuito
    case operator
    when 'Y_un_guarito', '&&'
      return native_bool_to_obj(truthy?(left) && truthy?(right))
    when 'O_una_polita', '||'
      return native_bool_to_obj(truthy?(left) || truthy?(right))
    end

    # Igualdad y diferencia (funcionan para todos los tipos)
    if operator == '=='
      return boolean_equals(left, right)
    elsif operator == '!='
      return boolean_not_equals(left, right)
    end

    # Operadores aritméticos y relacionales según los tipos
    if left.is_a?(IntegerObject) && right.is_a?(IntegerObject)
      evaluate_integer_infix(operator, left, right)

    elsif left.is_a?(FloatObject) || right.is_a?(FloatObject)
      # Si alguno es float, promovemos el entero a float
      l_val = left.is_a?(IntegerObject)  ? left.value.to_f  : left.value
      r_val = right.is_a?(IntegerObject) ? right.value.to_f : right.value
      l_obj = FloatObject.new(l_val)
      r_obj = FloatObject.new(r_val)
      evaluate_float_infix(operator, l_obj, r_obj)

    elsif left.is_a?(StringObject) && right.is_a?(StringObject)
      evaluate_string_infix(operator, left, right)

    elsif left.object_type != right.object_type
      new_error("Tipos incompatibles: #{left.object_type} #{operator} #{right.object_type}")

    else
      new_error("Operador desconocido: #{left.object_type} #{operator} #{right.object_type}")
    end
  end

  # ── Aritmética entera ────────────────────────────────────────────────────
  def evaluate_integer_infix(operator, left, right)
    l = left.value
    r = right.value

    case operator
    when '+', 'adicao'
      IntegerObject.new(l + r)
    when '-', 'subtracao'
      IntegerObject.new(l - r)
    when '*'
      IntegerObject.new(l * r)
    when '/', 'divisao'
      return new_error("División por cero") if r == 0
      IntegerObject.new(l / r)
    when '%'
      return new_error("Módulo por cero") if r == 0
      IntegerObject.new(l % r)
    when '^', 'lamamadelamamadelamamadelamamadelamama'
      IntegerObject.new(l ** r)
    # Raíz n-ésima: lahijadelahijadelahijadelahijadelahija
    when 'lahijadelahijadelahijadelahijadelahija'
      return new_error("Índice de raíz debe ser > 0") if r <= 0
      FloatObject.new(l ** (1.0 / r))
    when '<', 'no_me_importa_que_usted_sea_menor_que_yo'
      native_bool_to_obj(l < r)
    when '<='
      native_bool_to_obj(l <= r)
    when '>', 'no_me_importa_que_usted_sea_mayor_que_yo_yo_la_quiero_en_mi_cama'
      native_bool_to_obj(l > r)
    when '>='
      native_bool_to_obj(l >= r)
    else
      new_error("Operador desconocido para INTEGER: #{operator}")
    end
  end

  # ── Aritmética flotante ──────────────────────────────────────────────────
  def evaluate_float_infix(operator, left, right)
    l = left.value
    r = right.value

    case operator
    when '+', 'adicao'
      FloatObject.new(l + r)
    when '-', 'subtracao'
      FloatObject.new(l - r)
    when '*'
      FloatObject.new(l * r)
    when '/', 'divisao'
      return new_error("División por cero") if r == 0.0
      FloatObject.new(l / r)
    when '%'
      return new_error("Módulo por cero") if r == 0.0
      FloatObject.new(l % r)
    when '^', 'lamamadelamamadelamamadelamamadelamama'
      FloatObject.new(l ** r)
    when 'lahijadelahijadelahijadelahijadelahija'
      return new_error("Índice de raíz debe ser > 0") if r <= 0
      FloatObject.new(l ** (1.0 / r))
    when '<', 'no_me_importa_que_usted_sea_menor_que_yo'
      native_bool_to_obj(l < r)
    when '<='
      native_bool_to_obj(l <= r)
    when '>', 'no_me_importa_que_usted_sea_mayor_que_yo_yo_la_quiero_en_mi_cama'
      native_bool_to_obj(l > r)
    when '>='
      native_bool_to_obj(l >= r)
    else
      new_error("Operador desconocido para FLOAT: #{operator}")
    end
  end

  # ── Operaciones con strings ──────────────────────────────────────────────
  def evaluate_string_infix(operator, left, right)
    case operator
    when '+', 'adicao'
      StringObject.new(left.value + right.value)
    when '<'
      native_bool_to_obj(left.value < right.value)
    when '>'
      native_bool_to_obj(left.value > right.value)
    else
      new_error("Operador no soportado para STRING: #{operator}")
    end
  end

  # ── Igualdad universal (compara el valor, no la referencia) ─────────────
  def boolean_equals(left, right)
    case [left.object_type, right.object_type]
    when [ObjectType::BOOLEAN, ObjectType::BOOLEAN]
      native_bool_to_obj(left.value == right.value)
    when [ObjectType::INTEGER, ObjectType::INTEGER]
      native_bool_to_obj(left.value == right.value)
    when [ObjectType::FLOAT,   ObjectType::FLOAT]
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
  # IF EXPRESSION — si_se_porta_bien... / si_no_se_porta_bien_entonces... / si_no...
  # ===========================================================================
  def evaluate_if_expression(node, env)
    condition = evaluate(node.condition, env)
    return condition if error?(condition)

    if truthy?(condition)
      evaluate(node.consequence, env)

    elsif node.alternatives && !node.alternatives.empty?
      # Recorremos las ramas elseif en orden
      node.alternatives.each do |alt_condition, alt_block|
        cond_result = evaluate(alt_condition, env)
        return cond_result if error?(cond_result)

        if truthy?(cond_result)
          return evaluate(alt_block, env)
        end
      end

      # Ninguna rama elseif fue verdadera, vamos al else (si existe)
      if node.else_block
        evaluate(node.else_block, env)
      else
        NULL_OBJ
      end

    elsif node.else_block
      evaluate(node.else_block, env)

    else
      NULL_OBJ
    end
  end


  # ===========================================================================
  # CALL EXPRESSION — función(arg1, arg2, ...)
  # ===========================================================================
  def evaluate_call_expression(node, env)
    # 1. Evaluar la expresión que debe producir una función
    function = evaluate(node.function, env)
    return function if error?(function)

    unless function.is_a?(FunctionObject)
      return new_error("No es una función: #{function.object_type}")
    end

    # 2. Evaluar los argumentos
    args = evaluate_expressions(node.arguments, env)
    return args.first if args.length == 1 && error?(args.first)

    # 3. Verificar que el número de argumentos coincida
    if args.length != function.parameters.length
      return new_error(
        "Argumentos incorrectos: se esperaban #{function.parameters.length}, " \
        "se recibieron #{args.length}"
      )
    end

    # 4. Crear entorno de la llamada extendiendo el entorno de CLAUSURA
    call_env = extend_function_env(function, args)

    # 5. Evaluar el cuerpo de la función
    result = evaluate(function.body, call_env)

    # 6. Desenvolver el ReturnValue para que no se propague fuera de la función
    result.is_a?(ReturnValue) ? result.value : result
  end

  # Evalúa una lista de expresiones y retorna una lista de objetos
  def evaluate_expressions(expressions, env)
    result = []

    expressions.each do |expr|
      val = evaluate(expr, env)
      return [val] if error?(val)
      result << val
    end

    result
  end

  # Crea un nuevo entorno con los parámetros ligados a los argumentos
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

  # Convierte un booleano de Ruby en el singleton TRUE_OBJ o FALSE_OBJ
  def native_bool_to_obj(value)
    value ? TRUE_OBJ : FALSE_OBJ
  end

  # Determina si un objeto es "verdadero" en este lenguaje
  # Falso: false y null. Todo lo demás es verdadero (incluyendo 0).
  def truthy?(obj)
    case obj
    when NULL_OBJ  then false
    when TRUE_OBJ  then true
    when FALSE_OBJ then false
    else                true
    end
  end

  # Verifica si un objeto es un ErrorObject
  def error?(obj)
    obj.is_a?(ErrorObject)
  end

  # Crea un nuevo ErrorObject con un mensaje formateado
  def new_error(message)
    ErrorObject.new(message)
  end
end
