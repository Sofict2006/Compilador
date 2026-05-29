# =============================================================================
# repl.rb — Read-Eval-Print Loop
#
# Bucle interactivo que:
#   1. Lee una entrada del usuario
#   2. La procesa con el Lexer → Parser → Evaluador
#   3. Imprime el resultado
#   4. Repite hasta que el usuario escriba el comando de salir
# =============================================================================

require_relative 'lexer'
require_relative 'tokens'
require_relative 'parser'
require_relative 'evaluator'
require_relative 'environment'

def start_repl
  # Creamos un entorno global que persiste entre líneas del REPL
  env = Environment.new
  evaluator = Evaluator.new

  while (print(">> "); source = gets.chomp) != 'ya me voy amiguitos'
    # Se crea una instancia del lexer con el texto ingresado
    lexer = Lexer.new(source)

    # Se crea el parser y se parsea el programa
    parser = Parser.new(lexer)
    program = parser.parse_program

    # Si hay errores de parseo, los mostramos
    if parser.errors.any?
      parser.errors.each do |error|
        puts "  ERROR DE PARSEO: #{error}"
      end
      next
    end

    # Evaluamos el programa
    result = evaluator.evaluate(program, env)

    # Imprimimos el resultado (si no es null)
    if result && !result.is_a?(NullObject)
      puts result.inspect_value
    end
  end
end
