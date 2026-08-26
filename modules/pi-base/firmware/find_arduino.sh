#!/bin/bash
#
# find_arduino.sh
# Finds the serial port of an Arduino (including clones) by sending
# "serveID" via the serial interface and checking the response.
#
# Output: PORT<TAB>RECEIVED_MESSAGE (one line per detected device)
#
# Usage:
#   ./find_arduino.sh            -> outputs port + message of the first match
#                                    e.g., "/dev/ttyACM0    ID1130"
#   ./find_arduino.sh -v         -> verbose output (debugging)
#   ./find_arduino.sh -a         -> outputs ALL found Arduino ports (+ message)
#   ./find_arduino.sh -s         -> additionally creates a symlink for each match,
#                                    e.g., /dev/arduino/ID1130 -> /dev/ttyACM0
#                                    (usually requires sudo, as it writes to /dev)
#   ./find_arduino.sh -d DIR     -> target directory for symlinks (default: /dev/arduino)
#                                    implies -s

set -uo pipefail
trap '' TTIN TTOU

# ==========================================================================
# ADJUST: List of known IDs that an Arduino/board returns.
# Simply add/remove entries.
# The response always contains an underscore "_" between the ID and a
# trailing number (e.g., serial number), e.g. "ID_1130". Everything from
# the first underscore onward is automatically truncated for comparison
# -> only enter the actual ID without the underscore/number here.
# ==========================================================================
KNOWN_IDS=(
    "ID" # only for testing
    "do-PWM-1to6x"
    "ao-1to3x-0to10V"
    # add more IDs here, e.g.:
    # "MySensorBoard"
)

BAUDRATE=9600      # ADJUST: match the baud rate of your sketch
IDENTIFY_CMD='serveID'
TIMEOUT_SEC=2       # how long to wait for a response
BOOT_WAIT_SEC=2     # many boards reset when opening the port (DTR) -> wait for boot time

VERBOSE=0
LIST_ALL=0
MAKE_SYMLINKS=0
SYMLINK_DIR="/dev/arduino"   # ADJUST: target directory for symlinks
LAST_RESPONSE=""   # filled by check_port() with the raw received response

while getopts "vasd:p:" opt; do
  case $opt in
    v) VERBOSE=1 ;;
    a) LIST_ALL=1 ;;
    s) MAKE_SYMLINKS=1 ;;
    d) MAKE_SYMLINKS=1; SYMLINK_DIR="$OPTARG" ;;
    p) SINGLE_PORT="$OPTARG" ;;
    *) echo "Unknown option"; exit 1 ;;
  esac
done

log() {
    if [ "$VERBOSE" -eq 1 ]; then
        echo "$@" >&2
    fi
}

check_port() {
    local dev="$1"

    if [ ! -w "$dev" ]; then
        log "  -> no write permissions on $dev, skipping (sudo or dialout group may be needed)"
        return 1
    fi

    # Configure port: baud rate, raw mode (no processing/echo)
    if ! stty -F "$dev" "$BAUDRATE" raw -echo cs8 -cstopb -parenb 2>/dev/null; then
        log "  -> stty failed on $dev"
        return 1
    fi

    # IMPORTANT: Open the port ONLY ONCE and keep the connection open
    # for both writing AND reading (file descriptor 3). If you open it
    # multiple times in succession (e.g., once for writing, once for reading),
    # many boards trigger a reset on EVERY open (DTR toggle) ->
    # you might write/read during the board's restart and never get a proper response.
    if ! exec 3<>"$dev"; then
        log "  -> could not open $dev"
        return 1
    fi

    # After opening, many boards reset (Uno, Nano with CH340, Leonardo, etc.).
    # Wait briefly for the sketch to restart.
    sleep "$BOOT_WAIT_SEC"

    # Clear input buffer (discard old boot messages, etc.)
    timeout 0.3 dd if=/proc/self/fd/3 of=/dev/null bs=1 2>/dev/null

    # Send command
    printf '%s\n' "$IDENTIFY_CMD" >&3

    # Read response with timeout (first line is sufficient)
    local response
    response=$(timeout "$TIMEOUT_SEC" head -n1 <&3)

    # Close connection
    exec 3<&-
    exec 3>&-

    # Trim leading/trailing whitespace and newlines
    response="$(echo "$response" | tr -d '\r\n' | xargs)"

    log "  -> response (raw): '$response'"

    LAST_RESPONSE="$response"

    if [ -z "$response" ]; then
        log "  -> no response received (timeout)"
        return 1
    fi

    # Trim everything from the first underscore onward (the underscore
    # reliably separates the ID from the trailing number, e.g. serial
    # number/ID number) for comparison.
    local id_part
    id_part=$(echo "$response" | sed -E 's/_.*$//')

    log "  -> ID without number: '$id_part'"

    for known in "${KNOWN_IDS[@]}"; do
        if [ "$id_part" = "$known" ]; then
            log "  -> matches known ID '$known'"
            return 0
        fi
    done

    return 1
}

# Creates a symlink under $SYMLINK_DIR pointing to the serial port.
# The link name is derived from the response sent by the Arduino
# (e.g., "ID1130"), so the board can be addressed independently of the
# randomly assigned /dev/ttyACM* name.
create_symlink() {
    local dev="$1"
    local response="$2"

    # Convert response into a string safe for filenames/symlinks:
    # only allow letters, digits, '_', '.', '-', replace everything else with '_'
    local safe_name
    safe_name=$(printf '%s' "$response" | tr -c 'A-Za-z0-9_.-' '_')

    if [ -z "$safe_name" ]; then
        log "  -> could not generate a valid symlink name from '$response', skipping"
        return 1
    fi

    if ! mkdir -p "$SYMLINK_DIR" 2>/dev/null; then
        log "  -> could not create $SYMLINK_DIR (sudo may be needed)"
        return 1
    fi

    local link="$SYMLINK_DIR/$safe_name"
    if ln -sf "$dev" "$link" 2>/dev/null; then
        log "  -> symlink created: $link -> $dev"
    else
        log "  -> could not create symlink $link (sudo may be needed, e.g., run with sudo)"
        return 1
    fi
}

FOUND_PORTS=()
FOUND_RESPONSES=()

if [ -n "${SINGLE_PORT:-}" ]; then
    CANDIDATES=("$SINGLE_PORT")
else
    shopt -s nullglob
    CANDIDATES=(/dev/ttyACM* /dev/ttyUSB*)
    shopt -u nullglob
fi

if [ ${#CANDIDATES[@]} -eq 0 ]; then
    echo "No serial USB devices found (neither /dev/ttyACM* nor /dev/ttyUSB*)." >&2
    exit 1
fi

for dev in "${CANDIDATES[@]}"; do
    log "Checking $dev ..."
    if check_port "$dev"; then
        log "  -> Arduino detected on $dev (response: '$LAST_RESPONSE')"
        FOUND_PORTS+=("$dev")
        FOUND_RESPONSES+=("$LAST_RESPONSE")
        if [ "$MAKE_SYMLINKS" -eq 1 ]; then
            create_symlink "$dev" "$LAST_RESPONSE"
        fi
        if [ "$LIST_ALL" -eq 0 ]; then
            break
        fi
    fi
done

if [ ${#FOUND_PORTS[@]} -eq 0 ]; then
    echo "No Arduino found (no matching response to '$IDENTIFY_CMD')." >&2
    exit 1
fi

if [ "$LIST_ALL" -eq 1 ]; then
    for i in "${!FOUND_PORTS[@]}"; do
        printf '%s\t%s\n' "${FOUND_PORTS[$i]}" "${FOUND_RESPONSES[$i]}"
    done
else
    printf '%s\t%s\n' "${FOUND_PORTS[0]}" "${FOUND_RESPONSES[0]}"
fi
