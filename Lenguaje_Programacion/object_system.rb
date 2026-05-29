# =============================================================================
# object_system.rb — ARCHIVO DEPRECADO / CÓDIGO MUERTO
#
# [FIX VULN-02 / VULN-19]
#
# Este archivo es una versión paralela del sistema de objetos que NUNCA fue
# importado por main.rb ni por el evaluador. Existía como código muerto con
# clases duplicadas (ObjectBase vs BaseObject, Function vs FunctionObject)
# y constantes que colisionan con Ruby built-ins (TRUE, FALSE, NULL).
#
# La implementación activa está en object.rb.
# Este archivo se conserva solo por referencia histórica.
# =============================================================================

# NO USAR — Ver object.rb para la implementación activa.