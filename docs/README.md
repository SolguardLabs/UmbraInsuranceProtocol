# Documentación técnica

La documentación se organiza por decisión operativa y límite de confianza:

- [Arquitectura](./arquitectura.md): módulos, permisos y flujo de activos.
- [Modelo económico](./modelo-economico.md): capacidad, primas y pagos.
- [Integración](./integracion.md): cotización, compra, incidente y reclamación.
- [Operaciones](./operaciones.md): configuración, validación y observabilidad.
- [Riesgos](./riesgos.md): supuestos, estrés y criterios de revisión.

Todos los importes on-chain se expresan en las unidades mínimas del activo del
pool. Una cotización o proyección es una fotografía del bloque consultado y
debe volver a validarse al ejecutar una transacción.
