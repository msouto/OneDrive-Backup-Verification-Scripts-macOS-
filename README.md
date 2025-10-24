# OneDrive Backup & Verification Scripts (macOS)

Este repositório contém dois scripts shell para **backup incremental** e **verificação de integridade** de pastas do OneDrive no macOS,
com suporte a **rsync**, **barra de progresso (`pv`)**, e **menus interativos**.

## 📦 Scripts incluídos
- `copiar_onedrive_interativo_progress.sh` — realiza backup ou sincronização incremental de pastas OneDrive.
- `verificar_backup_onedrive_interativo_progress.sh` — compara origem e backup, verificando nomes e tamanhos.

## 🚀 Requisitos
Veja `requirements.txt`.

## 📘 Como usar
1. Dê permissão de execução:
   ```bash
   chmod +x copiar_onedrive_interativo_progress.sh verificar_backup_onedrive_interativo_progress.sh
   ```
2. Execute o backup:
   ```bash
   bash copiar_onedrive_interativo_progress.sh
   ```
3. Verifique integridade:
   ```bash
   bash verificar_backup_onedrive_interativo_progress.sh
   ```

## 🧩 Funcionalidades
- Detecta automaticamente múltiplas contas OneDrive locais.
- Lista backups anteriores e permite sincronização incremental.
- Exibe barra de progresso (via `pv`).
- Gera logs detalhados no HD externo.
- Verificação por nomes e tamanhos de arquivos.
- 100% compatível com openrsync (macOS nativo) e rsync (Homebrew).

## 🧾 Estrutura de diretórios
```
.
├── copiar_onedrive_interativo_progress.sh
├── verificar_backup_onedrive_interativo_progress.sh
├── README.md
└── requirements.txt
```

## 📜 Licença
MIT License — uso livre para fins pessoais e acadêmicos.
