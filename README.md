# UmbraInsuranceProtocol

![banner](./assets/banner.png)

UmbraInsuranceProtocol es un mercado descentralizado de cobertura para perdidas en vaults.
Los usuarios compran polizas contra incidentes operativos o economicos, y los underwriters
aportan capital a pools de riesgo que respaldan esas coberturas.

El protocolo separa custodia de capital, pricing, registro de polizas, incidentes, claims y
monitorizacion. La intencion es que cada modulo pueda auditarse de forma aislada y que los
flujos principales se puedan ejecutar sin servicios externos.

> Estado del proyecto: software experimental. No usar con fondos reales sin una revision
> independiente, parametrizacion operativa y controles adicionales.

## Componentes

| Componente | Responsabilidad |
| --- | --- |
| `RiskPool` | Custodia capital de underwriters, reservas de polizas, retiradas y pagos de claims. |
| `PremiumEngine` | Calcula primas segun producto, duracion, cobertura y utilizacion del pool. |
| `PolicyRegistry` | Emite polizas tokenizadas, reserva cobertura y gestiona expiracion. |
| `IncidentRegistry` | Registra incidentes aprobados para productos y vaults cubiertos. |
| `ClaimProcessor` | Recibe claims y coordina su revision y pago por lotes. |
| `ClaimReviewBoard` | Coordina revisiones operativas y recomendaciones sobre claims. |
| `ReserveMonitor` | Expone vistas agregadas de solvencia y presion de claims. |
| `RiskOracle` | Mantiene senales operativas de riesgo para reporting y pricing externo. |
| `EpochAccounting` | Guarda snapshots de pools por epoca para revision operacional. |
| `CoverageTerms` | Versiona documentos de condiciones de cobertura. |
| `TreasuryRouter` | Contabiliza fees y presupuestos operativos por categoria. |

## Flujos Principales

1. Un underwriter deposita capital en `RiskPool` y recibe shares internas.
2. Gobernanza configura un producto en `PremiumEngine`.
3. Un usuario compra una poliza en `PolicyRegistry`.
4. El pool recibe la prima de reserva y bloquea capacidad para la cobertura.
5. Un keeper abre un incidente en `IncidentRegistry`.
6. El beneficiario presenta un claim en `ClaimProcessor`.
7. Un keeper procesa el lote de claims y el pool realiza los pagos aprobados.
8. Las polizas expiradas liberan reserva y los underwriters pueden retirar capital disponible.

## Requisitos

- Foundry estable (`forge`, `cast`, `anvil`).
- Git.
- Solidity `0.8.26`.

## Instalacion

```bash
git clone <URL_DEL_REPOSITORIO>
cd UmbraInsuranceProtocol
forge install foundry-rs/forge-std --no-git
forge build
```

Si el repositorio ya incluye `lib/forge-std`, no hace falta reinstalar dependencias.

## Uso

```bash
# Formatear
forge fmt

# Compilar
forge build --sizes

# Ejecutar pruebas
bash scripts/tests.sh
powershell -ExecutionPolicy Bypass -File scripts/tests.ps1

# Validacion completa de CI
bash scripts/ci.sh
powershell -ExecutionPolicy Bypass -File scripts/ci.ps1

# Prueba concreta
forge test --match-test testSingleClaimPaysBeneficiaryAndClosesPolicy -vvvv
```

En Windows, use los scripts PowerShell si WSL no tiene Foundry nativo o no puede ejecutar
binarios Windows. Los comandos `forge` tambien pueden ejecutarse directamente desde PowerShell.

## Despliegue

`script/DeployUmbra.s.sol` despliega los modulos principales, conecta permisos entre ellos y
crea un producto inicial. Ejemplo de simulacion:

```bash
PRIVATE_KEY=<clave-local> \
UMBRA_ASSET=<erc20> \
UMBRA_TREASURY=<tesoreria> \
forge script script/DeployUmbra.s.sol:DeployUmbra --rpc-url <rpc> -vvvv
```

Para emitir transacciones, anada `--broadcast`. Las variables `UMBRA_*` permiten ajustar
capital minimo, limites de utilizacion, duraciones, comisiones y parametros de producto.

## Estructura

```text
.
├── src/
│   ├── core/          # Pools, pricing, polizas, incidentes, claims y monitores
│   ├── interfaces/    # Interfaces publicas
│   ├── libraries/     # Matematicas, transferencias, hashes y formulas de seguro
│   ├── security/      # Roles y proteccion contra reentrada
│   ├── token/         # Tokens de recibo y poliza
│   └── types/         # Structs, enums y constantes compartidas
├── test/              # Pruebas Foundry
├── script/            # Despliegue
├── scripts/           # Comandos locales y CI
└── foundry.toml       # Configuracion de Foundry
```

## Desarrollo Seguro

Los cambios que afecten a capital, reservas, claims, expiraciones o permisos deben incluir
pruebas de conservacion de saldos y casos de borde. Los reportes de seguridad deben seguir
el proceso descrito en [SECURITY.md](SECURITY.md).

## Licencia

MIT. Consulte [LICENSE](LICENSE).
