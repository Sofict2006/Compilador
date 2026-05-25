require_relative '../Lenguaje_Programacion/ast'

# ─────────────────────────────────────────────
# Prueba 1 -> (5+3)

# Crear nodos 
left = IntegerLiteral.new(nil, 5)
right = IntegerLiteral.new(nil, 3)

expr = InfixExpression.new(
   nil,
   left,
   "+",
   right
)

program = Program.new
program.statements << expr

puts program

# ─────────────────────────────────────────────
# Prueba 2 -> (5+3)*2

left_inner = IntegerLiteral.new(nil, 5)
right_inner = IntegerLiteral.new(nil, 3)

inner = InfixExpression.new(nil, left_inner, "+", right_inner)

two = IntegerLiteral.new(nil, 2)

expr = InfixExpression.new(nil, inner, "*", two)

program = Program.new
program.statements << expr

puts program


# ─────────────────────────────────────────────
# Prueba 3 -> print

value = IntegerLiteral.new(nil, 10)
print_stmt = PrintStatement.new(nil, value)

program = Program.new
program.statements << print_stmt

puts program

