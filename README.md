# 🧩 Sistema de Backup e Sincronização Local — OneDrive (macOS)

Este repositório contém um conjunto de **scripts utilitários para verificação, reparo e sincronização de backups locais do Microsoft OneDrive**, desenvolvidos para uso em ambientes de laboratório e servidores macOS (como o Mac Mini do CCSL-IFRN).

Os scripts automatizam a detecção e correção de inconsistências geradas pelo sistema **Files On-Demand**, garantindo que os arquivos estejam fisicamente disponíveis antes de qualquer cópia ou sincronização via `rsync`.

---

## 📘 Sumário

1. [Visão Geral](#visão-geral)
2. [Scripts Disponíveis](#scripts-disponíveis)
   - [`repara_copia.sh`](#1-repara_copiash)
   - [`materializa_nuvem.sh`](#2-materializa_nuvemsh)
   - [`forcar_materializar_nuvem.sh`](#3-forcar_materializar_nuvemsh)
3. [Fluxo de Operação Recomendado](#⚡-fluxo-de-operação-recomendado)
4. [Requisitos](#🧰-requisitos)
5. [Estrutura de Diretórios](#📦-estrutura-de-diretórios)
6. [Histórico de Alterações](#🧾-histórico-de-alterações)
7. [Créditos e Contexto](#🧠-créditos-e-contexto)
8. [Licença](#⚖️-licença)

---

## 📖 Visão Geral

O objetivo deste projeto é garantir **cópias locais confiáveis** do OneDrive, permitindo sincronização incremental, auditoria e recuperação de dados mesmo quando os arquivos originais estão disponíveis apenas como *placeholders* (arquivos sob demanda).

Esses scripts foram criados no contexto de infraestrutura do **CCSL-IFRN** para o controle de versões e preservação de dados de projetos como **Samanaú**, **Constelação Potiguar (GOLDS)** e integrações com o **INPE**.

---

## 🧩 Scripts Disponíveis

### 1. `repara_copia.sh`

Script principal responsável por **analisar logs de verificação** e **reparar arquivos ausentes** no backup.

#### 🔍 Funcionalidades

- Lê automaticamente o log mais recente (`verificacao_backup_*.log`);
- Extrai **origem** e **destino** diretamente do relatório (`📂 Verificando:` e `🔗 Comparando com backup:`);  
- Suporta dois formatos de log:
  - saída padrão do `rsync --itemize-changes` (`>f...`);
  - bloco textual `⚠️ Arquivos ausentes no backup:` com caminhos absolutos;
- Copia apenas os arquivos faltantes (`rsync --files-from`);
- Ignora arquivos de sistema e metadados (`.DS_Store`, `.Trash`, `.Spotlight-V100`, etc.);
- Gera log detalhado em:
  ```
  ~/Documents/onedrive_reparo_YYYY-MM-DD_HHMMSS.log
  ```
- Executa verificação pós-reparo (`rsync --dry-run`) para confirmar integridade.

#### 🧭 Uso

```bash
sh repara_copia.sh
# ou
./repara_copia.sh
```

Durante a execução:
1. Lista os logs disponíveis (ordem decrescente);
2. Solicita qual log utilizar;
3. Detecta origem e destino;
4. Exibe prévia dos faltantes e pede confirmação;
5. Inicia o reparo e acompanha o progresso.

> ⚠️ Execute **após materializar os arquivos** com `materializa_nuvem.sh`.

---

### 2. `materializa_nuvem.sh`

Garante que todos os arquivos do OneDrive estejam **fisicamente armazenados no disco local**, evitando falhas do tipo:

```
stat: No such file or directory
```

causadas por arquivos disponíveis apenas como *placeholders* do **Files On-Demand**.

#### ⚙️ Funções

- Usa `fileproviderctl` para forçar o download completo do conteúdo;
- Aceita como argumento o caminho da pasta sincronizada do OneDrive;
- Pode ser interrompido e retomado sem perdas.

#### 🧭 Uso

```bash
sudo sh materializa_nuvem.sh "/Users/<usuario>/Library/CloudStorage/OneDrive-IFRN"
```

#### 🧩 Internamente Executa

```bash
fileproviderctl domains
fileproviderctl materialize -r "/Users/<usuario>/Library/CloudStorage/OneDrive-IFRN"
fileproviderctl list -n
```

---

### 3. `forcar_materializar_nuvem.sh`

Versão automática e robusta do script anterior, que **detecta todos os domínios ativos** (`OneDrive`, `iCloudDrive`, `GoogleDrive`, etc.) e executa materialização recursiva em todos.

#### 🚀 Recursos

- Detecção automática de domínios via `fileproviderctl domains`;
- Materialização paralela de múltiplos provedores;
- Checagem de status e reexecução até 100% dos arquivos localizados;
- Compatível com agendamento via `cron` ou `launchd`.

#### 🧭 Uso

```bash
sudo ./forcar_materializar_nuvem.sh
```

> Ideal para execução periódica antes das rotinas de backup automatizado.

---

## ⚡ Fluxo de Operação Recomendado

```bash
# 1️⃣ Baixar todos os placeholders (garante que os arquivos existam fisicamente)
sudo ./materializa_nuvem.sh "/Users/moisessouto/Library/CloudStorage/OneDrive-IFRN"

# 2️⃣ Verificar backup existente
./verifica_copia.sh

# 3️⃣ Reparo automático de faltantes
./repara_copia.sh
```

Opcionalmente, use `forcar_materializar_nuvem.sh` para abranger múltiplos provedores em uma única execução.

---

## 🧰 Requisitos

| Dependência | Descrição | Instalação |
|--------------|------------|-------------|
| **macOS 13+** | Suporte nativo a FileProvider (OneDrive moderno) | Nativo |
| **rsync 3.x** | Compatível com `--protect-args` e `--whole-file` | `brew install rsync` |
| **fileproviderctl** | Controle de sincronização e domínios no macOS | Nativo |
| **rclone (opcional)** | Sincronização direta na nuvem (fallback) | `brew install rclone` |

> 🔒 Conceda **Acesso Total ao Disco** ao Terminal em:  
> Preferências do Sistema → Privacidade → Acesso Total ao Disco.

---

## 📦 Estrutura de Diretórios

```text
OneDrive/
├── verifica_copia.sh
├── repara_copia.sh
├── materializa_nuvem.sh
├── forcar_materializar_nuvem.sh
└── logs/
    ├── verificacao_backup_2025-10-30_17-40.log
    ├── verificacao_backup_2025-10-29_11-03.log
    └── relatorio_backup_2025-10-24_18-10.log
```

---

## 🧾 Histórico de Alterações

| Data | Alteração |
|------|------------|
| **2025-10-30** | Inclusão dos scripts `repara_copia.sh`, `materializa_nuvem.sh` e `forcar_materializar_nuvem.sh` |
| **2025-10-29** | Revisão dos relatórios de verificação (`verifica_copia_v2.sh`) |
| **2025-10-24** | Estrutura inicial de automação de backup local do OneDrive |

---

## 🧠 Créditos e Contexto

Desenvolvido por **Moisés Souto** no âmbito do  
**CCSL-IFRN — Centro de Competências em Soluções Livres**

Esses utilitários integram o ecossistema de scripts de engenharia e automação  
do laboratório, otimizando o gerenciamento de dados científicos e administrativos  
entre múltiplos provedores de nuvem.

---

## ⚖️ Licença

Distribuído sob a licença **MIT**.  
Você pode usar, modificar e redistribuir este software livremente,  
desde que mantenha a atribuição de autoria.
