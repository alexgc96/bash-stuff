#!/bin/bash
# create_project.sh — Project folder scaffolder

# ---------- USER CONFIG ----------
STUDIO_ROOT="/path/to/your/studio/root"   # top-level folder containing Templates/ and Projects/
TEMPLATES_DIR="$STUDIO_ROOT/Templates/Project_Structures"
PROJECTS_ROOT="$STUDIO_ROOT/Projects"
# ---------------------------------

trap 'printf "\n\n  Cancelled.\n\n"; exit 0' INT

BOLD='\033[1m'; DIM='\033[2m'; GREEN='\033[32m'; YELLOW='\033[33m'; RESET='\033[0m'

prompt() {
    local msg="$1" default="$2" val
    printf "\n${BOLD}  %s${RESET}" "$msg" >/dev/tty
    [ -n "$default" ] && printf " ${DIM}[%s]${RESET}" "$default" >/dev/tty
    printf "\n  › " >/dev/tty
    read -r val </dev/tty
    echo "${val:-$default}"
}

prompt_list() {
    local msg="$1"; shift
    local opts=("$@") idx=0 total=${#opts[@]} key seq

    printf "\n${BOLD}  %s${RESET}\n" "$msg" >/dev/tty

    _draw() {
        local i
        for i in "${!opts[@]}"; do
            if [ "$i" -eq "$idx" ]; then
                printf "  ${CYAN}› ${BOLD}%s${RESET}\n" "${opts[$i]}" >/dev/tty
            else
                printf "    ${DIM}%s${RESET}\n" "${opts[$i]}" >/dev/tty
            fi
        done
    }

    _draw

    while true; do
        IFS= read -r -s -n1 key </dev/tty
        if [[ "$key" == $'\x1b' ]]; then
            IFS= read -r -s -n2 seq</dev/tty
            key="${key}${seq}"
        fi
        case "$key" in
            $'\x1b[A'|$'\x1b[D') [ "$idx" -gt 0 ] && ((idx--)) ;;
            $'\x1b[B'|$'\x1b[C') [ "$idx" -lt $((total-1)) ] && ((idx++)) ;;
            ''|$'\r') break ;;
        esac
        printf "\033[%dA" "$total" >/dev/tty
        _draw
    done

    printf "\033[%dA" "$total" >/dev/tty
    printf "\033[J" >/dev/tty
    printf "  ${DIM}→ %s${RESET}\n" "${opts[$idx]}" >/dev/tty
    echo "${opts[$idx]}"
}

section_header() {
    printf "\n${CYAN}  ── %s ──${RESET}\n" "$1" >/dev/tty
}


##############################################
# 1. Project name (required)
##############################################
section_header "PROJECT NAME"
PROJECT_NAME=""
while [ -z "$PROJECT_NAME" ]; do
    PROJECT_NAME=$(prompt "Project name:" "")
    [ -z "$PROJECT_NAME" ] && printf "\n  ${YELLOW}⚠  Name is required.${RESET}\n" >/dev/tty
done

##############################################
# 2. Discover + select project type
##############################################
TYPES=()
for dir in "$TEMPLATES_DIR"/*/; do
    [ -d "$dir" ] && TYPES+=("$(basename "$dir")")
done

if [ ${#TYPES[@]} -eq 0 ]; then
    printf "\n  ✗ No template folders found in:\n  %s\n\n" "$TEMPLATES_DIR" >&2
    exit 1
fi

section_header "PROJECT TYPE"
PROJECT_TYPE=$(prompt_list "Select a type:" "${TYPES[@]}")

##############################################
# 3. Derive paths
##############################################
TEMPLATE_DIR="$TEMPLATES_DIR/$PROJECT_TYPE"
DEST_ROOT="$PROJECTS_ROOT/$(echo "$PROJECT_TYPE" | tr '[:upper:]' '[:lower:]')"
DATE_STAMP=$(date +"%y%m%d")
FINAL_PROJECT_NAME="${PROJECT_NAME}_${DATE_STAMP}"
DEST="$DEST_ROOT/$FINAL_PROJECT_NAME"

if [ ! -d "$TEMPLATE_DIR" ]; then
    printf "\n  ✗ Template not found: %s\n\n" "$TEMPLATE_DIR" >&2
    exit 1
fi

##############################################
# 4. Handle existing destination
##############################################
if [ -d "$DEST" ]; then
    printf "\n${YELLOW}  ⚠  '%s' already exists.${RESET}\n" "$FINAL_PROJECT_NAME"
    printf "  [O]verwrite  [R]ename  [C]ancel: "
    read -r ow_input
    case "$ow_input" in
        [Rr]*)
            NEW_NAME=$(prompt "New project name:" "")
            if [ -z "$NEW_NAME" ]; then printf "\n  Cancelled.\n\n"; exit 0; fi
            FINAL_PROJECT_NAME="${NEW_NAME}_${DATE_STAMP}"
            DEST="$DEST_ROOT/$FINAL_PROJECT_NAME"
            ;;
        [Oo]*)
            rm -rf "$DEST"
            ;;
        *)
            printf "\n  Cancelled.\n\n"; exit 0 ;;
    esac
fi

##############################################
# 5. Create project + copy template
##############################################
printf "\n  Creating: %s\n" "$DEST"
mkdir -p "$DEST"
cp -R "$TEMPLATE_DIR"/. "$DEST"/

##############################################
# 6. Generate README.md
##############################################
cat > "$DEST/README.md" << MDEOF
# ${PROJECT_NAME}

## Type
${PROJECT_TYPE}

## Code
${FINAL_PROJECT_NAME}

## Created
$(date +%Y-%m-%d)

## Notes

MDEOF

printf "\n${GREEN}  ✓ Project created!${RESET}\n"
printf "  %s\n\n" "$DEST"

if command -v xdg-open >/dev/null 2>&1; then xdg-open "$DEST"
elif command -v open >/dev/null 2>&1; then open "$DEST"; fi
