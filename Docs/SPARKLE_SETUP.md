# Sparkle OTA (ClipVault)

1. No Xcode, abra `File > Add Package Dependencies...`.
2. Adicione: `https://github.com/sparkle-project/Sparkle`.
3. Selecione o target `ClipVault` e vincule o produto `Sparkle`.
4. Em `Build Phases`, adicione script de assinatura Sparkle (se usar DSA/EdDSA para appcast).
5. Em `Info.plist`, adicione:

```xml
<key>SUFeedURL</key>
<string>https://seu-dominio.com/clipvault/appcast.xml</string>
<key>SUPublicEDKey</key>
<string>SUA_CHAVE_PUBLICA_ED25519</string>
```

6. Gere chave Sparkle (uma vez):

```bash
./bin/generate_keys
```

7. Publique `appcast.xml` e o `.zip` assinado da release no seu servidor/CDN.
8. O app já expõe `UpdateManager.checkForUpdates()` no menu bar item “Verificar Atualizações”.
