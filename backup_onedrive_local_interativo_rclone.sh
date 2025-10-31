#!/usr/bin/env bash
# backup_onedrive_local_interativo.sh
# Cópia interativa do OneDrive (conteúdo local) para HD externo usando rclone (sem login na nuvem)
# - Escolha da origem (OneDrive) e subpasta
# - Escolha do destino (/Volumes/<DISCO>/pasta)
# - Checagem de espaço livre antes de iniciar (com margem de 10%)
# - Cópia com checksums + log
# - Verificação one-way ao final
# Autor: Moisés Souto (adaptado pelo ChatGPT)
# Data: 2025-10-31

set -euo pipefail

# ============== Utilitários =================
die(){ echo "ERRO: $*" >&2; exit 1; }
hr(){ printf '%*s\n' "${COLUMNS:-80}" '' | tr ' ' -; }
need(){ command -v "$1" >/dev/null 2>&1 || die "Dependência ausente: $1"; }
readn(){ local p="$1"; local v; read -r -p "$p" v || true; echo "${v:-}"; }

human_bytes(){ awk 'function human(x){ s="BKMGTP"; while (x>=1024 && length(s)>1){x/=1024; s=substr(s,2)} return int(x+0.5) substr(s,1,1)} {print human($1)}'; }

bytes_free(){ # bytes livres da PARTIÇÃO onde está o diretório DEST_ROOT
  df -kP "$1" | awk 'NR==2{print $4*1024}'
}

size_bytes_rclone(){ # usa rclone size --json
  rclone size "$1" --json 2>/dev/null | awk -F'[:,}]' '/bytes/ {gsub(/[[:space:]]/,"",$3); print $3; exit}'
}

size_bytes_du(){ du -sk "$1" | awk '{print $1*1024}'; }

# ============== Checagens iniciais ==========
need rclone
need awk
need df
need find
need stat

echo "[INFO] Iniciando backup interativo OneDrive → HD externo"
hr

# ============== Seleção da origem (OneDrive) ==============
# Detecta roots do OneDrive em CloudStorage (pode haver mais de um)
CLOUD="$HOME/Library/CloudStorage"
mapfile -t ODS < <(find "$CLOUD" -maxdepth 1 -type d -name "OneDrive*" -print 2>/dev/null | sort)
[ "${#ODS[@]}" -gt 0 ] || die "Nenhum diretório 'OneDrive*' encontrado em $CLOUD"

echo "Selecione o OneDrive de origem:"
i=1; for d in "${ODS[@]}"; do echo "  $i) $d"; i=$((i+1)); done
CHOICE="$(readn "Número [1-${#ODS[@]}]: ")"
[[ "$CHOICE" =~ ^[0-9]+$ ]] || die "Escolha inválida."
(( CHOICE>=1 && CHOICE<=${#ODS[@]} )) || die "Escolha fora do intervalo."
SRC_ROOT="${ODS[$((CHOICE-1))]}"

echo
echo "[INFO] Origem selecionada: $SRC_ROOT"
echo "Deseja copiar a raiz inteira desse OneDrive ou escolher uma subpasta?"
echo "  1) Raiz inteira"
echo "  2) Escolher subpasta (até 2 níveis)"
SOPT="$(readn "Opção [1-2]: ")"
if [ "${SOPT:-1}" = "2" ]; then
  echo
  echo "[INFO] Listando subpastas (até 2 níveis) — pode demorar um pouco..."
  mapfile -t SUBS < <(find "$SRC_ROOT" -mindepth 1 -maxdepth 2 -type d -print 2>/dev/null | sort)
  [ "${#SUBS[@]}" -gt 0 ] || die "Nenhuma subpasta encontrada."
  j=1; for s in "${SUBS[@]}"; do printf "  %d) %s\n" "$j" "$s"; j=$((j+1)); done
  SCH="$(readn "Número da subpasta: ")"
  [[ "$SCH" =~ ^[0-9]+$ ]] || die "Escolha inválida."
  (( SCH>=1 && SCH<=${#SUBS[@]} )) || die "Escolha fora do intervalo."
  SRC="${SUBS[$((SCH-1))]}"
else
  SRC="$SRC_ROOT"
fi

[ -d "$SRC" ] || die "Origem não existe: $SRC"
echo "[OK] Origem final: $SRC"
hr

# ============== Seleção do destino (Volume e pasta) ==============
echo "[INFO] Procurando volumes em /Volumes..."
mapfile -t VOLS < <(find /Volumes -mindepth 1 -maxdepth 1 -type d -print 2>/dev/null | sort)
[ "${#VOLS[@]}" -gt 0 ] || die "Nenhum volume encontrado em /Volumes (HD externo montado?)."

echo "Selecione o volume de destino:"
k=1; for v in "${VOLS[@]}"; do echo "  $k) $v"; k=$((k+1)); done
VCH="$(readn "Número [1-${#VOLS[@]}]: ")"
[[ "$VCH" =~ ^[0-9]+$ ]] || die "Escolha inválida."
(( VCH>=1 && VCH<=${#VOLS[@]} )) || die "Escolha fora do intervalo."
DEST_VOL="${VOLS[$((VCH-1))]}"

# pasta (subdir) dentro do volume
SUG="OneDrive_Backup_$(date +%Y-%m-%d_%H%M)"
DEST_SUB="$(readn "Nome da pasta de destino dentro de '$DEST_VOL' [$SUG]: ")"
DEST_SUB="${DEST_SUB:-$SUG}"
DEST="$DEST_VOL/$DEST_SUB"
mkdir -p "$DEST"

echo "[OK] Destino final: $DEST"
hr

# ============== Estimar tamanho origem e espaço no destino ============
echo "[INFO] Estimando tamanho da origem..."
SRC_BYTES="$(size_bytes_rclone "$SRC" || true)"
if [ -z "${SRC_BYTES:-}" ]; then
  echo "[WARN] rclone size (json) indisponível; usando du (mais lento)..."
  SRC_BYTES="$(size_bytes_du "$SRC")"
fi
FREE_BYTES="$(bytes_free "$DEST_VOL")"

echo "[INFO] Origem: $(echo "$SRC_BYTES" | human_bytes)"
echo "[INFO] Livre no destino ($DEST_VOL): $(echo "$FREE_BYTES" | human_bytes)"

MARGIN=$(( SRC_BYTES/10 ))  # +10%
NEEDED=$(( SRC_BYTES + MARGIN ))
if [ "$FREE_BYTES" -lt "$NEEDED" ]; then
  echo
  echo "[WARN] Espaço insuficiente considerando margem de 10%:"
  echo "       Necessário ~ $(echo "$NEEDED" | human_bytes) | Livre: $(echo "$FREE_BYTES" | human_bytes)"
  CONT="$(readn "Deseja continuar mesmo assim? (digite SIM para prosseguir): ")"
  [ "$CONT" = "SIM" ] || die "Abortado pelo usuário."
fi

# ============== Logs e parâmetros ============
STAMP="$(date +%Y-%m-%d_%H%M%S)"
LOG_DIR="$HOME/Documents"
LOG_COPY="$LOG_DIR/rclone_localcopy_${STAMP}.log"
LOG_CHECK="$LOG_DIR/rclone_check_${STAMP}.log"
mkdir -p "$LOG_DIR"

EXCLUDES=(
  ".DS_Store"
  "._*"
  ".Spotlight-V100/**"
  ".Trashes/**"
  ".fseventsd/**"
)
RCLONE_EXCLUDES=()
for e in "${EXCLUDES[@]}"; do RCLONE_EXCLUDES+=( --exclude "$e" ); done

TRANSFERS="${TRANSFERS:-8}"
CHECKERS="${CHECKERS:-8}"

COPY_CMD=( rclone copy "$SRC" "$DEST"
  --create-empty-src-dirs
  --progress
  --stats-one-line
  --transfers="$TRANSFERS"
  --checkers="$CHECKERS"
  --checksum
  --copy-links
  "${RCLONE_EXCLUDES[@]}"
  --log-file="$LOG_COPY"
)

CHECK_CMD=( rclone check "$SRC" "$DEST"
  --size-only
  --one-way
  --progress
  --log-file="$LOG_CHECK"
)

echo
echo "[INFO] Resumo:"
echo "  Origem : $SRC"
echo "  Destino: $DEST"
echo "  Estimativa origem: $(echo "$SRC_BYTES" | human_bytes)"
echo "  Livre em $DEST_VOL: $(echo "$FREE_BYTES" | human_bytes)"
CONF="$(readn "Confirmar e iniciar a cópia? (SIM/NÃO): ")"
[ "$CONF" = "SIM" ] || die "Operação cancelada."

# ============== Execução =============
hr
echo "[INFO] Iniciando cópia (log: $LOG_COPY)"
"${COPY_CMD[@]}"

echo
echo "[INFO] Cópia concluída. Iniciando verificação one-way (log: $LOG_CHECK)"
"${CHECK_CMD[@]}" || echo "[WARN] Diferenças encontradas na verificação (consulte o log)."

# ============== Relatório final =============
hr
echo "[INFO] Relatório final:"
echo "  Origem:"
rclone size "$SRC" || true
echo
echo "  Destino:"
rclone size "$DEST" || true
echo
echo "[INFO] Últimas 20 linhas da verificação:"
tail -n 20 "$LOG_CHECK" || true
hr
echo "[OK] Backup finalizado."
echo "Logs:"
echo "  - Cópia:      $LOG_COPY"
echo "  - Verificação: $LOG_CHECK"
