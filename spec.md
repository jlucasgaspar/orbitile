# Orbitile: o que falta fazer

Estado atual: o fluxo principal está implementado e o app já vem empacotado (`.app`, ícone, menu bar, permissões sem relançar, Enable/Disable, About, licença, script de release). O José testou o cursor, o blur, os eventos de mouse/teclado e a animação da janela em 2026-11-25 e disse que estava tudo certo. O que sobra está nas seções abaixo, na ordem sugerida.

## Resumo: o que falta

1. **Antes do primeiro release:** testar o `.app` (Launch at Login, foco do app alvo, clique do meio passando direto), consertar o `LayoutTests.swift` e publicar a v0.1.0 (seções 1, 2 e 8).
2. **Robustez no dia a dia:** vários monitores, Spaces e tela cheia, janelas com tamanho mínimo, Dock/menu bar ocultos e permissão revogada com o app rodando (seções 4 e 6).
3. **Sem dinheiro envolvido, mas depende de decisão:** gatilho alternativo para quem não tem botão do meio e as preferências (seções 6 e 7).
4. **Depende de uma conta Apple Developer:** assinatura Developer ID e notarização, para o app abrir sem aviso do Gatekeeper (seção 8).
5. **Opcional:** gravação de tela real, Homebrew cask, famílias extras, modo claro, acessibilidade e localização (seções 9 e 10).

## 1. Validar no app real

Marcados: validados pelo José em 2026-11-25. Os dois últimos itens (clique do meio sem janela movível e foco do app alvo) ainda não foram confirmados.

- [x] Clique do meio abre o overlay e soltar o botão não fecha.
- [x] O disco centraliza no cursor e desliza para caber perto das bordas.
- [x] Hover no anel troca a família; `2` `4` `6` `8` (linha principal e teclado numérico) também.
- [x] Clique esquerdo numa célula aplica na hora.
- [x] Arrastar sobre várias células faz merge e o preview mostra o retângulo envolvente.
- [x] Soltar fora das células limpa a seleção e mantém o overlay aberto.
- [x] `Esc`, clique fora do disco e clique do meio sem célula cancelam.
- [x] Blur atrás do disco aparece sobre outras janelas ([OverlayPanel.swift](Sources/Orbitile/OverlayPanel.swift)).
- [x] Animação de 220 ms da janela fica fluida. Se travar em apps lentos, reduzir os passos ou voltar ao movimento instantâneo ([WindowAccess.swift](Sources/Orbitile/WindowAccess.swift)).
- [ ] O clique do meio passa direto quando não há janela movível sob o cursor.
- [ ] O app alvo não perde o foco quando o overlay abre.

### Fidelidade ao design (r4a8 de [Merge.dc.html](design/Orbitile%20refinamento%20visual%20MVP/Merge.dc.html))

Refinado a partir do código do design. Conferir lado a lado com o mockup:

- [x] O fan abre com uma família já ativa (a última usada, família 8 na primeira vez), arco azul e glifo branco, como no quadro "1 · Aberto".
- [x] Hover numa célula clareia para branco 17%. O azul só aparece enquanto se pressiona ou arrasta, e o retângulo azul desliza entre seleções em 110 ms.
- [x] Fatias do anel com gap de 2.5 pt (o design usa 6, o José pediu mais junto) e filete azul de 1.5 pt; glifos 20×13 com cantos externos arredondados em 3 pt.
- [x] Hint em 10 pt Medium, branco 45%, a 43 pt do centro: "Click or drag" / "Release to apply".
- [x] Cursor: o overlay não toma foco, então o app de baixo impunha o cursor dele (I-beam em editores). Agora o `MouseTap` liga `SetsCursorInBackground` (API privada do WindowServer, `CGSSetConnectionProperty`) e força `NSCursor.arrow`, e engole `mouseMoved` enquanto o overlay está aberto. Validar que a seta aparece sobre campos de texto e que o cursor volta ao normal ao fechar. Se a API privada quebrar em alguma versão do macOS, o plano B é uma janela do overlay que aceite mouse e use cursor rects.

## 2. Corrigir os testes

- [x] [LayoutTests.swift](Tests/OrbitileCoreTests/LayoutTests.swift) consertado e o target de teste adicionado ao `Package.swift` (antes não existia).
- [x] Checks novos portados para o Swift Testing: drag, span, `select(family:)`, `targetRect(from:to:)`, `FanState(family:)` e `Easing`.
- [x] 19 testes passando com `scripts/test.sh` (com só as Command Line Tools, o `swift test` puro não acha o framework `Testing`; o script passa os caminhos). `swift run OrbitileChecks` sem falhas.

## 3. Ícone na menu bar

Hoje usa o símbolo `square.grid.2x2` ([main.swift](Sources/Orbitile/main.swift)).

- [x] Gerar a marca como template image monocromática a partir de [logo.svg](docs/images/logo.svg): tile ativo sólido, os outros a 40% (regra do design).
- [x] Incluir variantes 1x/2x e marcar como `isTemplate` para funcionar em menu bar clara e escura.
- [x] Menu com Launch at Login (`SMAppService`, só funciona no `.app`) e Quit. Enable/Disable (guardado em `UserDefaults`) e About também estão no menu.

## 4. Permissões sem relançar

Hoje, sem Accessibility o app só imprime no stderr e não faz nada até ser relançado.

- [x] Detectar a permissão ausente e mostrar um aviso na menu bar com atalho para Privacy & Security → Accessibility.
- [x] Verificar `AXIsProcessTrusted()` periodicamente e iniciar o `MouseTap` assim que for concedida, sem relançar.
- [x] Tratar `tapCreate` falhando por falta de Input Monitoring com mensagem própria.
- [ ] Reativar o tap quando o sistema desabilitar (já há tratamento para timeout, validar na prática).
- [x] Permissão revogada com o app rodando: um timer de 2 s confere `AXIsProcessTrusted()`; se cair, o tap é removido (`MouseTap.stop()`), o overlay aberto fecha sem aplicar e o menu volta a "Accessibility access needed". Ao conceder de novo, o tap volta sozinho. Falta só você confirmar na prática (revogar o Orbitile em Accessibility com ele rodando).

## 5. Empacotar como .app

- [x] `Info.plist` com bundle id, versão e `LSUIElement = true` (sem ícone no Dock).
- [x] Ícone `.icns` gerado de [icon-light.svg](docs/images/icon-light.svg) (todos os tamanhos do iconset).
- [x] Script `scripts/build-app.sh`: `swift build -c release`, monta `Orbitile.app/Contents/{MacOS,Resources,Info.plist}`.
- [x] Assinatura. Ad-hoc (`codesign -s -`) para uso local. Com assinatura estável a permissão de Accessibility não se perde a cada build.
- [x] Documentar no README como conceder permissão ao `.app`, não ao terminal.
- [ ] Testar o `.app` instalado em `/Applications`: Launch at Login liga e desliga, e o app sobe sozinho depois de reiniciar a sessão.

## 6. Casos de borda

- [ ] Vários monitores: o fan e o `visibleFrame` usam a tela do cursor. Validar com telas de escalas e alturas diferentes (conversão de coordenadas em [GestureSession.swift](Sources/Orbitile/GestureSession.swift)).
- [ ] Spaces e apps em tela cheia: o painel usa `.canJoinAllSpaces` e `.fullScreenAuxiliary`. Validar.
- [ ] Janelas que mudam de tamanho mínimo: após mover, ler o frame real e não assumir o pedido.
- [ ] Mouse sem botão do meio: avaliar gatilho alternativo configurável (por exemplo modificador + clique).
- [ ] Dock e menu bar ocultos automaticamente alteram o `visibleFrame`.

## 7. Preferências

- [x] Launch at Login via `SMAppService.mainApp`.
- [x] Ligar/desligar o app pela menu bar.
- [ ] Margem entre janelas (hoje fixa em 6 pt, parâmetro `inset`).
- [ ] Escolher o botão de abertura.

## 8. Distribuição

- [x] Licença MIT (`LICENSE`) e URL do repositório no README.
- [ ] (precisa de conta Apple Developer) Assinar com Developer ID e notarizar (`notarytool`) para abrir sem aviso do Gatekeeper.
- [x] `scripts/release.sh <versão>` gera o `.dmg` (app + atalho para Applications), o `.zip` e um `.sha256` de cada; com `--publish` cria o release via `gh`. Falta publicar o primeiro (v0.1.0): fazer o push, `gh auth login` e `scripts/release.sh 0.1.0 --publish`.
- [ ] Opcional: Homebrew cask.
- [x] Seção Install do [README.md](README.md) aponta para a página de Releases.

## 9. Imagens do README

As imagens em `docs/images/` agora são renderizadas pelas próprias views SwiftUI do app (`swift run Orbitile --scenes <pasta>`, código em [Scenes.swift](Sources/Orbitile/Scenes.swift)) sobre um desktop de mentira. Não são gravações de tela do macOS.

- [x] Stills do overlay (aberto, clique, merge, preview no destino) e GIF do fluxo completo.
- [ ] Opcional: trocar por uma gravação de tela real (com o blur e a janela de verdade se movendo), gravada com `Cmd+Shift+5` e convertida com `ffmpeg`.

## 10. Opcional / depois

- [ ] Famílias extras (1/3, 2/3, 1/5) exploradas em [design/](design/Orbitile%20refinamento%20visual%20MVP/Orbitile%20Refinamento.dc.html).
- [ ] Modo claro do disco.
- [ ] Acessibilidade do overlay (VoiceOver, Reduce Motion desliga as animações).
- [ ] Localização: textos do hint hoje só em inglês.
