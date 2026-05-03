# Importa la clase Lexer que se encarga de convertir texto en tokens
require_relative 'lexer'
# Importa las estructuras de tokens
require_relative 'tokens'

# Token constante que representa el fin de entrada (EOF)
# Se usa para comparar cuándo detener el procesamiento
EOF_TOKEN = Token.new(TokenType::EOF, '')

def start_repl
    """
    Inicia un REPL (Read-Eval-Print Loop).

    Este bucle:
    1. Lee una entrada del usuario
    2. La procesa con el lexer
    3. Imprime los tokens generados
    4. Repite hasta que el usuario escriba el comando de salir
    """

    # Bucle infinito hasta que el usuario escriba lo de abajo c:
    while (print(">> "); source = gets.chomp) != 'ya me voy amiguitos'
        # Se crea una instancia del lexer con el texto ingresado
        lexer = Lexer.new(source)

        # Se obtienen tokens uno a uno hasta llegar a EOF
        while (token = lexer.next_token) != EOF_TOKEN
            # Imprime cada token generado (debug / visualización)
            puts token
        end
    end
end
