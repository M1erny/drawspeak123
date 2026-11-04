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
