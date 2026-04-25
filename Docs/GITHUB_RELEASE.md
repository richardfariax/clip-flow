# Distribuição Manual via GitHub Releases

## Objetivo
Publicar o `ClipVault.app` para instalação manual, sem mecanismo de atualização automática.

## Fluxo de publicação
1. Atualize versão do app (`MARKETING_VERSION` e `CURRENT_PROJECT_VERSION`).
2. Gere o artefato:

```bash
./Scripts/release.sh
```

Opcional: se quiser apontar workspace/projeto explicitamente:

```bash
XCODE_WORKSPACE="ClipVault.xcworkspace" SCHEME="ClipVault" ./Scripts/release.sh
# ou
XCODE_PROJECT="ClipVault.xcodeproj" SCHEME="ClipVault" ./Scripts/release.sh
```

3. (Recomendado) Notarize e faça staple usando o guia em `Docs/NOTARIZATION.md`.
4. Suba no GitHub Releases:
   - `build/ClipVault.zip` (ou `build/ClipVault-notarized.zip`)
   - `build/ClipVault.zip.sha256` (checksum)
5. Crie release notes com versão e mudanças.

## Passo a passo de instalação para usuário final
1. Baixar o `.zip` na página de Releases do GitHub.
2. Descompactar.
3. Arrastar `ClipVault.app` para `/Applications`.
4. Abrir o app.
5. Se o macOS bloquear na primeira execução:
   - Abrir `System Settings > Privacy & Security`.
   - Em “Security”, clicar em “Open Anyway”.

## Boas práticas
- Publicar sempre zip notarizado para evitar alertas de segurança.
- Manter checksum SHA256 para verificação de integridade.
- Não sobrescrever tags antigas de release.
