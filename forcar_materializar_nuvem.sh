# supondo que você já tenha um remote "onedrive" configurado
brew install rclone

# re-use a mesma lista construída pelo script (ela fica num tmp; então gere uma cópia manual):
LOG="/Volumes/Untitled/OneDrive/verificacao_backup_2025-10-30_17-40.log"
SRC="/Users/moisessouto/Library/CloudStorage/OneDrive-IFRN"
DST="/Volumes/Untitled/OneDrive/OneDrive-IFRN_Backup_2025-10-24_12-41"

# Reextraia os "faltantes" do bloco textual do seu log para um arquivo (ex.: miss.txt)
awk '/Arquivos ausentes no backup:/{flag=1;next} flag{
  line=$0; sub(/^[[:space:]]+/,"",line);
  if (line ~ /^(Verificando|Comparando|📊|🔍)$/ || line=="") exit;
  if (line ~ /^\//) print line;
}' "$LOG" \
| sed -E "s|^$SRC/||" | sed '/\.DS_Store$/d' | sort -u > miss.txt

# Copiar cada item direto da nuvem -> backup local
while IFS= read -r p; do
  rclone copy "onedrive:$p" "$DST" --create-empty-src-dirs --progress || echo "falhou: $p"
done < miss.txt
