#!/bin/bash
# Hook: behavior-verify.sh
# Evento: PostToolUse (matcher: Edit|Write), async
# Se il file modificato ha un test corrispondente, suggerisce di runnare i test
# Non blocca, non esegue test. Solo reminder.
# Ref: framework #172 (behavior preservation)

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

[ -z "$FILE_PATH" ] && exit 0
[ ! -f "$FILE_PATH" ] && exit 0

BASENAME=$(basename "$FILE_PATH")
DIRNAME=$(dirname "$FILE_PATH")
EXT="${BASENAME##*.}"

# Solo file sorgente
case "$EXT" in
  java|go|py|ts|js|kt|rs) ;;
  *) exit 0 ;;
esac

# Cerca test corrispondente
TEST_FILE=""
NAME_NO_EXT="${BASENAME%.*}"

case "$EXT" in
  java)
    # FooTest.java o FooIT.java nella stessa struttura src/test
    TEST_DIR="${DIRNAME//\/src\/main\///src/test/}"
    for suffix in Test IT; do
      CANDIDATE="${TEST_DIR}/${NAME_NO_EXT}${suffix}.java"
      [ -f "$CANDIDATE" ] && TEST_FILE="$CANDIDATE" && break
    done
    ;;
  go)
    CANDIDATE="${DIRNAME}/${NAME_NO_EXT}_test.go"
    [ -f "$CANDIDATE" ] && TEST_FILE="$CANDIDATE"
    ;;
  py)
    # test_foo.py nella stessa dir o in tests/
    for dir in "$DIRNAME" "$DIRNAME/../tests" "$DIRNAME/tests"; do
      CANDIDATE="${dir}/test_${BASENAME}"
      [ -f "$CANDIDATE" ] && TEST_FILE="$CANDIDATE" && break
    done
    ;;
  ts|js)
    for suffix in .test .spec; do
      CANDIDATE="${DIRNAME}/${NAME_NO_EXT}${suffix}.${EXT}"
      [ -f "$CANDIDATE" ] && TEST_FILE="$CANDIDATE" && break
    done
    ;;
esac

if [ -n "$TEST_FILE" ]; then
  echo "Test trovato: $(basename "$TEST_FILE") — considerare di runnare i test dopo questa modifica." >&2
fi

exit 0