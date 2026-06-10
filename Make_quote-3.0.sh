#!/bin/bash
# =============================================================================
# make_quote.sh — Freelance Quotation Generator (macOS only — requires osascript)
# =============================================================================

# --- DATES -------------------------------------------------------------------
TODAY=$(date +"%Y-%m-%d")
VALID_UNTIL=$(date -v+30d +"%Y-%m-%d")
MONTH_FOLDER=$(date +"%b%y" | tr '[:upper:]' '[:lower:]')   # e.g. apr26

# --- USER CONFIG (edit these before first use) -------------------------------
QUOTE_DIR="/path/to/your/quotes/folder/${MONTH_FOLDER}"   # output folder; created automatically
LOGO_PATH="/path/to/your/logo.png"                        # square PNG, embedded in HTML; skipped if missing
ARTIST_NAME="Your Name"
ARTIST_EMAIL="your@email.com"
ARTIST_ADDRESS="Your Address, City, Country"

# --- DOCUMENT CUSTOMIZATION --------------------------------------------------
# Payment terms and T&Cs are editable template text — search for L_PAYMENT_BODY
# and L_TNC_BODY in the LANGUAGE STRINGS section to change rates, revision
# rounds, cancellation policy, etc.
# The full HTML output document lives between "cat > "$HTML_FILE" << HTMLEOF"
# and "HTMLEOF" — edit the HTML/CSS there for layout or branding changes.
# -----------------------------------------------------------------------------

trap 'printf "\n\n  Cancelled.\n\n"; exit 0' INT

# --- COLORS ------------------------------------------------------------------
BOLD='\033[1m'; DIM='\033[2m'; CYAN='\033[36m'; GREEN='\033[32m'
YELLOW='\033[33m'; RESET='\033[0m'

# --- HELPER: terminal prompts ------------------------------------------------

# Text input — Enter accepts default; Ctrl-C exits
prompt() {
    local msg="$1" default="$2" val
    printf "\n${BOLD}  %s${RESET}" "$msg" >/dev/tty
    [ -n "$default" ] && printf " ${DIM}[%s]${RESET}" "$default" >/dev/tty
    printf "\n  › " >/dev/tty
    read -r val </dev/tty
    echo "${val:-$default}"
}

# Numbered list — type a number or Enter for default (first item)
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

# Yes / No — y/Y = Yes, anything else (including Enter) = No
prompt_yn() {
    local msg="$1" val
    printf "\n${BOLD}  %s${RESET} ${DIM}[y/N]${RESET}: " "$msg" >/dev/tty
    read -r val </dev/tty
    case "$val" in
        [yY]|[yY][eE][sS]) echo "Yes" ;;
        *) echo "No" ;;
    esac
}

# Section header — printed once per step
section_header() {
    local step="$1" total="$2" title="$3"
    printf "\n${CYAN}  ── %s of %s — %s${RESET}\n" "$step" "$total" "$title" >/dev/tty
}

# =============================================================================
# PROMPTS — linear, no back button, Cancel on any dialog exits cleanly
# =============================================================================

IS_SPANISH=false
CURR_CODE="MXN"; CURR_SYMBOL="MXN \$"
USE_TAX=false; TAX_RATE="0"
QUOTE_NUM=""; CLIENT_NAME=""; CLIENT_CONTACT=""; CLIENT_EMAIL=""
CLIENT_PHONE=""; CLIENT_PM=""; CLIENT_ADDRESS=""; CLIENT_PO=""
PROJ_NAME=""; PROJ_CODE=""; PROJ_TYPE=""; PROJ_DESC=""
NUM_ITEMS=1
declare -a ITEM_NAMES ITEM_DESCS ITEM_PRICES_RAW
TECH_RESOLUTION=""; TECH_FRAMERATE=""; TECH_FORMATS=""
TECH_COLORSPACE=""; TECH_RENDERENGINE=""; TECH_DELIVERY=""
NUM_WEEKS=0
declare -a MILESTONE_TEXTS

# ── 1. LANGUAGE ───────────────────────────────────────────────────────────────
section_header 1 10 "LANGUAGE"
lang=$(prompt_list "Quotation language:" "English" "Español")
[ "$lang" = "Español" ] && IS_SPANISH=true

# ── 2. CURRENCY ───────────────────────────────────────────────────────────────
section_header 2 10 "CURRENCY"
curr=$(prompt_list "Currency:" "USD" "EUR" "GBP" "MXN")
CURR_CODE="$curr"
case "$curr" in
    "USD") CURR_SYMBOL="\$" ;;
    "EUR") CURR_SYMBOL="€" ;;
    "GBP") CURR_SYMBOL="£" ;;
    "MXN") CURR_SYMBOL="MX\$" ;;
    *)     CURR_SYMBOL="$curr " ;;
esac

# ── 3. TAX ────────────────────────────────────────────────────────────────────
section_header 3 10 "TAX"
tax_ans=$(prompt_yn "Include tax in this quote?")
if [ "$tax_ans" = "Yes" ]; then
    USE_TAX=true
    raw_rate=$(prompt "Tax rate (%):" "20")
    [[ "$raw_rate" =~ ^[0-9]+(\.[0-9]+)?$ ]] && TAX_RATE="$raw_rate" || TAX_RATE="0"
fi

# ── 4. QUOTE NUMBER ───────────────────────────────────────────────────────────
section_header 4 10 "QUOTE NUMBER"
if $IS_SPANISH; then
    QUOTE_NUM=$(prompt "Número de cotización:" "COT-${TODAY//-/}-001")
else
    QUOTE_NUM=$(prompt "Quote number:" "QT-${TODAY//-/}-001")
fi
while [ -z "$QUOTE_NUM" ]; do
    printf "  ${YELLOW}⚠  Required.${RESET}\n" >/dev/tty
    if $IS_SPANISH; then
        QUOTE_NUM=$(prompt "Número de cotización:" "COT-${TODAY//-/}-001")
    else
        QUOTE_NUM=$(prompt "Quote number:" "QT-${TODAY//-/}-001")
    fi
done

# ── 5. CLIENT INFO ────────────────────────────────────────────────────────────
section_header 5 10 "CLIENT INFORMATION"
if $IS_SPANISH; then
    CLIENT_NAME=$(prompt    "Nombre del cliente (opcional):" "")
    CLIENT_CONTACT=$(prompt "Persona de contacto (opcional):" "")
    CLIENT_EMAIL=$(prompt   "Correo electrónico (opcional):" "")
    CLIENT_PHONE=$(prompt   "Teléfono (opcional):" "")
    CLIENT_ADDRESS=$(prompt "Dirección del cliente (opcional):" "")
    CLIENT_PM=$(prompt      "Project Manager (opcional):" "")
    CLIENT_PO=$(prompt      "Número de orden / PO (opcional):" "")
else
    CLIENT_NAME=$(prompt    "Client name (optional):" "")
    CLIENT_CONTACT=$(prompt "Contact person (optional):" "")
    CLIENT_EMAIL=$(prompt   "Client email (optional):" "")
    CLIENT_PHONE=$(prompt   "Client phone (optional):" "")
    CLIENT_ADDRESS=$(prompt "Client address (optional):" "")
    CLIENT_PM=$(prompt      "Client project manager (optional):" "")
    CLIENT_PO=$(prompt      "PO number (optional):" "")
fi

# ── 6. PROJECT DETAILS ────────────────────────────────────────────────────────
section_header 6 10 "PROJECT DETAILS"
TODAY_SHORT=$(date +"%d%m%y")
if $IS_SPANISH; then
    PROJ_NAME=$(prompt "Nombre del proyecto:" "ej. Visualización de Jardín")
    PROJ_CODE=$(prompt "Código del proyecto (opcional):" "ej. GardenViz_${TODAY_SHORT}")
    PROJ_TYPE=$(prompt "Tipo de proyecto:" "Archviz / Modelado 3D Freelance / Animación / Otro")
    PROJ_DESC=$(prompt "Descripción del proyecto (opcional):" "Breve descripción de 2-3 oraciones.")
else
    PROJ_NAME=$(prompt "Project name:" "e.g. Garden Visualization")
    PROJ_CODE=$(prompt "Project code (optional):" "e.g. GardenViz_${TODAY_SHORT}")
    PROJ_TYPE=$(prompt "Project type:" "Archviz / Freelance 3D Modeling / Animation / Other")
    PROJ_DESC=$(prompt "Project description (optional):" "Brief 2-3 sentence overview.")
fi

# ── 7. LINE ITEMS ─────────────────────────────────────────────────────────────
section_header 7 10 "LINE ITEMS"
if $IS_SPANISH; then
    raw_items=$(prompt "¿Cuántos artículos tiene esta cotización?" "1")
else
    raw_items=$(prompt "How many line items in this quote?" "1")
fi
[[ "$raw_items" =~ ^[1-9][0-9]*$ ]] && NUM_ITEMS="$raw_items" || NUM_ITEMS=1

for (( i=1; i<=NUM_ITEMS; i++ )); do
    printf "\n${DIM}  — Item %s of %s —${RESET}\n" "$i" "$NUM_ITEMS" >/dev/tty
    if $IS_SPANISH; then
        iname=$(prompt  "Nombre:" "")
        idesc=$(prompt  "Descripción (opcional):" "")
        iprice=$(prompt "Precio base ($CURR_CODE):" "0")
    else
        iname=$(prompt  "Name:" "")
        idesc=$(prompt  "Description (optional):" "")
        iprice=$(prompt "Base price ($CURR_CODE):" "0")
    fi
    [ -z "$iname" ]  && iname="Item $i"
    [ -z "$iprice" ] && iprice="0"
    ITEM_NAMES[$i]="$iname"
    ITEM_DESCS[$i]="$idesc"
    ITEM_PRICES_RAW[$i]="$iprice"
done

# ── 8. TECHNICAL SPECIFICATIONS ───────────────────────────────────────────────
section_header 8 10 "TECHNICAL SPECIFICATIONS"
if $IS_SPANISH; then
    tech_ans=$(prompt_yn "¿Llenar especificaciones técnicas?")
else
    tech_ans=$(prompt_yn "Fill out technical specifications?")
fi
if [ "$tech_ans" = "Yes" ]; then
    if $IS_SPANISH; then
        TECH_RESOLUTION=$(prompt   "Resolución (ej. 3840x2160):" "")
        TECH_FRAMERATE=$(prompt    "Frame Rate (ej. 24fps):" "")
        TECH_FORMATS=$(prompt      "Formatos de archivo (ej. PNG, MP4, FBX):" "")
        TECH_COLORSPACE=$(prompt   "Espacio de color (ej. sRGB):" "")
        TECH_RENDERENGINE=$(prompt "Motor de renderizado (ej. Cycles, V-Ray):" "")
        TECH_DELIVERY=$(prompt     "Formato de entrega (ej. Enlace en la nube):" "")
    else
        TECH_RESOLUTION=$(prompt   "Resolution (e.g. 3840x2160):" "")
        TECH_FRAMERATE=$(prompt    "Frame Rate (e.g. 24fps):" "")
        TECH_FORMATS=$(prompt      "File formats (e.g. PNG, MP4, FBX):" "")
        TECH_COLORSPACE=$(prompt   "Color space (e.g. sRGB):" "")
        TECH_RENDERENGINE=$(prompt "Render engine (e.g. Cycles, V-Ray):" "")
        TECH_DELIVERY=$(prompt     "Delivery format (e.g. Cloud link, USB):" "")
    fi
fi

# ── 9. MILESTONES ─────────────────────────────────────────────────────────────
section_header 9 10 "MILESTONES"
if $IS_SPANISH; then
    ms_ans=$(prompt_yn "¿Llenar hitos del proyecto?")
else
    ms_ans=$(prompt_yn "Fill out project milestones?")
fi
if [ "$ms_ans" = "Yes" ]; then
    if $IS_SPANISH; then
        raw_weeks=$(prompt "¿Cuántas semanas dura el proyecto?" "4")
    else
        raw_weeks=$(prompt "How many weeks is the project?" "4")
    fi
    [[ "$raw_weeks" =~ ^[1-9][0-9]*$ ]] && NUM_WEEKS="$raw_weeks" || NUM_WEEKS=4
    for (( w=1; w<=NUM_WEEKS; w++ )); do
        printf "\n${DIM}  — Week %s of %s —${RESET}\n" "$w" "$NUM_WEEKS" >/dev/tty
        if $IS_SPANISH; then
            MILESTONE_TEXTS[$w]=$(prompt "Descripción del hito:" "")
        else
            MILESTONE_TEXTS[$w]=$(prompt "Milestone description:" "")
        fi
    done
fi

section_header 10 10 "REVIEW"
printf "\n  ${DIM}Quote:   %s${RESET}\n" "$QUOTE_NUM" >/dev/tty
printf "  ${DIM}Client:  %s${RESET}\n" "${CLIENT_NAME:-—}" >/dev/tty
printf "  ${DIM}Project: %s${RESET}\n" "$PROJ_NAME" >/dev/tty
printf "  ${DIM}Items:   %s  |  Currency: %s  |  Tax: %s%%%s${RESET}\n" \
    "$NUM_ITEMS" "$CURR_CODE" "$TAX_RATE" "$(if $USE_TAX; then echo ""; else echo " (none)"; fi)" >/dev/tty
printf "\n"

# =============================================================================
# TAX CALCULATIONS (bc for float math)
# =============================================================================
ROWS_HTML=""
SUBTOTAL_SUM="0"

for (( i=1; i<=NUM_ITEMS; i++ )); do
    base="${ITEM_PRICES_RAW[$i]}"
    adjusted=$(echo "scale=2; $base" | bc)
    SUBTOTAL_SUM=$(echo "scale=2; $SUBTOTAL_SUM + $adjusted" | bc)
    ROWS_HTML="${ROWS_HTML}
        <tr>
            <td><strong>${ITEM_NAMES[$i]}</strong></td>
            <td>${ITEM_DESCS[$i]}</td>
            <td class=\"num\">$CURR_SYMBOL $(printf '%.2f' $adjusted)</td>
        </tr>"
done

if $USE_TAX; then
    TAX_AMOUNT=$(echo "scale=2; $SUBTOTAL_SUM * $TAX_RATE / 100" | bc)
    TOTAL=$(echo "scale=2; $SUBTOTAL_SUM + $TAX_AMOUNT" | bc)
    if $IS_SPANISH; then TAX_LABEL="Impuesto (${TAX_RATE}%)"; else TAX_LABEL="Tax (${TAX_RATE}%)"; fi
    TAX_ROWS="
        <tr class=\"subtotal-row\">
            <td colspan=\"2\">Subtotal</td>
            <td class=\"num\">$CURR_SYMBOL $(printf '%.2f' $SUBTOTAL_SUM)</td>
        </tr>
        <tr>
            <td colspan=\"2\">${TAX_LABEL}</td>
            <td class=\"num\">$CURR_SYMBOL $(printf '%.2f' $TAX_AMOUNT)</td>
        </tr>
        <tr class=\"total-row\">
            <td colspan=\"2\"><strong>TOTAL</strong></td>
            <td class=\"num\"><strong>$CURR_SYMBOL $(printf '%.2f' $TOTAL)</strong></td>
        </tr>"
    DISPLAY_TOTAL=$(printf '%.2f' $TOTAL)
else
    TAX_ROWS="
        <tr class=\"subtotal-row\">
            <td colspan=\"2\">Subtotal</td>
            <td class=\"num\">$CURR_SYMBOL $(printf '%.2f' $SUBTOTAL_SUM)</td>
        </tr>
        <tr>
            <td colspan=\"2\">Tax</td>
            <td class=\"num\">—</td>
        </tr>
        <tr class=\"total-row\">
            <td colspan=\"2\"><strong>TOTAL</strong></td>
            <td class=\"num\"><strong>$CURR_SYMBOL $(printf '%.2f' $SUBTOTAL_SUM)</strong></td>
        </tr>"
    DISPLAY_TOTAL=$(printf '%.2f' $SUBTOTAL_SUM)
fi

# =============================================================================
# LANGUAGE STRINGS
# =============================================================================
if $IS_SPANISH; then
    L_TITLE="COTIZACIÓN"
    L_QUOTE_NUM="Número de Cotización"
    L_DATE_ISSUED="Fecha de Emisión"
    L_VALID_UNTIL="Válida Hasta"
    L_CLIENT_INFO="INFORMACIÓN DEL CLIENTE"
    L_CLIENT_NAME="Nombre del Cliente"
    L_CONTACT="Persona de Contacto"
    L_EMAIL="Correo Electrónico"
    L_PHONE="Teléfono"
    L_CLIENT_ADDRESS="Dirección"
    L_PM="Project Manager"
    L_PO="Número de Orden (PO)"
    L_PROJ_DETAILS="DETALLES DEL PROYECTO"
    L_PROJ_NAME="Nombre del Proyecto"
    L_PROJ_CODE="Código del Proyecto"
    L_PROJ_TYPE="Tipo de Proyecto"
    L_PROJ_DESC="Descripción del Proyecto"
    L_SCOPE="ALCANCE DEL TRABAJO"
    L_DELIVERABLES="Entregas"
    L_ITEM="Artículo"
    L_DESC="Descripción"
    L_PRICE="Precio"
    L_TECH_SPEC="ESPECIFICACIONES TÉCNICAS"
    L_TECH_LABEL_RES="Resolución"
    L_TECH_LABEL_FPS="Frame Rate"
    L_TECH_LABEL_FMT="Formatos de Archivo"
    L_TECH_LABEL_CS="Espacio de Color"
    L_TECH_LABEL_RE="Renderización"
    L_TECH_LABEL_DEL="Formato de Entrega"
    L_TIMELINE="CRONOGRAMA"
    L_START_DATE="Fecha de Inicio"
    L_DRAFT_DATE="Entrega de Borrador/Preview"
    L_FINAL_DATE="Fecha de Entrega Final"
    L_DURATION="Duración Total"
    L_MILESTONES="Hitos"
    L_WEEK="Semana"
    L_PRICING="DESGLOSE DE PRECIOS"
    L_PAYMENT="TÉRMINOS DE PAGO"
    L_PAYMENT_BODY="
        <ul>
            <li>Anticipo: [50]% al aceptar la cotización</li>
            <li>Pago Final: [50]% al completar el proyecto</li>
            <li>Métodos de Pago: [Transferencia bancaria, PayPal, Stripe, etc.]</li>
            <li>Pago Tardío: Cargo de 5% aplica después de 15 días</li>
        </ul>"
    L_TNC="TÉRMINOS Y CONDICIONES"
    L_TNC_BODY="
        <p><strong>Qué Está Incluido:</strong></p>
        <ul>
            <li>Hasta 2 rondas de revisiones razonables</li>
            <li>Archivos del proyecto en formatos acordados</li>
            <li>Actualizaciones regulares del progreso</li>
        </ul>
        <p><strong>Qué NO Está Incluido:</strong></p>
        <ul>
            <li>Cambios mayores de alcance después de la aprobación (sujetos a cargos adicionales)</li>
            <li>Revisiones adicionales más allá de 2 rondas (\$144 MXN/hora)</li>
            <li>Entrega urgente (menos de 2 días de aviso) — Recargo del 20%</li>
            <li>Archivos fuente/escenas (disponibles por \$450 MXN adicionales)</li>
        </ul>
        <p><strong>Responsabilidades del Cliente:</strong></p>
        <ul>
            <li>Proporcionar todos los materiales de referencia, planos y briefs dentro de [3] días hábiles</li>
            <li>Responder a previews/borradores dentro de [5] días hábiles</li>
            <li>Pago final antes de la entrega de archivos</li>
        </ul>
        <p><strong>Política de Cancelación:</strong></p>
        <ul>
            <li>El anticipo no es reembolsable</li>
            <li>Cancelación después de comenzar: se cobran las horas trabajadas</li>
            <li>El cliente adquiere los entregables finales con el pago completo</li>
        </ul>
        <p><strong>Derechos de Uso:</strong></p>
        <ul>
            <li>El cliente recibe derechos completos de uso comercial de los archivos finales entregados</li>
            <li>El artista conserva el derecho de usar el trabajo en su portafolio salvo acuerdo contrario</li>
        </ul>"
    L_ACCEPTANCE="ACEPTACIÓN"
    L_ACCEPTANCE_BODY="Al firmar abajo, usted acepta el alcance, cronograma, precios y términos descritos en esta cotización."
    L_CLIENT_SIG="Firma del Cliente"
    L_ARTIST_SIG="Firma del Artista"
    L_PRINT_NAME="Nombre (letra de molde)"
    L_DATE_SIGN="Fecha"
    L_QUESTIONS="¿Preguntas? Contáctame en"
    L_VALID_NOTE="Esta cotización es válida por 30 días desde la fecha de emisión. Precios y disponibilidad sujetos a cambio después de la expiración."
else
    L_TITLE="QUOTATION"
    L_QUOTE_NUM="Quote Number"
    L_DATE_ISSUED="Date Issued"
    L_VALID_UNTIL="Valid Until"
    L_CLIENT_INFO="CLIENT INFORMATION"
    L_CLIENT_NAME="Client Name"
    L_CONTACT="Contact Person"
    L_EMAIL="Email"
    L_PHONE="Phone"
    L_CLIENT_ADDRESS="Address"
    L_PM="Project Manager"
    L_PO="PO Number"
    L_PROJ_DETAILS="PROJECT DETAILS"
    L_PROJ_NAME="Project Name"
    L_PROJ_CODE="Project Code"
    L_PROJ_TYPE="Project Type"
    L_PROJ_DESC="Project Description"
    L_SCOPE="SCOPE OF WORK"
    L_DELIVERABLES="Deliverables"
    L_ITEM="Item"
    L_DESC="Description"
    L_PRICE="Price"
    L_TECH_SPEC="TECHNICAL SPECIFICATIONS"
    L_TECH_LABEL_RES="Resolution"
    L_TECH_LABEL_FPS="Frame Rate"
    L_TECH_LABEL_FMT="File Formats"
    L_TECH_LABEL_CS="Color Space"
    L_TECH_LABEL_RE="Render Engine"
    L_TECH_LABEL_DEL="Delivery Format"
    L_TIMELINE="TIMELINE"
    L_START_DATE="Project Start Date"
    L_DRAFT_DATE="Draft/Preview Delivery"
    L_FINAL_DATE="Final Delivery Date"
    L_DURATION="Total Duration"
    L_MILESTONES="Milestones"
    L_WEEK="Week"
    L_PRICING="PRICING BREAKDOWN"
    L_PAYMENT="PAYMENT TERMS"
    L_PAYMENT_BODY="
        <ul>
            <li>Deposit: [50]% due upon acceptance of quotation</li>
            <li>Final Payment: [50]% due upon project completion</li>
            <li>Payment Methods: [Bank transfer, PayPal, Stripe, etc.]</li>
            <li>Late Payment: 5% fee applies after 15 days</li>
        </ul>"
    L_TNC="TERMS &amp; CONDITIONS"
    L_TNC_BODY="
        <p><strong>What's Included:</strong></p>
        <ul>
            <li>Up to 2 rounds of reasonable revisions</li>
            <li>Project files in agreed formats</li>
            <li>Regular progress updates</li>
        </ul>
        <p><strong>What's NOT Included:</strong></p>
        <ul>
            <li>Major scope changes after approval (subject to additional charges)</li>
            <li>Additional revisions beyond 2 rounds (\$8 USD/hour)</li>
            <li>Rush delivery (less than 2 days notice) — 20% surcharge applies</li>
            <li>Source files/scene files (available for additional \$25 USD)</li>
        </ul>
        <p><strong>Client Responsibilities:</strong></p>
        <ul>
            <li>Provide all reference materials, floor plans, and briefs within [3] business days</li>
            <li>Respond to previews/drafts within [5] business days</li>
            <li>Final payment before file delivery</li>
        </ul>
        <p><strong>Cancellation Policy:</strong></p>
        <ul>
            <li>Deposit is non-refundable</li>
            <li>Cancellation after work begins: charged for hours worked</li>
            <li>Client owns final deliverables upon full payment</li>
        </ul>
        <p><strong>Usage Rights:</strong></p>
        <ul>
            <li>Client receives full commercial usage rights for delivered final files</li>
            <li>Artist retains right to use work in portfolio unless otherwise agreed</li>
        </ul>"
    L_ACCEPTANCE="ACCEPTANCE"
    L_ACCEPTANCE_BODY="By signing below, you agree to the scope, timeline, pricing, and terms outlined in this quotation."
    L_CLIENT_SIG="Client Signature"
    L_ARTIST_SIG="Artist Signature"
    L_PRINT_NAME="Print Name"
    L_DATE_SIGN="Date"
    L_QUESTIONS="Questions? Contact me at"
    L_VALID_NOTE="This quotation is valid for 30 days from the date of issue. Prices and availability subject to change after expiration."
fi

# =============================================================================
# BUILD DYNAMIC HTML SNIPPETS (tech specs + milestones)
# =============================================================================

# Tech specs — show filled values or blank placeholder per field
tech_li() { local label="$1" val="$2"
    if [ -n "$val" ]; then
        echo "        <li><strong>${label}:</strong> ${val}</li>"
    else
        echo "        <li><strong>${label}:</strong> &nbsp;</li>"
    fi
}
L_TECH_ITEMS="
$(tech_li "$L_TECH_LABEL_RES" "$TECH_RESOLUTION")
$(tech_li "$L_TECH_LABEL_FPS" "$TECH_FRAMERATE")
$(tech_li "$L_TECH_LABEL_FMT" "$TECH_FORMATS")
$(tech_li "$L_TECH_LABEL_CS"  "$TECH_COLORSPACE")
$(tech_li "$L_TECH_LABEL_RE"  "$TECH_RENDERENGINE")
$(tech_li "$L_TECH_LABEL_DEL" "$TECH_DELIVERY")"

# Milestones — blank if skipped, filled list if entered
if [ "$NUM_WEEKS" -eq 0 ]; then
    L_MILESTONE_ITEMS="        <li>&nbsp;</li>"
else
    L_MILESTONE_ITEMS=""
    for (( w=1; w<=NUM_WEEKS; w++ )); do
        L_MILESTONE_ITEMS="${L_MILESTONE_ITEMS}        <li>${L_WEEK} ${w}: ${MILESTONE_TEXTS[$w]}</li>"$'\n'
    done
fi

# =============================================================================
# OUTPUT FILE PATH
# =============================================================================
SAFE_QUOTE_NUM="${QUOTE_NUM//\//-}"
HTML_FILE="${QUOTE_DIR}/${SAFE_QUOTE_NUM}.html"

# =============================================================================
# OVERWRITE PROTECTION
# =============================================================================
if [ -f "$HTML_FILE" ]; then
    printf "\n${YELLOW}  ⚠  '%s' already exists.${RESET}\n" "$SAFE_QUOTE_NUM"
    printf "  [O]verwrite  [R]ename  [C]ancel: "
    read -r ow_input
    case "$ow_input" in
        [Rr]*)
            printf "  New name [%s_v2]: " "$SAFE_QUOTE_NUM"
            read -r new_name
            SAFE_QUOTE_NUM="${new_name:-${SAFE_QUOTE_NUM}_v2}"
            HTML_FILE="${QUOTE_DIR}/${SAFE_QUOTE_NUM}.html"
            ;;
        [Oo]*) : ;;
        *) printf "\n  Cancelled.\n\n"; exit 0 ;;
    esac
fi

mkdir -p "$QUOTE_DIR"

# Encode logo as base64 for embedding in HTML (no external file dependency)
if [ -f "$LOGO_PATH" ]; then
    LOGO_B64=$(base64 < "$LOGO_PATH")
    LOGO_SRC="data:image/png;base64,${LOGO_B64}"
else
    LOGO_SRC=""
fi

# =============================================================================
# BUILD HTML
# =============================================================================
cat > "$HTML_FILE" << HTMLEOF
<!DOCTYPE html>
<html lang="$(if $IS_SPANISH; then echo 'es'; else echo 'en'; fi)">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>${L_TITLE} — ${QUOTE_NUM}</title>
<style>
  @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700&display=swap');

  * { box-sizing: border-box; margin: 0; padding: 0; }

  body {
    font-family: 'Inter', 'Helvetica Neue', Arial, sans-serif;
    font-size: 11pt;
    color: #111;
    background: #fff;
    max-width: 820px;
    margin: 0 auto;
    padding: 48px 56px;
  }

  /* HEADER */
  .header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    margin-bottom: 36px;
    border-bottom: 3px solid #111;
    padding-bottom: 24px;
  }
  .header-left h1 {
    font-size: 32pt;
    font-weight: 700;
    letter-spacing: -1px;
    line-height: 1;
  }
  .header-left .meta {
    margin-top: 12px;
    font-size: 10pt;
    line-height: 1.8;
  }
  .header-left .meta strong { font-weight: 600; }
  .header-right {
    display: flex;
    flex-direction: column;
    align-items: flex-end;
    gap: 10px;
  }
  .logo {
    width: 90px;
    height: 90px;
    object-fit: contain;
  }
  .artist-meta {
    font-size: 9pt;
    color: #333;
    text-align: right;
    line-height: 1.7;
  }

  /* SECTIONS */
  .section {
    margin-top: 32px;
  }
  .section h2 {
    font-size: 12pt;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 1px;
    border-bottom: 1.5px solid #111;
    padding-bottom: 4px;
    margin-bottom: 14px;
  }
  .section h3 {
    font-size: 10.5pt;
    font-weight: 600;
    margin: 14px 0 8px;
  }
  .field-row {
    display: flex;
    gap: 8px;
    margin-bottom: 5px;
    font-size: 10.5pt;
  }
  .field-row .label { font-weight: 600; white-space: nowrap; }
  .field-row .value { color: #333; }

  /* TABLES */
  table {
    width: 100%;
    border-collapse: collapse;
    font-size: 10.5pt;
    margin-top: 8px;
  }
  th {
    background: #111;
    color: #fff;
    text-align: left;
    padding: 8px 10px;
    font-weight: 600;
    font-size: 9.5pt;
    text-transform: uppercase;
    letter-spacing: 0.5px;
  }
  td {
    padding: 8px 10px;
    border-bottom: 1px solid #e0e0e0;
    vertical-align: top;
  }
  tr:last-child td { border-bottom: none; }
  .num { text-align: right; white-space: nowrap; }
  .subtotal-row td {
    border-top: 2px solid #111;
    font-weight: 600;
    background: #f7f7f7;
  }
  .total-row td {
    background: #111;
    color: #fff;
    font-size: 11.5pt;
    font-weight: 700;
    border-top: none;
  }

  /* LISTS */
  ul { padding-left: 20px; margin: 6px 0; }
  li { margin-bottom: 4px; font-size: 10.5pt; line-height: 1.5; }

  /* TIMELINE */
  .timeline-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 6px 24px;
    font-size: 10.5pt;
  }

  /* SIGNATURE BLOCK */
  .sig-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 32px;
    margin-top: 24px;
  }
  .sig-box { font-size: 10.5pt; }
  .sig-line {
    border-bottom: 1px solid #111;
    margin: 28px 0 6px;
    width: 100%;
  }

  /* FOOTER */
  .footer {
    margin-top: 40px;
    border-top: 1px solid #ccc;
    padding-top: 14px;
    font-size: 9pt;
    color: #555;
    text-align: center;
  }

  @media print {
    body { padding: 32px 40px; }
    .section { page-break-inside: avoid; }
  }

  @page {
    margin-top: 1.2cm;
    margin-bottom: 0.8cm;
    margin-left: 0;
    margin-right: 0;
    /* Suppress browser-injected URL footer, keep default title header */
    @bottom-center { content: none; }
    @bottom-left   { content: none; }
    @bottom-right  { content: none; }
  }
</style>
</head>
<body>

<!-- ===== HEADER ===== -->
<div class="header">
  <div class="header-left">
    <h1>${L_TITLE}</h1>
    <div class="meta">
      <div class="field-row"><span class="label">${L_QUOTE_NUM}:</span><span class="value">${QUOTE_NUM}</span></div>
      <div class="field-row"><span class="label">${L_DATE_ISSUED}:</span><span class="value">${TODAY}</span></div>
      <div class="field-row"><span class="label">${L_VALID_UNTIL}:</span><span class="value">${VALID_UNTIL}</span></div>
    </div>
  </div>
  <div class="header-right">
    <img class="logo" src="${LOGO_SRC}" alt="Logo">
    <div class="artist-meta">
      <strong>${ARTIST_NAME}</strong><br>
      ${ARTIST_ADDRESS}<br>
      <a href="mailto:${ARTIST_EMAIL}">${ARTIST_EMAIL}</a>
    </div>
  </div>
</div>

<!-- ===== CLIENT INFORMATION ===== -->
<div class="section">
  <h2>${L_CLIENT_INFO}</h2>
  <div class="field-row"><span class="label">${L_CLIENT_NAME}:</span><span class="value">${CLIENT_NAME:-&nbsp;}</span></div>
  <div class="field-row"><span class="label">${L_CONTACT}:</span><span class="value">${CLIENT_CONTACT:-&nbsp;}</span></div>
  <div class="field-row"><span class="label">${L_EMAIL}:</span><span class="value">${CLIENT_EMAIL:-&nbsp;}</span></div>
  <div class="field-row"><span class="label">${L_PHONE}:</span><span class="value">${CLIENT_PHONE:-&nbsp;}</span></div>
  <div class="field-row"><span class="label">${L_CLIENT_ADDRESS}:</span><span class="value">${CLIENT_ADDRESS:-&nbsp;}</span></div>
  <div class="field-row"><span class="label">${L_PM}:</span><span class="value">${CLIENT_PM:-&nbsp;}</span></div>
  <div class="field-row"><span class="label">${L_PO}:</span><span class="value">${CLIENT_PO:-&nbsp;}</span></div>
</div>

<!-- ===== PROJECT DETAILS ===== -->
<div class="section">
  <h2>${L_PROJ_DETAILS}</h2>
  <div class="field-row"><span class="label">${L_PROJ_NAME}:</span><span class="value">${PROJ_NAME}</span></div>
  <div class="field-row"><span class="label">${L_PROJ_CODE}:</span><span class="value">${PROJ_CODE:-&nbsp;}</span></div>
  <div class="field-row"><span class="label">${L_PROJ_TYPE}:</span><span class="value">${PROJ_TYPE:-&nbsp;}</span></div>
  <div class="field-row"><span class="label">${L_PROJ_DESC}:</span><span class="value">${PROJ_DESC:-&nbsp;}</span></div>
</div>

<!-- ===== SCOPE OF WORK ===== -->
<div class="section">
  <h2>${L_SCOPE}</h2>
  <h3>${L_DELIVERABLES}</h3>
  <table>
    <thead>
      <tr>
        <th>${L_ITEM}</th>
        <th>${L_DESC}</th>
        <th class="num">${L_PRICE} (${CURR_CODE})</th>
      </tr>
    </thead>
    <tbody>
      ${ROWS_HTML}
    </tbody>
  </table>
</div>

<!-- ===== TECHNICAL SPECS ===== -->
<div class="section">
  <h2>${L_TECH_SPEC}</h2>
  <ul>${L_TECH_ITEMS}</ul>
</div>

<!-- ===== TIMELINE ===== -->
<div class="section">
  <h2>${L_TIMELINE}</h2>
  <div class="timeline-grid">
    <div class="field-row"><span class="label">${L_START_DATE}:</span><span class="value">${TODAY}</span></div>
    <div class="field-row"><span class="label">${L_DURATION}:</span><span class="value">&nbsp;</span></div>
    <div class="field-row"><span class="label">${L_DRAFT_DATE}:</span><span class="value">&nbsp;</span></div>
    <div class="field-row"><span class="label">${L_FINAL_DATE}:</span><span class="value">&nbsp;</span></div>
  </div>
  <h3>${L_MILESTONES}</h3>
  <ul>${L_MILESTONE_ITEMS}</ul>
</div>

<!-- ===== PRICING BREAKDOWN ===== -->
<div class="section">
  <h2>${L_PRICING}</h2>
  <table>
    <thead>
      <tr>
        <th colspan="2">${L_DESC}</th>
        <th class="num">${CURR_CODE}</th>
      </tr>
    </thead>
    <tbody>
      ${TAX_ROWS}
    </tbody>
  </table>
</div>

<!-- ===== PAYMENT TERMS ===== -->
<div class="section">
  <h2>${L_PAYMENT}</h2>
  ${L_PAYMENT_BODY}
</div>

<!-- ===== TERMS & CONDITIONS ===== -->
<div class="section">
  <h2>${L_TNC}</h2>
  ${L_TNC_BODY}
</div>

<!-- ===== ACCEPTANCE ===== -->
<div class="section">
  <h2>${L_ACCEPTANCE}</h2>
  <p>${L_ACCEPTANCE_BODY}</p>
  <div class="sig-grid">
    <div class="sig-box">
      <div class="sig-line"></div>
      <strong>${L_CLIENT_SIG}</strong><br>
      ${L_PRINT_NAME}: ___________________<br>
      ${L_DATE_SIGN}: ___________________
    </div>
    <div class="sig-box">
      <div class="sig-line"></div>
      <strong>${L_ARTIST_SIG}</strong><br>
      ${L_PRINT_NAME}: ${ARTIST_NAME}<br>
      ${L_DATE_SIGN}: ___________________
    </div>
  </div>
</div>

<!-- ===== FOOTER ===== -->
<div class="footer">
  ${L_QUESTIONS} <a href="mailto:${ARTIST_EMAIL}">${ARTIST_EMAIL}</a><br>
  ${L_VALID_NOTE}
</div>

</body>
</html>
HTMLEOF

printf "\n${GREEN}  ✓ Quote saved!${RESET}\n"
printf "  %s\n\n" "$HTML_FILE"

if command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$HTML_FILE"
elif command -v open >/dev/null 2>&1; then
    open "$HTML_FILE"
fi
