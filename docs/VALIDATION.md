# Weryfikacja pierwszego etapu

Data: 2026-11-04. Zakres: specyfikacja, samodzielny HTML i źródło skilla, bez natywnego buildu.

## Wykonane

- `node --check /tmp/review-canvas-prototype-script.js` — exit 0. Skrypt wyodrębniony z aktualnego `prototype/index.html`.
- `html_preview` — wizualna inspekcja przy 1024, 728 i 390 CSS px; brak komunikatów konsoli. Po korekcie proporcji importu i ładowania stash ponowiono podgląd 1024 px, również bez błędów konsoli.
- Niezależny przegląd kodu — wykryto i poprawiono niedopasowanie SVG/pointer przy imporcie innego aspect ratio oraz stary tekst edytora po wczytaniu stash. SVG obrazu i warstwy ink współdzielą pełny viewport; proporcje kontenera wynikają z obrazu. Ładowanie stash zamyka/resetuje edytor i przywraca wybór zapisanej paczki.
- Specyfikacja — sprawdzone pokrycie wymaganych przepływów, etapów i granic dowodów; źródło 133 linie.
- Badanie T3 Code — inspekcja lokalnego `app.asar`; dokładne dowody i ograniczenia w `T3-INTEGRATION.md`. Bez połączenia do hosta.

## Sprawdzenia zakończone poprawnie (exit 0)

- Model paczek: `~/.local/bin/heavy-check node /tmp/review-canvas-model-check.cjs`. PASS: sprawdzono pustą paczkę/uwagę, kopię tekstu i geometrii w stash, przypisanie do snapshotu, grupowanie i wybór uwag, brak efektu wysyłki oraz odtworzenie zapisu.
- Skill: `~/.local/bin/heavy-check python3 ~/.codex/skills/.system/skill-creator/scripts/quick_validate.py .agents/skills/ui-review-variants` — `Skill is valid!`.

## Niezweryfikowane

Rzeczywiste gesty użytkownika na iPadzie i import różnych proporcji nie miały osobnego testu urządzeniowego. Inspekcja kodu i screenshot startowego stanu nie dowodzą pełnego przejścia interakcji.

Brak natywnego projektu Xcode/builda, testów Pencil Pro squeeze, nagrania i odsłuchu, transkrypcji PL/EN, natywnego zapisu/odtwarzania, OAuth i tailnet, uploadów, realnej wysyłki/pull, uzgodnienia timeoutów i importera manifestu. SwiftUI i integracja są kolejnym etapem, nie wynikiem tej weryfikacji.

Nie uruchamiano serwera deweloperskiego, instalacji pakietów, Dockera ani wysyłki do agenta. Nie utworzono zdalnego repo ani PR.

## V2 po Sol / Grok 4.7 / Opus 5.5

Kandydat oceniony niezależnie: commit 8e7f21f, SHA-256 HTML 2c69cfa0e2abce2e5943ce1f84f98285b2a4df9e94df79b1184ee83a4f0b2598. Raporty i decyzje: docs/reviews/DECISIONS.md.

Końcowy HTML po poprawkach: SHA-256 c5d564cb3adb1940520214c2b6755d5531369dfef174966733792637a4f3a277.

- Pierwszy queued model check zakończył się exit 75: timeout kolejki, nie uruchomił testów. To nie był pass.
- Ostateczny: ~/.local/bin/heavy-check node scripts/check-model.cjs — exit 0. Sprawdza rzeczywisty model inline oraz finalizer nagrywania z zastąpionymi wyłącznie efektami widoku: ustawienia, kopie geometrii i stash, grupowanie wiadomości, izolację canvas/thread, stabilne numery, Undo dokładnej uwagi, próg świadomego regionu, explicit Stop vs cancel/interruption, zachowanie tekstu użytkownika, osobną surową transkrypcję, zapis do pierwotnego właściciela, guard brakującego obrazu, roundtrip zapisu i składnię pełnego skryptu.
- Node syntax check: exit 0 dla aktualnego skryptu wyodrębnionego z HTML.
- html_preview końcowego kodu: 1194, 728, 390 CSS px; brak komunikatów konsoli. Screenshoty final-1194.png, final-728.png, final-390.png w docs/reviews/.
- Stany inscenizowane rzeczywistymi funkcjami aplikacji: nowy region → auto-start (final-recording-1194.png), podgląd paczki przez kliknięcie kontrolki w skrypcie (final-batch-1194.png), Add Region bez rysowania (final-region-728.png). Brak błędów konsoli. To potwierdza renderowanie tych stanów, nie pełne przejście gestem użytkownika.
- Przegląd wizualny: nieskalowane selektory i piny, brak jednoczesnego Start/Stop, REC przy kotwicy, wąski recorder bez zasłaniania B, miniatury screenshotów z numerowanymi obrysami w paczce, dostępne pola geometrii.

Nie wykonano ponownego niezależnego review po poprawkach ani nie nadano nowego score HIG/UX. Oceny z raportów dotyczą wyłącznie kandydata. Podstawowa wersja dark była sprawdzona na wcześniejszej kopii poprawek; nie jest to akceptacja wszystkich końcowych stanów w dark/increased contrast.

Nadal pending: fizyczny iPad, próg intencji/palm rejection, Pencil Pro squeeze, VoiceOver/Switch Control, Dynamic Type i klawiatura ekranowa, realne audio/przerwania/odsłuch/transkrypcja, trwałe zasoby natywne, OAuth/Tailscale/upload/push/pull. Nie uruchomiono usług, zdalnej wysyłki ani publikacji.

## V3 — HTML/DOM i ElevenLabs

Końcowy HTML SHA-256: 2ebe7b1f560f1eaa90d3748dffb4243930b63759ac064bbcd6d823e43ca46674.
Adapter ElevenLabs SHA-256: 71a380e7e9ad40410274e124e976128cf23dddffb78f72635c4eb309572c6560.

- heavy-check node scripts/check-model.cjs: exit 0. Obejmuje regresje v2 i nowe: wersję HTML w celu DOM, kopiowanie locatora, izolację canvasu/źródła, pressure depth/histerezę/release, brak zasobu HTML, jawnego providera oraz rzeczywisty handler zmiany na niegotowy widok (czyści poprzedni cel i blokuje Confirm).
- heavy-check node scripts/check-elevenlabs.mjs: 13/13 grup mock, exit 0. Pierwsza próba zakończyła się exit 75 bez wykonania; ponowienie z AGENT_GATE_LOCK_TIMEOUT=600 wykonało sprawdzenia. Brak realnego ruchu do API.
- Skill quick_validate.py: exit 0, Skill is valid. Zaktualizowano kontrakt HTML i domTarget.
- Osobny read-only przegląd poprawności Sol wykrył viewport 328×478 vs 330×480 oraz zachowanie starego celu przy ładowaniu nowego HTML. Oba miejsca poprawiono; zakres w reviews/HTML-CORRECTNESS.md. Bez ponownego niezależnego audytu końcowego kodu.
- html_preview: początkowy canvas przy 1194, końcowy przy 728 i 390 CSS px, bez błędów konsoli. Rzeczywiste iframe HTML są renderowane obok obrazu.
- Inscenizowane QA w html_preview używało rzeczywistych funkcji aplikacji po gotowości iframe: pomiar live 330×480; elementsFromPoint trafia w etykietę przycisku, pressure preview 0,5 wybiera Payment Section na poziomie 2. Konsola potwierdziła wynik, bez błędów.
- Druga ścieżka QA użyła File i importHTML na fixtures/stacked-components.html: parsowanie, hashe, ramka, hit-test nakładki, wybór warstwy pod nią, nacisk do rodzica Pay Button, commit domTarget do właściwej wersji i auto-start voice fixture. Konsola potwierdziła cały łańcuch. Nie był to ręczny gest ani pomiar sprzętu.
- Zrzuty stanów w reviews/: v3-dom-selection.png, v3-import-layer-comment.png, v3-canvas-728.png. QA dodaje wyłącznie skrypt inscenizacji do kopii podglądu; plik aplikacji go nie zawiera.

Pozostaje niezweryfikowane: nacisk i release na fizycznym Pencil, palm rejection, pełna izolacja niezaufanych scripted bundli, capture screenshotu HTML jako bajtów do rzeczywistej paczki, trwałe źródła i audio, mikrofon/ElevenLabs na koncie użytkownika, wdrożony host i T3/Tailscale. Statyczny HTML nie potwierdza wykonywania React/JS. Testy providera są mock, nie akceptacją jakości/retencji/kosztu konta.

## Natywny MVP — 2026-11-04

Gałąź `feat/native-mvp`. Aplikacja iPadOS 27 (SwiftUI, Swift 6.4), pakiet `Packages/DrawspeakKit`, projekt `App/project.yml`. Decyzje: [ADR-0007](adr/0007-native-mvp-implementation.md).

Wykonane (exit 0):

- `heavy-check swift test` w `Packages/DrawspeakKit`: 171 testów (Core 69, CanvasKit 45, VoiceKit 23, HTMLKit 22, T3Kit 12).
- `heavy-check xcodebuild … -scheme Drawspeak` na symulatorze iPad Pro 13" (iOS 27): build bez ostrzeżeń kompilatora.
- **T3 Code na żywo z symulatora**: parowanie kodem z `t3 auth pairing create` (rejestracja → decyzja → token PKCE → `initialize`), lista wątków z serwera, wysyłka paczki (1 kompozyt PNG + manifest) do izolowanego wątku testowego z ACK (`state: sent`, `messageId` serwera), odpowiedź agenta w formacie text-bundle i **Pull**: import propozycji HTML (`Proposal C`) z capture renderowanym na iPadzie. Ścieżka przez debugowy hook `DebugEndToEnd` (tylko DEBUG + symulator), który wywołuje te same metody co przyciski.
- **ElevenLabs na żywo**: `LiveElevenLabsTests` z kluczem z Apassy, syntetyczne nagranie PL (`say -v Zosia`): `detected=pol`, tekst zgodny, `scribe_v2`. Jedno płatne żądanie.
- Przegląd UI/kodu: raporty w `docs/reviews/native-v1/` (HIG — Opus, kod SwiftUI i UX — gpt-6.1-sol); poprawki P0/P1 wdrożone, zrzuty po poprawkach zweryfikowane.
- TestFlight: `scripts/testflight.sh` — archiwum Release, eksport z ręcznym podpisem, `altool --validate-app` (bez błędów) i upload.

Niezweryfikowane: fizyczny iPad i Apple Pencil (kalibracja nacisku, squeeze, odrzucanie dłoni), mikrofon na urządzeniu, VoiceOver/Dynamic Type na urządzeniu, tryb okienkowy iPadOS, przerwanie sieci w trakcie wysyłki, pobieranie PNG zwróconych przez agenta (poza MVP, ADR-0007).

## v2 — natywny interfejs i głos na żywo (2026-11-04)

- Przeglądy: `docs/reviews/native-v2/` (apple-design + copy audit — Opus; swiftui-pro A/B — gpt-6.1-sol), specyfikacja docelowa `TARGET-DESIGN.md`. Wdrożone: natywny toolbar (`.toolbarRole(.editor)`), sidebar canvasów, `.inspector` z uwagami i tekstem na żywo, Send jako popover, ~70% mniej tekstu, lokalizacja w pakietach, poprawki swiftui-pro.
- `xcodebuild test -scheme DrawspeakKit-Package` na symulatorze iPad Pro 13": 204 testy, exit 0 (2 testy Keychain pominięte bez hosta aplikacji).
- **Scribe v2 Realtime na żywo** (`LiveRealtimeTests`, klucz z Apassy, syntetyczne nagranie PL strumieniowane 4× szybciej): 5 wyników częściowych, zatwierdzony tekst zgodny z nagraniem, `finished`.
- Niezweryfikowane: mikrofon i czas startu nagrania na fizycznym iPadzie.
