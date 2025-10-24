#!/usr/bin/env bash
# Script de verificação de integridade do backup do OneDrive com barra de progresso
# Desenvolvido para macOS com suporte a 'pv' (Pipe Viewer)
# Autor: Moisés Souto
# Data: 2025-10-24_15-48
# Consulte README.md para documentação completa.

set -euo pipefail

DEST_BASE="/Volumes/Untitled/OneDrive"
DATE_TAG="$(date +%Y-%m-%d_%H-%M)"
LOG_FILE="$DEST_BASE/verificacao_backup_$DATE_TAG.log"

echo "🕵️ Iniciando verificação — $(date)" | tee "$LOG_FILE"
echo "Destino: $DEST_BASE" | tee -a "$LOG_FILE"
echo "--------------------------------------------" | tee -a "$LOG_FILE"

SOURCES=$(ls -d "/Users/$USER/Library/CloudStorage/OneDrive"* 2>/dev/null || true)
if [ -z "$SOURCES" ]; then
  echo "❌ Nenhuma pasta OneDrive encontrada." | tee -a "$LOG_FILE"
  exit 1
fi

for SRC in $SOURCES; do
  NAME="$(basename "$SRC")"
  echo ""
  echo "📂 Verificando: $NAME" | tee -a "$LOG_FILE"

  BACKUPS=( $(ls -dt "$DEST_BASE"/${NAME}_Backup_* 2>/dev/null || true) )
  if (( ${#BACKUPS[@]} == 0 )); then
    echo "⚠️ Nenhum backup encontrado para $NAME" | tee -a "$LOG_FILE"
    continue
  fi

  echo "📚 Backups disponíveis:"
  i=1
  for bkp in "${BACKUPS[@]}"; do
    echo "  [$i] $(basename "$bkp")"
    ((i++))
  done
  echo ""
  read -rp "Selecione o número do backup a verificar: " choice
  if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#BACKUPS[@]} )); then
    SELECTED_BACKUP="${BACKUPS[$((choice-1))]}"
  else
    echo "❌ Opção inválida. Pulando $NAME." | tee -a "$LOG_FILE"
    continue
  fi

  echo "🔍 Comparando $SRC ↔ $SELECTED_BACKUP" | tee -a "$LOG_FILE"
  SRC_COUNT=$(find "$SRC" -type f | wc -l | tr -d ' ')
  DEST_COUNT=$(find "$SELECTED_BACKUP" -type f | wc -l | tr -d ' ')
  echo "📊 Origem: $SRC_COUNT | Backup: $DEST_COUNT" | tee -a "$LOG_FILE"

  echo "🔎 Verificando arquivos..."
  find "$SRC" -type f | pv -pt -i 1 -s "$SRC_COUNT" -N "Verificação $NAME" > /dev/null &

  TMP_SRC=$(mktemp)
  TMP_DEST=$(mktemp)
  find "$SRC" -type f -exec stat -f "%N|%z" {} \; | sort > "$TMP_SRC"
  find "$SELECTED_BACKUP" -type f -exec stat -f "%N|%z" {} \; | sort > "$TMP_DEST"
  killall pv 2>/dev/null || true

  MISSING=$(comm -23 <(cut -d'|' -f1 "$TMP_SRC") <(cut -d'|' -f1 "$TMP_DEST"))
  EXTRA=$(comm -13 <(cut -d'|' -f1 "$TMP_SRC") <(cut -d'|' -f1 "$TMP_DEST"))
  SIZE_DIFF=$(join -t'|' -j1 <(sort "$TMP_SRC") <(sort "$TMP_DEST") | awk -F'|' '$2 != $3 {print $1 " — origem: " $2 " bytes, backup: " $3 " bytes"}')

  if [ -z "$MISSING" ] && [ -z "$EXTRA" ] && [ -z "$SIZE_DIFF" ]; then
    echo "✅ Nenhuma diferença detectada. Backup íntegro." | tee -a "$LOG_FILE"
  else
    [ -n "$MISSING" ] && echo "⚠️ Arquivos ausentes:" | tee -a "$LOG_FILE" && echo "$MISSING" | tee -a "$LOG_FILE"
    [ -n "$EXTRA" ] && echo "⚠️ Arquivos extras:" | tee -a "$LOG_FILE" && echo "$EXTRA" | tee -a "$LOG_FILE"
    [ -n "$SIZE_DIFF" ] && echo "⚠️ Arquivos com tamanhos diferentes:" | tee -a "$LOG_FILE" && echo "$SIZE_DIFF" | tee -a "$LOG_FILE"
  fi

  rm -f "$TMP_SRC" "$TMP_DEST"
  echo "--------------------------------------------" | tee -a "$LOG_FILE"
done

echo "🕒 Fim da verificação: $(date)" | tee -a "$LOG_FILE"
echo "📄 Relatório salvo em: $LOG_FILE"
