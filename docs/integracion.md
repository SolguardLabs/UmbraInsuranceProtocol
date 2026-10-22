# Integración de clientes

## Cotización y contratación

1. Leer producto y pool correspondientes, incluida su admisión actual.
2. Solicitar `quotePolicy(productId, coverageAmount, duration)` al motor.
3. Opcionalmente consultar `ProductRiskLens.project(...)` para mostrar capital,
   reservas y utilización estimadas después de la compra.
4. Presentar importe bruto, prima de reserva, comisión, deducible, ventana de
   espera, inicio y expiración.
5. Aprobar el activo para `PolicyRegistry` y llamar `buyPolicy` con titular,
   beneficiario, bóveda cubierta, términos y `maxPremium`.
6. Registrar el ID de póliza y confirmar el evento en cadena.

Si el estado cambia entre la consulta y la compra, `maxPremium` o los límites
de capacidad pueden hacer revertir la operación. No reutilices una proyección
como autorización definitiva ni omitas la identidad de producto/bóveda al
presentar el riesgo al usuario.

## Incidente y reclamación

Un incidente contiene producto, bóveda, fecha de ocurrencia, severidad y una
referencia de evidencia. Su fecha debe estar dentro de la vigencia de la
póliza. El reclamante presenta pérdida, importe solicitado, destinatario y
hash de evidencia; el procesador asigna un ID de reclamación. El tratamiento
por lote corresponde a un keeper o gobernador. Una recomendación de
`ClaimReviewBoard` es información operativa, no un pago automático.

## Lectura de cartera y estado

`ReserveMonitor.poolHealth(poolId)` expone capital, reservas, disponible,
retiradas pendientes y utilización. `policyHealth(policyId)` muestra cobertura,
partes y tiempo restante. `summarizeClaims(ids)` resume presión de cola, pero
es una estimación y no ejecuta deducibles ni cambios de estado. Las interfaces
deben mostrar el número de bloque de la instantánea y refrescar la lectura
antes de firmar acciones sensibles.
