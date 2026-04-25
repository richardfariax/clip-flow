# ClipFlow (macOS)

Aplicativo nativo macOS para histórico de área de transferência, inspirado no `Windows + V`, com SwiftUI + AppKit, menu bar app, hotkey global e persistência local.

## Funcionalidades implementadas (MVP avançado)
- Monitoramento automático de clipboard via `NSPasteboard` com `changeCount`.
- Histórico de textos e imagens.
- Classificação de texto: link, email, código, texto longo e texto comum.
- Painel flutuante com atalho global padrão `Option + V`.
- Presets de hotkey global nas preferências.
- Busca no histórico.
- Navegação por teclado no painel (`↑`, `↓`, `Enter`, `Esc`).
- Favoritar item.
- Fixar item no topo.
- Excluir item individual.
- Limpar histórico completo.
- Colar item selecionado no app ativo (clipboard + simulação `Cmd + V`).
- Launch at Login (`SMAppService.mainApp`).
- Tela de permissões (Accessibility/Input Monitoring).
- Modo claro/escuro nativo.
- Menu bar app com ícone e ações rápidas.
- Pausar monitoramento.
- Ignorar apps sensíveis por `bundle id`.
- Não recaptura escrita programática feita pelo próprio ClipFlow.
- Criptografia local opcional (AES-GCM + chave no Keychain).
- Distribuição manual via GitHub Releases (`.zip` assinado/notarizado).

## Estrutura de pastas

```text
ClipFlow/
  App/
    ClipFlowApp.swift
    AppDelegate.swift
  Core/
    Models/
      ClipboardItemEntity.swift
      ClipboardTypes.swift
    Managers/
      AppSettings.swift
      HotkeyManager.swift
      LaunchAtLoginManager.swift
      MenuBarController.swift
      PermissionsManager.swift
    Services/
      ClipboardMonitorService.swift
      ClipboardStorageService.swift
      LocalCryptoService.swift
      PasteService.swift
    Utilities/
      ClipboardContentClassifier.swift
      HotkeySupport.swift
      KeychainHelper.swift
      NotificationNames.swift
  UI/
    Components/
      ClipboardCardView.swift
      VisualEffectBlur.swift
    ViewModels/
      ClipboardPanelViewModel.swift
    Views/
      ClipboardPanelController.swift
      ClipboardPanelView.swift
      PermissionsView.swift
      SettingsView.swift
  Resources/
    Assets.xcassets/
      ClipFlowLogo.imageset/
    ClipFlow.entitlements
    Info.plist
ClipFlowTests/
Docs/
  GITHUB_RELEASE.md
  NOTARIZATION.md
Scripts/
  release.sh
README.md
```

## 1) Passo a passo: criar projeto no Xcode

1. Abra o Xcode e crie projeto `App` (`macOS`, interface `SwiftUI`, linguagem `Swift`).
2. Nomeie como `ClipFlow`.
3. Defina deployment target em `macOS 14.0+` (SwiftData).
4. Em `Signing & Capabilities`, configure Team e Bundle ID.
5. Em `Build Settings`, aponte `Info.plist` para `ClipFlow/Resources/Info.plist`.
6. Adicione os arquivos Swift da pasta `ClipFlow/` ao target.
7. Remova arquivos padrão criados pelo template que conflitem com `ClipFlowApp.swift` e `AppDelegate.swift`.
8. Execute (`Run`) e confirme que o app abre apenas na menu bar.

### Logo do app (ClipFlow)
1. Abra `ClipFlow/Resources/Assets.xcassets`.
2. Selecione `ClipFlowLogo.imageset`.
3. Arraste a imagem enviada (`ClipFlow`) para os slots `1x` e `2x`.
4. O app já usa esse asset automaticamente na menu bar, painel e preferências.

## 2) Launch at Login

1. O app já inclui `LaunchAtLoginManager` usando `SMAppService.mainApp`.
2. No app, abra `Preferências` e ative `Iniciar com o macOS`.
3. Teste encerrando e relogando no macOS.

## 3) Hotkey global

1. Hotkey padrão: `Option + V`.
2. Registro via Carbon em `HotkeyManager` com `RegisterEventHotKey`.
3. No `AppDelegate`, o evento abre/fecha o painel flutuante.
4. Em `Preferências > Atalho Global`, selecione um preset.
5. Se necessário, use `Reaplicar Atalho`.

## 4) Distribuição Manual (GitHub)

1. Gere o artefato com `./Scripts/release.sh`.
2. (Recomendado) Notarize seguindo [Docs/NOTARIZATION.md](Docs/NOTARIZATION.md).
3. Publique o `.zip` no GitHub Releases conforme [Docs/GITHUB_RELEASE.md](Docs/GITHUB_RELEASE.md).

## 5) Permissões macOS

- `Accessibility`: necessária para colagem automática (`Cmd + V` sintético).
- `Input Monitoring`: recomendada para máxima robustez de hotkeys globais.
- A tela de permissões está embutida em `Preferências`.

## 6) Geração de release

1. Atualize `MARKETING_VERSION` e `CURRENT_PROJECT_VERSION`.
2. Gere archive Release:

```bash
./Scripts/release.sh
```

3. Notarize conforme [Docs/NOTARIZATION.md](Docs/NOTARIZATION.md).
4. Faça `staple` e publique `.zip` no GitHub Releases.
5. Inclua checksum `SHA256` para validação.

## 7) Requisitos de assinatura e notarização

- Target preparado para assinatura (`Developer ID`) e fluxo de notarização.
- Guia operacional em [Docs/NOTARIZATION.md](Docs/NOTARIZATION.md).

## 8) Melhorias futuras sugeridas

1. Sincronização iCloud (CloudKit) com criptografia E2E opcional.
2. OCR de imagens copiadas para busca textual.
3. Snippets inteligentes com categorias e placeholders.
4. Preview avançado para Markdown, JSON e código com syntax highlighting.
5. Auto-expiração por tipo de conteúdo e políticas de retenção.
6. Telemetria local opcional de performance e falhas (privacy-first).
