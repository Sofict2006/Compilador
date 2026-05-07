# Importa el archivo repl.rb
# En Ruby se carga todo el archivo, no por funciones
require_relative 'Lenguaje_Programacion/repl'

# Define la función principal del programa
def main
  # Imprime un mensaje en consola
  puts "Maldito talento"
  
  # Llama a la función start_repl definida en repl.rb
  start_repl
end

# Verifica si este archivo es el que se está ejecutando directamente
# __FILE__ = nombre de este archivo
# $0 = archivo que se ejecutó desde la terminal
if __FILE__ == $0
  # Si este archivo es el principal, ejecuta la función main
  main
end