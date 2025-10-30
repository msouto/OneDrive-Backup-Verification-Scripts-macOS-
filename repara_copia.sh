#!/bin/sh
# Repara faltantes no backup a partir de um log de verificação.
# Suporta:
#  (A) logs com rsync --itemize-changes (>f…)
#  (B) logs com bloco textual "⚠️ Arquivos ausentes no backup:" (caminhos absolutos iniciando com "/")
set -e

LOG_DIR="${LOG_DIR:-$PWD}"
ALT_LOG_DIR="${ALT_LOG_DIR:-$HOME/Documents}"
RSYNC_FLAGS="-a --human-readable --progress --checksum --no-perms --no-owner --no-group"

EXCLUIR='.DS_Store
._*
.Spotlight-V100/
.fseventsd/
.Trash/
.DocumentCache/
.com.microsoft.OneDrive*
.TemporaryItems/'

msg() { printf '[%s] %s\n' "$(date '+%F %T')" "$*"; }
die() { msg "ERRO: $*"; exit 1; }
trim() { printf '%s' "$1" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//'; }
listar_logs() { ls -1t "$1"/*.log 2>/dev/null || true; }

inferir_origem() {
  s="$(trim "$1")"
  case "$s" in
    /*) printf '%s\n' "$s" ;;
    OneDrive*|OneDrive-*)
      base="$(printf '%s' "$s" | tr ' ' '-')"
      printf '%s/Library/CloudStorage/%s\n' "$HOME" "$base"
      ;;
    *) printf '%s\n' "$s" ;;
  esac
}

escolher_origem_interativa() {
  CANDS="$(find "$HOME/Library/CloudStorage" -maxdepth 1 -type d -name 'OneDrive*' 2>/dev/null | sort)"
  [ -z "$CANDS" ] && die "Nenhuma pasta OneDrive* encontrada em ~/Library/CloudStorage."
  i=1
  echo "Pastas OneDrive detectadas:"
  echo "$CANDS" | while IFS= read -r d; do printf '%2d) %s\n' "$i" "$d"; i=$((i+1)); done
  printf 'Escolha a origem correta (número) ou ENTER para cancelar: '
  read pick
  case "$pick" in ''|*[!0-9]*) die "Cancelado sem origem válida." ;; esac
  ORG="$(echo "$CANDS" | sed -n "${pick}p")"
  [ -z "$ORG" ] && die "Índice inválido."
  printf '%s\n' "$ORG"
}

escolher_destino_interativa() {
  CANDS="$( (find "$PWD" -maxdepth 2 -type d -name 'OneDrive*_Backup_*' 2>/dev/null; \
             find "$HOME/Documents" -maxdepth 3 -type d -name 'OneDrive*_Backup_*' 2>/dev/null) | sort -u )"
  [ -z "$CANDS" ] && die "Nenhum backup *Backup_* encontrado automaticamente. Ajuste LOG_DIR ou o log de verificação."
  i=1
  echo "Backups detectados:"
  echo "$CANDS" | while IFS= read -r d; do printf '%2d) %s\n' "$i" "$d"; i=$((i+1)); done
  printf 'Escolha o destino correto (número) ou ENTER para cancelar: '
  read pick
  case "$pick" in ''|*[!0-9]*) die "Cancelado sem destino válido." ;; esac
  DST="$(echo "$CANDS" | sed -n "${pick}p")"
  [ -z "$DST" ] && die "Índice inválido."
  printf '%s\n' "$DST"
}

# 1) Selecionar LOG
msg "Procurando logs em: $LOG_DIR"
LOG_LIST="$(listar_logs "$LOG_DIR")"
if [ -z "$LOG_LIST" ]; then
  msg "Nenhum .log em $LOG_DIR. Tentando $ALT_LOG_DIR…"
  LOG_LIST="$(listar_logs "$ALT_LOG_DIR")" || true
  [ -z "$LOG_LIST" ] && die "Sem .log em $LOG_DIR e $ALT_LOG_DIR."
  LOG_DIR="$ALT_LOG_DIR"
fi

i=1
echo "$LOG_LIST" | while IFS= read -r f; do printf '%2d) %s\n' "$i" "$f"; i=$((i+1)); done

printf 'Digite o número do log a usar: '
read choice
case "$choice" in ''|*[!0-9]*) die "Escolha inválida." ;; esac
LOG_FILE="$(echo "$LOG_LIST" | sed -n "${choice}p")"
[ -n "$LOG_FILE" ] || die "Índice fora do intervalo."
msg "Usando log: $LOG_FILE"

# 2) Extrair ORIGEM e DESTINO do log e sanear
ORIG_RAW="$(grep -E -m1 'Verificando origem:|📂 Verificando origem:|📂 Verificando:' "$LOG_FILE" \
  | sed -E 's/.*Verificando origem:\s*//; s/.*Verificando:\s*//' )"
DEST_PATH="$(grep -E -m1 'Comparando com backup:' "$LOG_FILE" \
  | sed -E 's/.*Comparando com backup:\s*//' )"
[ -n "$ORIG_RAW" ] || die "Não foi possível identificar a ORIGEM no log."
[ -n "$DEST_PATH" ] || die "Não foi possível identificar o DESTINO no log."

ORIG_RAW="$(trim "$ORIG_RAW" | tr -d '\r')"
DEST_PATH="$(trim "$DEST_PATH" | tr -d '\r')"

SRC_PATH="$(inferir_origem "$ORIG_RAW")"
msg "Origem inferida (pré-checagem): $SRC_PATH"
[ -d "$SRC_PATH" ] || { msg "Origem não encontrada em: $SRC_PATH"; SRC_PATH="$(escolher_origem_interativa)"; }
msg "Origem confirmada: $SRC_PATH"

[ -d "$DEST_PATH" ] || { msg "Destino não encontrado em: $DEST_PATH"; DEST_PATH="$(escolher_destino_interativa)"; }
msg "Destino confirmado: $DEST_PATH"

# 3) Construir lista de faltantes
TMP_MISS="$(mktemp)"

# 3A) Tentar via rsync --itemize (>f…)
grep -E '^[[:space:]]*>f[^ ]*[[:space:]]+' "$LOG_FILE" 2>/dev/null \
  | sed -E 's/^[[:space:]]*>f[^ ]*[[:space:]]+//' \
  | sed '/^[[:space:]]*$/d' \
  | sort -u > "$TMP_MISS" || true
MISS_COUNT=$(wc -l < "$TMP_MISS" | tr -d ' ')

# 3B) Se não encontrou nada, ler o bloco "⚠️ Arquivos ausentes no backup:"
if [ "$MISS_COUNT" -eq 0 ]; then
  START_LINE="$(grep -n 'Arquivos ausentes no backup:' "$LOG_FILE" | head -n1 | cut -d: -f1 || true)"
  if [ -n "$START_LINE" ]; then
    # Coleta linhas após o cabeçalho enquanto começarem com "/" (caminhos absolutos).
    # Para quando encontra:
    #  - linha vazia
    #  - novo cabeçalho do relatório (Verificando, Comparando, 📊, 🔍)
    awk -v start="$START_LINE" '
      NR>start {
        line=$0
        gsub(/^[[:space:]]+/, "", line)
        if (line ~ /^$/) exit
        if (line ~ /^(Verificando|Comparando|📊|🔍)/) exit
        if (line ~ /^\//) print line
        else exit
      }
    ' "$LOG_FILE" > "${TMP_MISS}.abs" || true

    : > "$TMP_MISS"
    while IFS= read -r abs; do
      abs="$(printf '%s' "$abs" | tr -d '\r')"
      # ignora lixo conhecido
      case "$abs" in
        *"/.DS_Store"|*"/.Trash/"*|*"/.DocumentCache/"*|*"/.TemporaryItems/"*|*"/.Spotlight-V100/"*|*"/.fseventsd/"*|*"._"*)
          continue ;;
      esac
      case "$abs" in
        "$SRC_PATH"/*) rel="${abs#$SRC_PATH/}" ;;
        /*)
          base_src="$(basename "$SRC_PATH")"
          case "$abs" in
            *"/$base_src/"*) rel="${abs#*"/$base_src/"}" ;;
            *) rel="" ;;
          esac
          ;;
        *) rel="$abs" ;;
      esac
      [ -n "$rel" ] && printf '%s\n' "$rel" >> "$TMP_MISS"
    done < "${TMP_MISS}.abs"
    rm -f "${TMP_MISS}.abs"
    sort -u "$TMP_MISS" -o "$TMP_MISS"
    MISS_COUNT=$(wc -l < "$TMP_MISS" | tr -d ' ')
  fi
fi

if [ "$MISS_COUNT" -eq 0 ]; then
  msg "Nenhum arquivo faltante detectado no log (nada a reparar)."
  rm -f "$TMP_MISS"
  exit 0
fi

msg "Encontrados $MISS_COUNT arquivo(s) a restaurar. Exibindo até 15:"
head -n 15 "$TMP_MISS" | sed 's/^/   • /'

printf "Prosseguir copiando do ORIGEM → BACKUP? (digite: SIM) "
read CONF
[ "$CONF" = "SIM" ] || { msg "Cancelado."; rm -f "$TMP_MISS"; exit 1; }

# 4) Montar exclusões
EXC_ARGS=""
echo "$EXCLUIR" | while IFS= read -r pat; do [ -n "$pat" ] && EXC_ARGS="$EXC_ARGS --exclude=$pat"; done

# 5) Log e execução
LOG_REPARO="$HOME/Documents/onedrive_reparo_$(date +%Y-%m-%d_%H%M%S).log"
{
  echo "===== $(date '+%F %T') Reparação de faltantes ====="
  echo "Log base: $LOG_FILE"
  echo "Origem: $SRC_PATH"
  echo "Destino: $DEST_PATH"
  printf "Arquivos: %s\n" "$MISS_COUNT"
} >> "$LOG_REPARO"

set +e
# shellcheck disable=SC2086
eval rsync $RSYNC_FLAGS $EXC_ARGS --files-from="$TMP_MISS" "$SRC_PATH/" "$DEST_PATH/" | tee -a "$LOG_REPARO"
RS=$?
set -e

[ "$RS" -ne 0 ] && msg "rsync retornou código $RS (alguns itens podem ter falhado). Veja: $LOG_REPARO"

# 6) Verificação pós-reparo (dry-run somente dos itens reparados)
msg "Verificação pós-reparo (dry-run)…"
set +e
POST="$(
  eval rsync -a --dry-run --itemize-changes --checksum $EXC_ARGS --files-from="$TMP_MISS" "$SRC_PATH/" "$DEST_PATH/"
)"
RC=$?
set -e

if [ "$RC" -ne 0 ]; then
  msg "Aviso: rsync dry-run retornou $RC. Ainda assim, analisando diferenças (se houver)."
fi

if [ -z "$POST" ]; then
  msg "✅ Sem diferenças restantes para os itens reparados."
else
  msg "❗ Ainda há diferenças (mostrando até 50 linhas):"
  printf '%s\n' "$POST" | sed -n '1,50p'
  LINES=$(printf '%s\n' "$POST" | wc -l | tr -d ' ')
  [ "$LINES" -gt 50 ] && msg "… e mais $((LINES-50)) linha(s)."
fi

msg "Operação finalizada. Log de reparo: $LOG_REPARO"
rm -f "$TMP_MISS"
SH

chmod +x repara_copia.sh
