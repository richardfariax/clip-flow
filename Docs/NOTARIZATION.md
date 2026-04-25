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
2. Gere build de release e zip para distribuição manual:

```bash
./Scripts/release.sh
```

3. Envie o zip para notarização:

```bash
xcrun notarytool submit build/ClipVault.zip \
  --apple-id "seu-apple-id" \
  --team-id "SEU_TEAM_ID" \
  --password "app-specific-password" \
  --wait
```

4. Faça `staple` no app dentro do archive:

```bash
xcrun stapler staple "build/ClipVault.xcarchive/Products/Applications/ClipVault.app"
```

5. Gere novamente o zip final já com ticket de notarização:

```bash
ditto -c -k --sequesterRsrc --keepParent \
  "build/ClipVault.xcarchive/Products/Applications/ClipVault.app" \
  "build/ClipVault-notarized.zip"
```

6. Verifique Gatekeeper:

```bash
spctl --assess --type execute --verbose "build/ClipVault.xcarchive/Products/Applications/ClipVault.app"
```
