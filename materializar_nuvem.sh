# Veja os provedores registrados (deve listar o OneDrive)
fileproviderctl domains

# Baixe TUDO da pasta origem (pode demorar; deixa rodando)
fileproviderctl materialize -r "/Users/moisessouto/Library/CloudStorage/OneDrive-IFRN"

# (opcional) acompanhar
fileproviderctl list -n
