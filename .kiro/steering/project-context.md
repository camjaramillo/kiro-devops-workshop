# Contexto del Proyecto - Kiro DevOps Workshop

## Descripción General

Este es un **workshop de DevOps** diseñado para aprender a usar Kiro en entornos de desarrollo y operaciones.

## Stack Tecnológico

- **Runtime**: Node.js 20
- **Framework**: Express.js
- **Testing**: Jest
- **Despliegue**: AWS (Lambda o ECS)

## Objetivo del Workshop

El objetivo es entender cómo configurar y gestionar pipelines de CI/CD usando GitHub Actions, aplicando buenas prácticas de DevOps en una aplicación Node.js sencilla.

## Estructura del Proyecto

- `src/` - Código fuente de la aplicación Express
- `tests/` - Pruebas unitarias con Jest
- `.github/workflows/` - Workflows de GitHub Actions

## Consideraciones de Despliegue

- El target de deploy es AWS
- Se puede desplegar en Lambda para arquitecturas serverless o en ECS para contenedores
- Las credenciales de AWS deben usar el prefijo `CARVAJAL_AWS_`

## Comunicación

- **Preferir respuestas en español** para toda la interacción.
- La documentación y comments en código deben estar en español.