require_relative '../Lenguaje_Programacion/object_system'

puts "Probando inspect:"
puts TRUE.inspect
puts FALSE.inspect
puts NULL.inspect
puts BREAK_SIGNAL.inspect
puts CONTINUE_SIGNAL.inspect

puts "\nProbando types:"
puts TRUE.type == ObjectType::BOOLEAN
puts NULL.type == ObjectType::NULL
puts BREAK_SIGNAL.type == ObjectType::BREAK

puts "\nProbando identidad (singleton):"
puts TRUE.object_id == TRUE.object_id

puts "\nSimulación de control:"

def fake_loop(result)
  return "BREAK detectado" if result == BREAK_SIGNAL
  return "CONTINUE detectado" if result == CONTINUE_SIGNAL
  "NORMAL"
end

puts fake_loop(BREAK_SIGNAL)
puts fake_loop(CONTINUE_SIGNAL)
puts fake_loop(TRUE)

# Pruebas de continue y break
def test_control(signal)
  case signal.type
  when ObjectType::BREAK
    "romper loop"
  when ObjectType::CONTINUE
    "continuar loop"
  else
    "normal"
  end
end

puts test_control(BREAK_SIGNAL)
puts test_control(CONTINUE_SIGNAL)


puts "\n✅ FIN DE PRUEBAS yupi"