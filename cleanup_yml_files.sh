#!/bin/bash

# Script para eliminar archivos .yml dejando solo uno por carpeta
# Autor: GitHub Copilot
# Fecha: $(date +%Y-%m-%d)

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para mostrar ayuda
show_help() {
    echo -e "${BLUE}Uso: $0 [opciones]${NC}"
    echo ""
    echo "Opciones:"
    echo "  -h, --help          Mostrar esta ayuda"
    echo "  -d, --dry-run       Simular la ejecución sin eliminar archivos"
    echo "  -v, --verbose       Mostrar información detallada"
    echo "  -f, --force         Ejecutar sin confirmación"
    echo "  -p, --path PATH     Especificar ruta base (por defecto: directorio actual)"
    echo ""
    echo "Descripción:"
    echo "  Este script elimina archivos .yml dejando solo uno por carpeta."
    echo "  Se mantiene el primer archivo alfabéticamente en cada directorio."
    echo ""
    echo "Ejemplos:"
    echo "  $0 --dry-run        # Simular sin eliminar archivos"
    echo "  $0 --verbose        # Ejecutar con salida detallada"
    echo "  $0 --force          # Ejecutar sin confirmación"
}

# Variables por defecto
DRY_RUN=false
VERBOSE=false
FORCE=false
BASE_PATH="."
TOTAL_DELETED=0
TOTAL_KEPT=0
FOLDERS_PROCESSED=0

# Procesar argumentos de línea de comandos
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        -p|--path)
            BASE_PATH="$2"
            shift 2
            ;;
        *)
            echo -e "${RED}Opción desconocida: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# Verificar que el directorio base existe
if [[ ! -d "$BASE_PATH" ]]; then
    echo -e "${RED}Error: El directorio '$BASE_PATH' no existe.${NC}"
    exit 1
fi

# Función para log verbose
log_verbose() {
    if [[ "$VERBOSE" == true ]]; then
        echo -e "${BLUE}[VERBOSE]${NC} $1"
    fi
}

# Función para confirmar la ejecución
confirm_execution() {
    if [[ "$FORCE" == true ]]; then
        return 0
    fi
    
    echo -e "${YELLOW}¿Está seguro de que desea continuar? (s/N)${NC}"
    read -r response
    case "$response" in
        [sS][iI]|[sS])
            return 0
            ;;
        *)
            echo -e "${YELLOW}Operación cancelada.${NC}"
            exit 0
            ;;
    esac
}

# Mostrar banner
echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}  Limpieza de archivos .yml      ${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

# Mostrar configuración
echo -e "${YELLOW}Configuración:${NC}"
echo -e "  Directorio base: ${GREEN}$BASE_PATH${NC}"
echo -e "  Modo dry-run: ${GREEN}$DRY_RUN${NC}"
echo -e "  Verbose: ${GREEN}$VERBOSE${NC}"
echo -e "  Forzar: ${GREEN}$FORCE${NC}"
echo ""

# Buscar todas las carpetas que contienen archivos .yml
echo -e "${YELLOW}Analizando estructura de directorios...${NC}"

# Crear archivo temporal para almacenar resultados
TEMP_FILE=$(mktemp)

# Buscar todos los directorios que contienen archivos .yml
find "$BASE_PATH" -type f -name "*.yml" -exec dirname {} \; | sort -u > "$TEMP_FILE"

TOTAL_FOLDERS=$(wc -l < "$TEMP_FILE")
echo -e "Encontradas ${GREEN}$TOTAL_FOLDERS${NC} carpetas con archivos .yml"

if [[ $TOTAL_FOLDERS -eq 0 ]]; then
    echo -e "${YELLOW}No se encontraron archivos .yml en el directorio especificado.${NC}"
    rm -f "$TEMP_FILE"
    exit 0
fi

# Contar archivos total antes de la limpieza
TOTAL_FILES_BEFORE=$(find "$BASE_PATH" -type f -name "*.yml" | wc -l)
echo -e "Total de archivos .yml antes de la limpieza: ${GREEN}$TOTAL_FILES_BEFORE${NC}"
echo ""

# Mostrar algunos ejemplos de lo que se va a hacer
echo -e "${YELLOW}Ejemplos de carpetas a procesar:${NC}"
head -5 "$TEMP_FILE" | while read -r folder; do
    yml_count=$(find "$folder" -maxdepth 1 -name "*.yml" | wc -l)
    first_file=$(find "$folder" -maxdepth 1 -name "*.yml" | sort | head -1 | xargs basename)
    echo -e "  ${folder}: ${GREEN}$yml_count${NC} archivos → mantener: ${GREEN}$first_file${NC}"
done

if [[ $TOTAL_FOLDERS -gt 5 ]]; then
    echo -e "  ... y ${GREEN}$((TOTAL_FOLDERS - 5))${NC} carpetas más"
fi
echo ""

# Confirmar ejecución si no es dry-run
if [[ "$DRY_RUN" == false ]]; then
    confirm_execution
fi

echo -e "${YELLOW}Iniciando procesamiento...${NC}"
echo ""

# Procesar cada carpeta
while read -r folder; do
    ((FOLDERS_PROCESSED++))
    log_verbose "Procesando carpeta ($FOLDERS_PROCESSED/$TOTAL_FOLDERS): $folder"
    
    # Obtener todos los archivos .yml en la carpeta (solo en el nivel actual, no subdirectorios)
    yml_files=($(find "$folder" -maxdepth 1 -name "*.yml" | sort))
    
    if [[ ${#yml_files[@]} -gt 1 ]]; then
        # Mantener el primer archivo (alfabéticamente)
        keep_file="${yml_files[0]}"
        keep_basename=$(basename "$keep_file")
        
        log_verbose "  Mantener: $keep_basename"
        ((TOTAL_KEPT++))
        
        # Eliminar los demás archivos
        for ((i=1; i<${#yml_files[@]}; i++)); do
            file_to_delete="${yml_files[i]}"
            delete_basename=$(basename "$file_to_delete")
            
            if [[ "$DRY_RUN" == true ]]; then
                echo -e "  ${RED}[DRY-RUN]${NC} Eliminaría: $folder/$delete_basename"
            else
                if rm "$file_to_delete" 2>/dev/null; then
                    echo -e "  ${RED}Eliminado:${NC} $folder/$delete_basename"
                    log_verbose "    ✓ Archivo eliminado exitosamente"
                else
                    echo -e "  ${RED}Error al eliminar:${NC} $folder/$delete_basename"
                fi
            fi
            ((TOTAL_DELETED++))
        done
    else
        # Solo hay un archivo, no hacer nada
        keep_basename=$(basename "${yml_files[0]}")
        log_verbose "  Solo un archivo: $keep_basename (no se requiere acción)"
        ((TOTAL_KEPT++))
    fi
    
    # Mostrar progreso cada 50 carpetas
    if [[ $((FOLDERS_PROCESSED % 50)) -eq 0 ]]; then
        echo -e "${BLUE}Progreso: $FOLDERS_PROCESSED/$TOTAL_FOLDERS carpetas procesadas...${NC}"
    fi
    
done < "$TEMP_FILE"

# Limpiar archivo temporal
rm -f "$TEMP_FILE"

echo ""
echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}       Resumen de ejecución      ${NC}"
echo -e "${BLUE}================================${NC}"

if [[ "$DRY_RUN" == true ]]; then
    echo -e "${YELLOW}MODO DRY-RUN - No se eliminaron archivos realmente${NC}"
fi

echo -e "Carpetas procesadas: ${GREEN}$FOLDERS_PROCESSED${NC}"
echo -e "Archivos mantenidos: ${GREEN}$TOTAL_KEPT${NC}"

if [[ "$DRY_RUN" == true ]]; then
    echo -e "Archivos que se eliminarían: ${YELLOW}$TOTAL_DELETED${NC}"
else
    echo -e "Archivos eliminados: ${RED}$TOTAL_DELETED${NC}"
    
    # Contar archivos después de la limpieza
    TOTAL_FILES_AFTER=$(find "$BASE_PATH" -type f -name "*.yml" | wc -l)
    echo -e "Total de archivos .yml después de la limpieza: ${GREEN}$TOTAL_FILES_AFTER${NC}"
    
    REDUCTION_PERCENTAGE=$(( (TOTAL_FILES_BEFORE - TOTAL_FILES_AFTER) * 100 / TOTAL_FILES_BEFORE ))
    echo -e "Reducción: ${GREEN}$REDUCTION_PERCENTAGE%${NC}"
fi

echo ""
if [[ "$DRY_RUN" == true ]]; then
    echo -e "${YELLOW}Para ejecutar realmente, ejecute el script sin la opción --dry-run${NC}"
else
    echo -e "${GREEN}¡Limpieza completada exitosamente!${NC}"
fi