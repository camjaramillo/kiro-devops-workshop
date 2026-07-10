#!/usr/bin/env bash
# validate-terraform.sh - Validación de módulos Terraform
# Ejecuta fmt -check y validate en todos los módulos
# Retorna exit code != 0 si alguna validación falla (integrable en CI)
#
# Uso:
#   ./scripts/validate-terraform.sh
#   ./scripts/validate-terraform.sh --fix   (aplica fmt en lugar de solo verificar)

set -euo pipefail

# ------------------------------------------------------------------
# Colores para output legible en terminal y CI
# ------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
RESET='\033[0m'

# Deshabilitar colores si no es un terminal (ej: logs de CI sin ANSI)
if [ ! -t 1 ]; then
  RED=''; GREEN=''; YELLOW=''; BLUE=''; BOLD=''; RESET=''
fi

# ------------------------------------------------------------------
# Variables globales de control
# ------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
MODULES_DIR="${REPO_ROOT}/infra/terraform/modules"
ENVIRONMENTS_DIR="${REPO_ROOT}/infra/terraform/environments"

FIX_MODE=false
ERRORS=0
WARNINGS=0
MODULES_CHECKED=0
MODULES_FAILED=0

# ------------------------------------------------------------------
# Funciones de output
# ------------------------------------------------------------------

log_header() {
  echo ""
  echo -e "${BOLD}${BLUE}══════════════════════════════════════════════════${RESET}"
  echo -e "${BOLD}${BLUE}  $1${RESET}"
  echo -e "${BOLD}${BLUE}══════════════════════════════════════════════════${RESET}"
}

log_info() {
  echo -e "${BLUE}ℹ  $1${RESET}"
}

log_success() {
  echo -e "${GREEN}✔  $1${RESET}"
}

log_warning() {
  echo -e "${YELLOW}⚠  $1${RESET}"
  ((WARNINGS++)) || true
}

log_error() {
  echo -e "${RED}✘  $1${RESET}"
  ((ERRORS++)) || true
}

log_step() {
  echo -e "   ${BOLD}▶ $1${RESET}"
}

# ------------------------------------------------------------------
# Verificar dependencias
# ------------------------------------------------------------------

check_dependencies() {
  log_header "Verificando dependencias"

  local missing=0

  if command -v terraform &>/dev/null; then
    local tf_version
    tf_version=$(terraform version -json 2>/dev/null | grep -o '"terraform_version":"[^"]*"' | cut -d'"' -f4 || terraform version | head -1)
    log_success "terraform encontrado: ${tf_version}"
  else
    log_error "terraform no está instalado o no está en PATH"
    missing=1
  fi

  if [ "${missing}" -eq 1 ]; then
    echo ""
    echo -e "${RED}${BOLD}Instala las dependencias faltantes y vuelve a ejecutar el script.${RESET}"
    exit 1
  fi
}

# ------------------------------------------------------------------
# Descubrir módulos y entornos a validar
# ------------------------------------------------------------------

discover_modules() {
  local dirs=()

  # Módulos reutilizables
  if [ -d "${MODULES_DIR}" ]; then
    while IFS= read -r -d '' dir; do
      # Solo directorios que contienen al menos un .tf
      if compgen -G "${dir}/*.tf" > /dev/null 2>&1; then
        dirs+=("${dir}")
      fi
    done < <(find "${MODULES_DIR}" -type d -print0)
  fi

  # Entornos (environments)
  if [ -d "${ENVIRONMENTS_DIR}" ]; then
    while IFS= read -r -d '' dir; do
      if compgen -G "${dir}/*.tf" > /dev/null 2>&1; then
        dirs+=("${dir}")
      fi
    done < <(find "${ENVIRONMENTS_DIR}" -type d -print0)
  fi

  printf '%s\n' "${dirs[@]}"
}

# ------------------------------------------------------------------
# Validar formato (terraform fmt)
# ------------------------------------------------------------------

validate_fmt() {
  local dir="$1"
  local rel_path="${dir#${REPO_ROOT}/}"

  log_step "fmt: ${rel_path}"

  if [ "${FIX_MODE}" = true ]; then
    # En modo --fix aplica el formato directamente
    if terraform fmt -recursive "${dir}" > /dev/null 2>&1; then
      log_success "fmt aplicado en ${rel_path}"
    else
      log_error "fmt falló en ${rel_path}"
      return 1
    fi
  else
    # En modo check solo reporta diferencias sin modificar
    local fmt_output
    if fmt_output=$(terraform fmt -check -diff "${dir}" 2>&1); then
      log_success "fmt OK"
    else
      log_error "fmt: archivos con formato incorrecto en ${rel_path}"
      echo "${fmt_output}" | sed 's/^/      /'
      return 1
    fi
  fi
}

# ------------------------------------------------------------------
# Inicializar módulo (terraform init -backend=false)
# ------------------------------------------------------------------

init_module() {
  local dir="$1"
  local rel_path="${dir#${REPO_ROOT}/}"

  log_step "init: ${rel_path}"

  local init_output
  # -backend=false evita necesitar credenciales de S3/remote backend
  # -upgrade=false evita descargas innecesarias en CI
  if init_output=$(terraform -chdir="${dir}" init -backend=false -upgrade=false 2>&1); then
    log_success "init OK"
  else
    log_error "init falló en ${rel_path}"
    echo "${init_output}" | grep -E "(Error|error)" | sed 's/^/      /'
    return 1
  fi
}

# ------------------------------------------------------------------
# Validar sintaxis y configuración (terraform validate)
# ------------------------------------------------------------------

validate_module() {
  local dir="$1"
  local rel_path="${dir#${REPO_ROOT}/}"

  log_step "validate: ${rel_path}"

  local validate_output
  if validate_output=$(terraform -chdir="${dir}" validate -json 2>&1); then
    # Parsear JSON de salida para extraer mensajes legibles
    local valid
    valid=$(echo "${validate_output}" | grep -o '"valid":[a-z]*' | cut -d':' -f2 || echo "true")

    if [ "${valid}" = "true" ]; then
      local warning_count
      warning_count=$(echo "${validate_output}" | grep -o '"warning_count":[0-9]*' | cut -d':' -f2 || echo "0")

      if [ "${warning_count}" -gt 0 ] 2>/dev/null; then
        log_warning "validate OK con ${warning_count} advertencia(s) en ${rel_path}"
      else
        log_success "validate OK"
      fi
    else
      log_error "validate falló en ${rel_path}"
      # Extraer mensajes de error del JSON
      echo "${validate_output}" | \
        grep -o '"summary":"[^"]*"' | \
        cut -d'"' -f4 | \
        sed 's/^/      ✘ /'
      return 1
    fi
  else
    # Si validate no puede emitir JSON, mostrar output raw
    log_error "validate falló en ${rel_path}"
    echo "${validate_output}" | grep -E "(Error|error|Warning)" | head -20 | sed 's/^/      /'
    return 1
  fi
}

# ------------------------------------------------------------------
# Procesar un módulo completo
# ------------------------------------------------------------------

process_module() {
  local dir="$1"
  local rel_path="${dir#${REPO_ROOT}/}"
  local module_failed=false

  echo ""
  echo -e "${BOLD}📁 ${rel_path}${RESET}"

  # fmt
  if ! validate_fmt "${dir}"; then
    module_failed=true
  fi

  # init (necesario antes de validate)
  if ! init_module "${dir}"; then
    module_failed=true
    # Si init falla, no tiene sentido continuar con validate
    echo -e "   ${YELLOW}⚠  validate omitido (init falló)${RESET}"
  else
    # validate
    if ! validate_module "${dir}"; then
      module_failed=true
    fi
  fi

  ((MODULES_CHECKED++)) || true

  if [ "${module_failed}" = true ]; then
    ((MODULES_FAILED++)) || true
    return 1
  fi

  return 0
}

# ------------------------------------------------------------------
# Reporte final
# ------------------------------------------------------------------

print_summary() {
  log_header "Resumen de validación"

  local modules_ok=$((MODULES_CHECKED - MODULES_FAILED))

  echo -e "  Módulos verificados : ${BOLD}${MODULES_CHECKED}${RESET}"
  echo -e "  Módulos correctos   : ${GREEN}${BOLD}${modules_ok}${RESET}"

  if [ "${MODULES_FAILED}" -gt 0 ]; then
    echo -e "  Módulos con errores : ${RED}${BOLD}${MODULES_FAILED}${RESET}"
  fi

  if [ "${WARNINGS}" -gt 0 ]; then
    echo -e "  Advertencias        : ${YELLOW}${BOLD}${WARNINGS}${RESET}"
  fi

  echo ""

  if [ "${ERRORS}" -eq 0 ]; then
    echo -e "${GREEN}${BOLD}✔ Todas las validaciones pasaron correctamente.${RESET}"
  else
    echo -e "${RED}${BOLD}✘ Se encontraron ${ERRORS} error(es). Revisa los mensajes anteriores.${RESET}"
    echo ""
    echo -e "  ${YELLOW}Consejo:${RESET} ejecuta con ${BOLD}--fix${RESET} para corregir problemas de formato automáticamente."
  fi

  echo ""
}

# ------------------------------------------------------------------
# Entrada principal
# ------------------------------------------------------------------

main() {
  # Parsear argumentos
  for arg in "$@"; do
    case "${arg}" in
      --fix)    FIX_MODE=true ;;
      --help|-h)
        echo "Uso: $0 [--fix]"
        echo ""
        echo "  (sin flags)  Verifica fmt y validate sin modificar archivos"
        echo "  --fix        Aplica terraform fmt antes de validar"
        exit 0
        ;;
      *)
        echo -e "${RED}Argumento desconocido: ${arg}${RESET}"
        exit 1
        ;;
    esac
  done

  log_header "Validación de módulos Terraform"
  log_info "Repositorio : ${REPO_ROOT}"
  log_info "Modo        : $([ "${FIX_MODE}" = true ] && echo 'fix (aplica fmt)' || echo 'check (solo lectura)')"

  check_dependencies

  # Descubrir módulos
  log_header "Descubriendo módulos"
  mapfile -t modules < <(discover_modules)

  if [ "${#modules[@]}" -eq 0 ]; then
    log_warning "No se encontraron módulos Terraform en ${MODULES_DIR} ni en ${ENVIRONMENTS_DIR}"
    exit 0
  fi

  log_info "Módulos encontrados: ${#modules[@]}"

  # Validar cada módulo
  log_header "Ejecutando validaciones"

  for module_dir in "${modules[@]}"; do
    process_module "${module_dir}" || true
  done

  # Resumen
  print_summary

  # Exit code para CI: 0 = éxito, 1 = errores encontrados
  [ "${ERRORS}" -eq 0 ]
}

main "$@"
