# Orbitile: o que falta fazer

Estado atual: o fluxo principal está implementado (abrir com clique do meio, famílias 2/4/6/8, teclas, clique em célula, merge por arraste, preview no destino real, cancelar, blur, animações). Nada disso foi validado com o app rodando. Os itens abaixo estão na ordem sugerida.

## 1. Validar no app real

Rodar `swift run Orbitile` e passar pela lista. Corrigir o que falhar antes de seguir.

- [ ] Clique do meio abre o overlay e soltar o botão não fecha.
- [ ] O disco centraliza no cursor e desliza para caber perto das bordas.
- [ ] Hover no anel troca a família; `2` `4` `6` `8` (linha principal e teclado numérico) também.
- [ ] Clique esquerdo numa célula aplica na hora.
- [ ] Arrastar sobre várias células faz merge e o preview mostra o retângulo envolvente.
- [ ] Soltar fora das células limpa a seleção e mantém o overlay aberto.
- [ ] `Esc`, clique fora do disco e clique do meio sem célula cancelam.
- [ ] Blur atrás do disco aparece sobre outras janelas ([OverlayPanel.swift](Sources/Orbitile/OverlayPanel.swift)).
- [ ] Animação de 220 ms da janela fica fluida. Se travar em apps lentos, reduzir os passos ou voltar ao movimento instantâneo ([WindowAccess.swift](Sources/Orbitile/WindowAccess.swift)).
- [ ] O clique do meio passa direto quando não há janela movível sob o cursor.
- [ ] O app alvo não perde o foco quando o overlay abre.

### Fidelidade ao design (r4a8 de [Merge.dc.html](design/Orbitile%20refinamento%20visual%20MVP/Merge.dc.html))

Refinado a partir do código do design. Conferir lado a lado com o mockup:

- [ ] O fan abre com uma família já ativa (a última usada, família 8 na primeira vez), arco azul e glifo branco, como no quadro "1 · Aberto".
- [ ] Hover numa célula clareia para branco 17%. O azul só aparece enquanto se pressiona ou arrasta, e o retângulo azul desliza entre seleções em 110 ms.
- [ ] Fatias do anel com gap de 6 pt e filete azul de 1.5 pt; glifos 20×13 com cantos externos arredondados em 3 pt.
- [ ] Hint em 10 pt Medium, branco 45%, a 43 pt do centro: "Click or drag" / "Release to apply".
- [ ] Cursor: o overlay não toma foco, então o app de baixo impunha o cursor dele (I-beam em editores). Agora o `MouseTap` liga `SetsCursorInBackground` (API privada do WindowServer, `CGSSetConnectionProperty`) e força `NSCursor.arrow`, e engole `mouseMoved` enquanto o overlay está aberto. Validar que a seta aparece sobre campos de texto e que o cursor volta ao normal ao fechar. Se a API privada quebrar em alguma versão do macOS, o plano B é uma janela do overlay que aceite mouse e use cursor rects.
- [ ] Efeitos do design ainda fora: nenhum ponto conhecido além dos itens acima. Qualquer diferença visual que sobrar entra aqui.

## 2. Corrigir os testes

- [ ] [LayoutTests.swift](Tests/OrbitileCoreTests/LayoutTests.swift) não compila: tem `width: 720 == height: 438` e `x: 119 == y: 119` no lugar de vírgulas, e `#expect(r, CGRect(...))` com dois argumentos. Trocar por `#expect(r == CGRect(...))`.
- [ ] Portar para o Swift Testing os checks novos que hoje só existem em [OrbitileChecks](Sources/OrbitileChecks/main.swift): drag, span, `select(family:)`, `targetRect(from:to:)` e `Easing`.
- [ ] Rodar `swift test` e `swift run OrbitileChecks` sem falhas.

## 3. Ícone na menu bar

Hoje usa o símbolo `square.grid.2x2` ([main.swift](Sources/Orbitile/main.swift)).

- [x] Gerar a marca como template image monocromática a partir de [logo.svg](docs/images/logo.svg): tile ativo sólido, os outros a 40% (regra do design).
- [x] Incluir variantes 1x/2x e marcar como `isTemplate` para funcionar em menu bar clara e escura.
- [x] Menu com Launch at Login (`SMAppService`, só funciona no `.app`) e Quit. Falta: Enable/Disable e About.

## 4. Permissões sem relançar

Hoje, sem Accessibility o app só imprime no stderr e não faz nada até ser relançado.

- [x] Detectar a permissão ausente e mostrar um aviso na menu bar com atalho para Privacy & Security → Accessibility.
- [x] Verificar `AXIsProcessTrusted()` periodicamente e iniciar o `MouseTap` assim que for concedida, sem relançar.
- [x] Tratar `tapCreate` falhando por falta de Input Monitoring com mensagem própria.
- [ ] Reativar o tap quando o sistema desabilitar (já há tratamento para timeout, validar na prática).

## 5. Empacotar como .app

- [x] `Info.plist` com bundle id, versão e `LSUIElement = true` (sem ícone no Dock).
- [x] Ícone `.icns` gerado de [icon-light.svg](docs/images/icon-light.svg) (todos os tamanhos do iconset).
- [x] Script `scripts/build-app.sh`: `swift build -c release`, monta `Orbitile.app/Contents/{MacOS,Resources,Info.plist}`.
- [x] Assinatura. Ad-hoc (`codesign -s -`) para uso local. Com assinatura estável a permissão de Accessibility não se perde a cada build.
- [ ] Documentar no README como conceder permissão ao `.app`, não ao terminal.

## 6. Casos de borda

- [ ] Vários monitores: o fan e o `visibleFrame` usam a tela do cursor. Validar com telas de escalas e alturas diferentes (conversão de coordenadas em [GestureSession.swift](Sources/Orbitile/GestureSession.swift)).
- [ ] Spaces e apps em tela cheia: o painel usa `.canJoinAllSpaces` e `.fullScreenAuxiliary`. Validar.
- [ ] Janelas que mudam de tamanho mínimo: após mover, ler o frame real e não assumir o pedido.
- [ ] Mouse sem botão do meio: avaliar gatilho alternativo configurável (por exemplo modificador + clique).
- [ ] Dock e menu bar ocultos automaticamente alteram o `visibleFrame`.

## 7. Preferências

- [x] Launch at Login via `SMAppService.mainApp`.
- [ ] Ligar/desligar o app pela menu bar.
- [ ] Margem entre janelas (hoje fixa em 6 pt, parâmetro `inset`).
- [ ] Escolher o botão de abertura.

## 8. Distribuição

- [ ] Nome do repositório e licença (`LICENSE`). Ainda não há licença definida.
- [ ] Assinar com Developer ID e notarizar (`notarytool`) para abrir sem aviso do Gatekeeper.
- [ ] Gerar `.zip` ou `.dmg` e publicar em GitHub Releases.
- [ ] Opcional: Homebrew cask.
- [ ] Atualizar a seção Install do [README.md](README.md) com o link do release.

## 9. Imagens do README

As imagens em `docs/images/` agora são renderizadas pelas próprias views SwiftUI do app (`swift run Orbitile --scenes <pasta>`, código em [Scenes.swift](Sources/Orbitile/Scenes.swift)) sobre um desktop de mentira. Não são gravações de tela do macOS.

- [x] Stills do overlay (aberto, clique, merge, preview no destino) e GIF do fluxo completo.
- [ ] Opcional: trocar por uma gravação de tela real (com o blur e a janela de verdade se movendo), gravada com `Cmd+Shift+5` e convertida com `ffmpeg`.

## 10. Opcional / depois

- [ ] Famílias extras (1/3, 2/3, 1/5) exploradas em [design/](design/Orbitile%20refinamento%20visual%20MVP/Orbitile%20Refinamento.dc.html).
- [ ] Modo claro do disco.
- [ ] Acessibilidade do overlay (VoiceOver, Reduce Motion desliga as animações).
- [ ] Localização: textos do hint hoje só em inglês.
