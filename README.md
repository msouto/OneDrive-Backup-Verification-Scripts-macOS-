# ☁️ OneDrive Backup & Verification Scripts (macOS)

Este repositório contém **scripts shell avançados** para **backup incremental**, **verificação de integridade**, **sincronização local** e **reparo automatizado** de pastas do **Microsoft OneDrive** no macOS.

Os scripts foram desenvolvidos para o ambiente do **CCSL-IFRN**, integrando-se ao ecossistema de automação de backup do **Mac Mini de laboratório** e garantindo a integridade de dados sincronizados com a nuvem.

---

## 📦 Scripts Incluídos

### 🔹 `copiar_onedrive_interativo_progress.sh`

Realiza **backup incremental** e/ou **sincronização completa** de pastas do OneDrive para um volume externo.

**Recursos:**
- Detecta automaticamente múltiplas contas OneDrive locais;
- Permite selecionar backup existente ou criar novo;
- Exibe **barra de progresso em tempo real** (`pv`);
- Gera logs detalhados com data/hora no HD externo;
- Compatível com **openrsync (nativo)** e **rsync (Homebrew)**.

---

### 🔹 `verificar_backup_onedrive_interativo_progress.sh`

Compara origem e backup, verificando diferenças de **nomes e tamanhos** de arquivos.

**Recursos:**
- Analisa múltiplos diretórios OneDrive;
- Lista discrepâncias de forma legível;
- Gera relatórios de inconsistência (`relatorio_backup_*.log`);
- Compatível com os scripts de reparo (`repara_copia.sh`).

---

### 🔹 `repara_copia.sh`

Repara automaticamente os arquivos ausentes no backup com base nos relatórios de verificação (`verificacao_backup_*.log`).

**Principais funções:**
- Lê logs e extrai origem/destino;
- Identifica faltantes via `rsync` ou via bloco textual `⚠️ Arquivos ausentes no backup:`;
- Copia apenas os arquivos que não estão no backup;
- Ignora arquivos de sistema (`.DS_Store`, `.Trash`, etc.);
- Gera log de reparo em `~/Documents/onedrive_reparo_YYYY-MM-DD_HHMMSS.log`;
- Executa verificação pós-reparo (`rsync --dry-run`).

---

### 🔹 `materializa_nuvem.sh`

Força a **materialização local** (download físico) de todos os arquivos sob demanda do OneDrive.

**Uso:**
```bash
sudo sh materializa_nuvem.sh "/Users/<usuario>/Library/CloudStorage/OneDrive-IFRN"
```

Evita erros do tipo:
```
stat: No such file or directory
```

---

### 🔹 `forcar_materializar_nuvem.sh`

Versão automática que materializa todos os provedores (`OneDrive`, `iCloudDrive`, etc.) detectados no sistema.

**Recursos:**
- Usa `fileproviderctl domains` e `fileproviderctl materialize -r`;
- Executa em múltiplos domínios;
- Pode ser agendado via `cron` ou `launchd`.

---

## 🚀 Requisitos

As dependências estão listadas em [`requirements.txt`](./requirements.txt):

```bash
# Dependências do sistema
# Instale com Homebrew (https://brew.sh)
rsync
pv
```

Adicionalmente:
- macOS 13+ (Ventura ou superior);
- `fileproviderctl` nativo para controle de sincronização;
- Permissão de **Acesso Total ao Disco** para o Terminal.

---

## 📘 Como Usar

1. Dê permissão de execução:
   ```bash
   chmod +x copiar_onedrive_interativo_progress.sh verificar_backup_onedrive_interativo_progress.sh
   ```

2. Execute o backup:
   ```bash
   bash copiar_onedrive_interativo_progress.sh
   ```

3. Verifique a integridade:
   ```bash
   bash verificar_backup_onedrive_interativo_progress.sh
   ```

4. Repare arquivos faltantes (se houver):
   ```bash
   bash repara_copia.sh
   ```

---

## 🧩 Funcionalidades Gerais

- 🧭 Detecção automática de contas e pastas OneDrive locais;  
- 🔁 Sincronização incremental com verificação de tamanho e data;  
- ⏳ Exibição de barra de progresso (`pv`);  
- 🪶 Suporte total a `openrsync` e `rsync 3.x`;  
- 🧾 Geração de logs legíveis e datados;  
- 🔐 Compatibilidade total com o sistema de segurança do macOS;  
- ⚙️ Reparo automatizado de backups incompletos.

---

## 📦 Estrutura de Diretórios

```text
OneDrive/
├── copiar_onedrive_interativo_progress.sh
├── verificar_backup_onedrive_interativo_progress.sh
├── repara_copia.sh
├── materializa_nuvem.sh
├── forcar_materializar_nuvem.sh
├── requirements.txt
└── logs/
    ├── verificacao_backup_2025-10-30_17-40.log
    ├── verificacao_backup_2025-10-29_11-03.log
    └── relatorio_backup_2025-10-24_18-10.log
```

---

## ⚡ Fluxo Completo de Backup e Verificação

```bash
# 1️⃣ Materializar todos os arquivos do OneDrive (evita placeholders)
sudo ./materializa_nuvem.sh "/Users/moisessouto/Library/CloudStorage/OneDrive-IFRN"

# 2️⃣ Executar backup incremental com barra de progresso
bash copiar_onedrive_interativo_progress.sh

# 3️⃣ Verificar integridade do backup
bash verificar_backup_onedrive_interativo_progress.sh

# 4️⃣ Reparo automático (caso faltem arquivos)
bash repara_copia.sh
```

---

## 🧾 Histórico de Alterações

| Data | Alteração |
|------|------------|
| **2025-10-30** | Inclusão dos scripts `repara_copia.sh`, `materializa_nuvem.sh` e `forcar_materializar_nuvem.sh` |
| **2025-10-24** | Criação dos scripts `copiar_onedrive_interativo_progress.sh` e `verificar_backup_onedrive_interativo_progress.sh` |
| **2025-10-24** | Adicionado arquivo `requirements.txt` com dependências do sistema |

---

## 🧠 Créditos e Contexto

Desenvolvido por **Moisés Souto** no âmbito do  
**CCSL-IFRN — Centro de Competências em Soluções Livres**

---

## ⚖️ Licença

MIT License — uso livre para fins pessoais e acadêmicos.  
Ao reutilizar este código, mantenha a atribuição de autoria original.
