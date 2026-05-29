# =============================================================================
# main.rb — Punto de entrada del compilador
#
# Soporta dos modos:
#   1. REPL interactivo: ruby main.rb
#   2. Ejecutar archivo:  ruby main.rb archivo.txt
# =============================================================================

require_relative 'Lenguaje_Programacion/lexer'
require_relative 'Lenguaje_Programacion/parser'
require_relative 'Lenguaje_Programacion/evaluator'
require_relative 'Lenguaje_Programacion/environment'
require_relative 'Lenguaje_Programacion/repl'

def run_file(filename)
  unless File.exist?(filename)
    puts "Error: No se encontró el archivo '#{filename}'"
    return
  end

  source = File.read(filename)
  lexer = Lexer.new(source)
  parser = Parser.new(lexer)
  program = parser.parse_program

  if parser.errors.any?
    puts "Errores de parseo:"
    parser.errors.each { |e| puts "  #{e}" }
    return
  end

  env = Environment.new
  evaluator = Evaluator.new
  result = evaluator.evaluate(program, env)

  if result.is_a?(ErrorObject)
    puts result.inspect_value
  end
end

def main
  puts "Maldito talento"

  if ARGV.length > 0
    # Modo archivo
    run_file(ARGV[0])
  else
    # Modo REPL interactivo
    start_repl
  end
end

if __FILE__ == $0
  main
end