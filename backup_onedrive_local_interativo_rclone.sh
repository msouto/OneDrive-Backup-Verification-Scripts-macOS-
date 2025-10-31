#!/bin/sh
# backup_onedrive_local_interativo_rclone.sh (POSIX)
# Cópia interativa do OneDrive (conteúdo LOCAL) para HD externo usando rclone
# - Escolhe origem (raiz ou subpasta)
# - Escolhe volume/pasta de destino
# - Checa espaço livre (origem + 10%)
# - Copia com rclone e verifica (check one-way)
# Requer: rclone, awk, df, find, stat

set -eu

die() { printf '%s\n' "ERRO: $*" >&2; exit 1; }
hr() { printf '%s\n' "--------------------------------------------------------------------------------"; }

need() { command -v "$1" >/dev/null 2>&1 || die "Dependência ausente: $1"; }

human_bytes() {
  # uso: human_bytes <bytes>
  # conversão simples em awk (B,K,M,G,T,P)
  printf '%s\n' "$1" | awk 'function human(x){
    s="BKMGTP"; while (x>=1024 && length(s)>1){x/=1024; s=substr(s,2)}
    return int(x+0.5) substr(s,1,1)} {print human($1)}'
}

bytes_free() {
  # bytes livres no filesystem do caminho passado
  # POSIX df -kP: segunda linha coluna 4 = blocos livres em KB
  df -kP "$1" | awk 'NR==2{print $4*1024}'
}

size_bytes_rclone() {
  # tenta obter bytes com rclone size --json
  # devolve vazio se não conseguir
  rclone size "$1" --json 2>/dev/null | awk -F'[:,}]' '/bytes/ {gsub(/[[:space:]]/,"",$3); print $3; exit}'
}

size_bytes_du() {
  # fallback: du -sk (KB) -> bytes
  du -sk "$1" | awk '{print $1*1024}'
}

prompt_num() {
  # lê número; falha se vazio
  read -r ans || true
  [ -n "${ans:-}" ] || die "Entrada vazia."
  printf '%s' "$ans"
}

# ----------------- Checagens iniciais -----------------
need rclone; need awk; need df; need find; need stat
CLOUD="$HOME/Library/CloudStorage"

printf '[INFO] Iniciando backup interativo OneDrive → HD externo\n'
hr

# ----------------- Seleção da origem ------------------
[ -d "$CLOUD" ] || die "Diretório não encontrado: $CLOUD"

ODLIST="/tmp/odlist.$$"
find "$CLOUD" -maxdepth 1 -type d -name 'OneDrive*' -print 2>/dev/null | sort > "$ODLIST"
[ -s "$ODLIST" ] || die "Nenhum diretório OneDrive* encontrado em $CLOUD"

printf 'Selecione o OneDrive de origem:\n'
nl -ba "$ODLIST" | sed 's/^/  /'
printf "Número [1-$(wc -l < "$ODLIST")]: "
CHOICE="$(prompt_num)"
case "$CHOICE" in
  *[!0-9]*|'') die "Escolha inválida." ;;
esac
TOTAL="$(wc -l < "$ODLIST")"
[ "$CHOICE" -ge 1 ] && [ "$CHOICE" -le "$TOTAL" ] || die "Escolha fora do intervalo."
SRC_ROOT="$(sed -n "${CHOICE}p" "$ODLIST")"

printf '\n[INFO] Origem selecionada: %s\n' "$SRC_ROOT"
printf 'Deseja copiar a raiz inteira desse OneDrive ou escolher uma subpasta?\n'
printf '  1) Raiz inteira\n'
printf '  2) Escolher subpasta (até 2 níveis)\n'
printf 'Opção [1-2]: '
SOPT="$(prompt_num)"
if [ "$SOPT" = "2" ]; then
  SUBLIST="/tmp/subs.$$"
  printf '\n[INFO] Listando subpastas (até 2 níveis)...\n'
  find "$SRC_ROOT" -mindepth 1 -maxdepth 2 -type d -print 2>/dev/null | sort > "$SUBLIST"
  [ -s "$SUBLIST" ] || die "Nenhuma subpasta encontrada."
  nl -ba "$SUBLIST" | sed 's/^/  /'
  printf 'Número da subpasta: '
  SCH="$(prompt_num)"
  case "$SCH" in *[!0-9]*|'') die "Escolha inválida." ;; esac
  TOT2="$(wc -l < "$SUBLIST")"
  [ "$SCH" -ge 1 ] && [ "$SCH" -le "$TOT2" ] || die "Escolha fora do intervalo."
  SRC="$(sed -n "${SCH}p" "$SUBLIST")"
  rm -f "$SUBLIST"
else
  SRC="$SRC_ROOT"
fi
[ -d "$SRC" ] || die "Origem não existe: $SRC"
printf '[OK] Origem final: %s\n' "$SRC"
hr

# ----------------- Seleção do destino -----------------
VOLLIST="/tmp/vollist.$$"
find /Volumes -mindepth 1 -maxdepth 1 -type d -print 2>/dev/null | sort > "$VOLLIST"
[ -s "$VOLLIST" ] || die "Nenhum volume encontrado em /Volumes (HD externo montado?)."

printf '[INFO] Volumes encontrados em /Volumes:\n'
nl -ba "$VOLLIST" | sed 's/^/  /'
printf "Selecione o volume de destino [1-$(wc -l < "$VOLLIST")]: "
VCH="$(prompt_num)"
case "$VCH" in *[!0-9]*|'') die "Escolha inválida." ;; esac
VTOT="$(wc -l < "$VOLLIST")"
[ "$VCH" -ge 1 ] && [ "$VCH" -le "$VTOT" ] || die "Escolha fora do intervalo."
DEST_VOL="$(sed -n "${VCH}p" "$VOLLIST")"
rm -f "$VOLLIST" "$ODLIST"

SUG="OneDrive_Backup_$(date +%Y-%m-%d_%H%M)"
printf "Nome da pasta de destino dentro de '%s' [%s]: " "$DEST_VOL" "$SUG"
read -r DEST_SUB || true
[ -n "${DEST_SUB:-}" ] || DEST_SUB="$SUG"
DEST="$DEST_VOL/$DEST_SUB"
mkdir -p "$DEST"
printf '[OK] Destino final: %s\n' "$DEST"
hr

# ------------- Estimar tamanho / checar espaço --------
printf '[INFO] Estimando tamanho da origem...\n'
SRC_BYTES="$(size_bytes_rclone "$SRC" || true)"
if [ -z "${SRC_BYTES:-}" ]; then
  printf '[WARN] rclone size (json) indisponível; usando du (mais lento)...\n'
  SRC_BYTES="$(size_bytes_du "$SRC")"
fi
FREE_BYTES="$(bytes_free "$DEST_VOL")"

printf '[INFO] Origem: %s\n' "$(human_bytes "$SRC_BYTES")"
printf '[INFO] Livre no destino (%s): %s\n' "$DEST_VOL" "$(human_bytes "$FREE_BYTES")"

NEEDED=$(( SRC_BYTES + SRC_BYTES/10 ))  # +10% margem
if [ "$FREE_BYTES" -lt "$NEEDED" ]; then
  printf '\n[WARN] Espaço insuficiente considerando margem de 10%%:\n'
  printf '       Necessário ~ %s | Livre: %s\n' "$(human_bytes "$NEEDED")" "$(human_bytes "$FREE_BYTES")"
  printf 'Deseja continuar mesmo assim? (digite SIM para prosseguir): '
  read -r CONT || true
  [ "${CONT:-}" = "SIM" ] || die "Abortado pelo usuário."
fi

# ----------------- Logs e parâmetros -------------------
STAMP="$(date +%Y-%m-%d_%H%M%S)"
LOG_DIR="$HOME/Documents"
LOG_COPY="$LOG_DIR/rclone_localcopy_${STAMP}.log"
LOG_CHECK="$LOG_DIR/rclone_check_${STAMP}.log"
mkdir -p "$LOG_DIR"

# exclusões
EXC="--exclude .DS_Store --exclude ._* --exclude .Spotlight-V100/** --exclude .Trashes/** --exclude .fseventsd/**"

TRANSFERS="${TRANSFERS:-8}"
CHECKERS="${CHECKERS:-8}"

# ----------------- Resumo e confirmação ----------------
printf '\n[INFO] Resumo:\n'
printf '  Origem : %s\n' "$SRC"
printf '  Destino: %s\n' "$DEST"
printf '  Estimativa origem: %s\n' "$(human_bytes "$SRC_BYTES")"
printf '  Livre em %s: %s\n' "$DEST_VOL" "$(human_bytes "$FREE_BYTES")"
printf 'Confirmar e iniciar a cópia? (SIM/NÃO): '
read -r CONF || true
[ "${CONF:-}" = "SIM" ] || die "Operação cancelada."

hr
printf '[INFO] Iniciando cópia (log: %s)\n' "$LOG_COPY"
# shellcheck disable=SC2086
rclone copy "$SRC" "$DEST" \
  --create-empty-src-dirs \
  --progress \
  --stats-one-line \
  --transfers="$TRANSFERS" \
  --checkers="$CHECKERS" \
  --checksum \
  --copy-links \
  $EXC \
  --log-file="$LOG_COPY"

printf '\n[INFO] Cópia concluída. Iniciando verificação one-way (log: %s)\n' "$LOG_CHECK"
rclone check "$SRC" "$DEST" \
  --size-only \
  --one-way \
  --progress \
  --log-file="$LOG_CHECK" || printf '[WARN] Diferenças encontradas na verificação (consulte o log).\n'

hr
printf '[INFO] Relatório final:\n'
printf '  Origem:\n'
rclone size "$SRC" || true
printf '\n  Destino:\n'
rclone size "$DEST" || true
printf '\n[INFO] Últimas 20 linhas da verificação:\n'
tail -n 20 "$LOG_CHECK" || true
hr
printf '[OK] Backup finalizado.\n'
printf 'Logs:\n  - Cópia:       %s\n  - Verificação: %s\n' "$LOG_COPY" "$LOG_CHECK"
