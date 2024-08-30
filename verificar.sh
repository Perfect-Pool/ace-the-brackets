#!/bin/bash

echo "Iniciando a verificação dos scripts..."

yarn verify-nft base-testnet
yarn verify-ace base-testnet
# yarn verify-library-1 base-testnet

# yarn verify-nft base
# yarn verify-ace base
# yarn verify-library-1 base
# yarn verify-library-2 base
# yarn verify-library-3 base
# yarn verify-nft-metadata base
# yarn verify-nft-image base

echo "Verificação concluída."
