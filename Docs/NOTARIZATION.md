# Assinatura e Notarização (Developer ID)

## Pré-requisitos
- Apple Developer Program ativo.
- Certificados instalados no Keychain:
  - `Developer ID Application`
  - `Developer ID Installer` (opcional para pkg)
- Xcode com `Automatically manage signing` ou manual configurado.

## Passo a passo
1. No target `ClipVault`, configure:
   - `Signing Certificate`: `Developer ID Application`
   - `Team`
   - `Bundle Identifier` único (ex.: `com.suaempresa.clipvault`)
2. Faça archive:

```bash
xcodebuild -scheme ClipVault -configuration Release -archivePath build/ClipVault.xcarchive archive
```

3. Exporte `.app` assinado (ou `.pkg`) com `xcodebuild -exportArchive`.
4. Envie para notarização:

```bash
xcrun notarytool submit build/ClipVault.zip \
  --apple-id "seu-apple-id" \
  --team-id "SEU_TEAM_ID" \
  --password "app-specific-password" \
  --wait
```

5. Staple no app:

```bash
xcrun stapler staple "build/ClipVault.app"
```

6. Verifique Gatekeeper:

```bash
spctl --assess --type execute --verbose "build/ClipVault.app"
```
