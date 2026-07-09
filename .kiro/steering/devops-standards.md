# Estándares DevOps - Kiro DevOps Workshop

Este documento define los estándares DevOps para el equipo de desarrollo.

## GitHub Actions

- **Todos los pipelines deben usar GitHub Actions** como sistema de CI/CD.
- Los workflows deben colocarse en `.github/workflows/` dentro del repositorio.

## Naming Conventions

- **Los workflows deben tener nombres descriptivos en español**.
- Los archivos de workflow deben seguir el formato: `ci-build.yml`, `deploy-production.yml`, etc.

## Estages del Pipeline

**Siempre incluir los siguientes steps en orden:**

1. `lint` - Verificación de código y estilo
2. `test` - Ejecución de pruebas
3. `build` - Compilación y empaquetado

## Versiones y Dependencias

- **Usar Node.js 20 como versión por defecto** para todos los proyectos.
- Especificar la versión explícitamente en workflows: `node-version: '20'`

## Secrets y Variables

- **Los secrets se referencian con el prefijo `CARVAJAL_`**.
- Ejemplo: `CARVAJAL_SLACK_WEBHOOK`, `CARVAJAL_AWS_ACCESS_KEY_ID`
- No hardcodear secrets en los workflows.

## Notificaciones

- **Incluir notificación a Slack en caso de fallo**.
- Usar el action `slack/webhook` o similar.
- Configurar el webhook como secret: `CARVAJAL_SLACK_WEBHOOK`

## Estructura Básica de un Workflow

```yaml
name: nombre-descriptivo-en-espanol

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  ci:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Configurar Node.js 20
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Instalar dependencias
        run: npm ci

      - name: Lint
        run: npm run lint

      - name: Test
        run: npm run test

      - name: Build
        run: npm run build

      - name: Notificar fallo a Slack
        if: failure()
        uses: slackapi/slack-github-action@v1.25.0
        with:
          webhook: ${{ secrets.CARVAJAL_SLACK_WEBHOOK }}
          message: "Fallo en el pipeline: ${{ github.workflow }} #${{ github.run_number }}"
```

## Buenas Prácticas

- Usar versiones específicas de actions (no `@latest`)
- Mantener los workflows lo más limpios y legibles posible
- Documentar inputs y outputs de custom actions
- Usar matrices para testing multi-plataforma cuando sea necesario
