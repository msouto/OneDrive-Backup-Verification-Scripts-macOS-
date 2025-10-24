#!/usr/bin/env bash
# Consulte README.md para documentação completa.
# Script de backup do OneDrive com barra de progresso e opção de sincronização
# Desenvolvido para macOS com suporte a openrsync ou rsync (Homebrew)
# Autor: Moisés Souto
# Data: 2025-10-24_15-48

set -euo pipefail

DEST_BASE="/Volumes/Untitled/OneDrive"
DATE_TAG="$(date +%Y-%m-%d_%H-%M)"
LOG_FILE="$DEST_BASE/relatorio_backup_$DATE_TAG.log"

# === Detecta rsync ===
if command -v /opt/homebrew/bin/rsync >/dev/null 2>&1; then
  RSYNC="/opt/homebrew/bin/rsync"
else
  RSYNC="/usr/bin/rsync"
fi

RSYNC_VERSION="$($RSYNC --version 2>&1 | head -1 || true)"
if echo "$RSYNC_VERSION" | grep -qi "openrsync"; then
  FLAGS="-av --stats"
else
  FLAGS="-aHAX --human-readable --itemize-changes"
fi

EXCLUDES=(--exclude ".DS_Store" --exclude ".Trash/" --exclude ".TemporaryItems/"
          --exclude "*.tmp" --exclude "*.lnk" --exclude "*.icloud")

SOURCES=$(ls -d "/Users/$USER/Library/CloudStorage/OneDrive"* 2>/dev/null || true)
if [ -z "$SOURCES" ]; then
  echo "❌ Nenhuma pasta OneDrive encontrada."
  exit 1
fi

mkdir -p "$DEST_BASE"
touch "$DEST_BASE/.teste" 2>/dev/null || { echo "❌ Sem permissão de escrita em $DEST_BASE."; exit 1; }
rm -f "$DEST_BASE/.teste"

for SRC in $SOURCES; do
  NAME="$(basename "$SRC")"
  echo ""
  echo "📁 Pasta detectada: $NAME"

  BACKUPS=( $(ls -dt "$DEST_BASE"/${NAME}_Backup_* 2>/dev/null || true) )
  if (( ${#BACKUPS[@]} > 0 )); then
    echo ""
    echo "📚 Backups anteriores:"
    i=1
    for bkp in "${BACKUPS[@]}"; do
      echo "  [$i] $(basename "$bkp")"
      ((i++))
    done
    echo "  [N] Criar novo backup completo"
    echo ""
    read -rp "Selecione um número para sincronizar ou [N]ovo: " choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#BACKUPS[@]} )); then
      DEST="${BACKUPS[$((choice-1))]}"
      echo "🔄 Sincronizando com backup existente: $DEST"
      SYNC_MODE="true"
    else
      DEST="$DEST_BASE/${NAME}_Backup_${DATE_TAG}"
      mkdir -p "$DEST"
      echo "🆕 Criando novo backup em $DEST"
      SYNC_MODE="false"
    fi
  else
    DEST="$DEST_BASE/${NAME}_Backup_${DATE_TAG}"
    mkdir -p "$DEST"
    echo "🆕 Nenhum backup prévio encontrado. Criando novo backup em $DEST"
    SYNC_MODE="false"
  fi

  echo "-------------------------------------------"
  echo "📂 Origem: $SRC"
  echo "📦 Destino: $DEST"

  TOTAL_FILES=$(find "$SRC" -type f | wc -l | tr -d ' ')
  echo "📊 Total de arquivos a copiar: $TOTAL_FILES"

  COUNT=0
  find "$SRC" -type f | pv -pt -i 1 -s "$TOTAL_FILES" -N "Backup $NAME" > /dev/null &
  PV_PID=$!

  $RSYNC $FLAGS "${EXCLUDES[@]}" "$SRC"/ "$DEST"/ | tee -a "$LOG_FILE"
  kill $PV_PID 2>/dev/null || true

  echo ""
  echo "✅ Backup concluído para $NAME"
  echo "-------------------------------------------"
done

echo ""
echo "🕒 Fim do backup: $(date)"
echo "📄 Log completo salvo em: $LOG_FILE"
echo "🎉 Processo finalizado com sucesso!"
