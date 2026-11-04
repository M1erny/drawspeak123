# Drawspeak

Projekt aplikacji Drawspeak na iPada do review UI: obrazy i makiety HTML na canvasie, zaznaczenia Apple Pencilem, komentarze głosowe i wymiana wersji z T3 Code przez Tailscale.

Stan: natywna aplikacja SwiftUI dla iPadOS 27 w TestFlight (`App/`, `Packages/DrawspeakKit`). Działa canvas z Now i propozycjami, zaznaczenia Pencilem, wybór komponentu HTML, głos z transkrypcją ElevenLabs, paczka Feedback (N) z wysyłką do wątku T3 Code i Pull propozycji HTML. Budowanie: `cd App && xcodegen generate`, testy: `cd Packages/DrawspeakKit && xcodebuild test -scheme DrawspeakKit-Package -destination "platform=iOS Simulator,name=Drawspeak iPad Pro 13"`, wydanie: [docs/RELEASE.md](docs/RELEASE.md). Klucz ElevenLabs jest wbudowany w build wydania (ADR-0008). Połączenie: T3 Code › Settings › Sharing & access › Create pairing link › Show code, a w Drawspeak „Choose Thread” → kod parowania.

## Pliki

- [PRD produktu](docs/PRD.md) — aktualne wymagania całej aplikacji, model, flow i kryteria akceptacji.
- [Rejestr ADR](docs/adr/README.md) — siedem przyjętych decyzji produktu i architektury.
- [Kontrakt T3 MCP](docs/T3-MCP-CONTRACT.md) i [wydanie TestFlight](docs/RELEASE.md).
- [Prototyp interakcji](prototype/index.html) — samodzielny HTML; otwórz plik w przeglądarce, bez instalacji i serwera.
- [Integracja T3 Code](docs/T3-INTEGRATION.md) — możliwości potwierdzone w zainstalowanym buildzie i brakujące dowody.
- [Kierunek wizualny](docs/DESIGN.md).
- [Skill ui-review-variants](.agents/skills/ui-review-variants/SKILL.md) — źródło skilla projektu; kontrakt manifestu w `references`. Zainstalowany globalnie jako dowiązanie: `~/.agents/skills/ui-review-variants` (Claude, Codex) i `.claude/skills` w projekcie.

## Docelowy przepływ feedbacku

Zaznaczenie → auto-głos przy ON → Stop → transkrypcja i autosave. Następnie Feedback (N) → podgląd → Send to Agent / Save Draft → Sent / Draft Saved. Po zebraniu gotowych uwag są dwa tapnięcia, bez osobnego Save Comment i dodatkowego potwierdzenia.

Paczka domyślnie obejmuje gotowe, niewysłane uwagi bieżącego canvasu i wyłącznie ich snapshoty. Jeden snapshot występuje raz z wieloma oznaczeniami; różne wersje są osobne. Puste regiony i trwające transkrypcje zostają w szkicu, bez blokowania gotowych uwag. Można odznaczyć uwagi w podglądzie. Draft jest lokalny; Sent wymaga ACK serwera.

Decyzja: [ADR-0004](docs/adr/0004-feedback-package-and-two-tap-delivery.md). Ten najnowszy flow nie jest jeszcze wdrożony w v3.

## Prototyp v3 — obrazy i HTML

Poniżej opis aktualnego kodu 08bd0da, z wcześniejszym Save Comment / Notes / Review Batch. To instrukcja demonstratora, nie źródło wymagań docelowych. Stan implementacji i różnice opisuje PRD, sekcja 12.

Pełnoekranowy canvas z pływającymi paletami, pan/zoom i Fit All. `Now` jest obrazem, `Proposal A` i `Proposal B` makietami HTML obok siebie. Każda propozycja ma osobny wybór iteracji. Przycisk Canvases otwiera inne review, z osobnym wątkiem, uwagami, stash i kamerą.

1. Zakreśl region myszą/Pencilem. Automatycznie otworzy się panel symulowanego nagrania. Palec domyślnie przesuwa canvas; rysowanie palcem można włączyć.
2. `Stop` tworzy przykładową transkrypcję PL/EN; popraw tekst i `Save Comment`. `Discard` odrzuca bieżące nagranie i pusty region; wpisany tekst oraz wcześniejsze nagrania pozostają. Usunięty region można przywrócić przez Undo. Przerwanie lub zmiana canvasu zachowuje wpisany tekst, bez dopisywania przykładowej transkrypcji.
3. `Auto Voice On` otwiera ustawienia; wyłączenie auto-startu dotyczy nowych zaznaczeń. Wtedy można pisać lub wybrać `Start Demo Voice`.
4. Otwórz `Notes`, wybierz uwagi i `Save Stash` albo `Review Batch`. `Load Copies` odtwarza stash jako nowe uwagi bez nadpisywania aktualnych edycji. Wszystkie uwagi w paczce należą do jednego canvasu/wątku. `Simulate Send` nie wysyła prawdziwej wiadomości.
5. Zmień canvas. Własne uwagi i stash nie mieszają się z drugim wątkiem. Aktywne nagranie kończy się na pierwotnym zaznaczeniu.
6. Menu `Canvas Actions` zawiera import, demo pull i eksport JSON.

Kontrolki wersji i piny mają stały rozmiar ekranowy przy zoomie. `Notes → Add Region` udostępnia zaznaczenie bez rysowania, z wyborem obrazu i edycją geometrii. Stare uwagi mają podgląd oryginału i `Show Source on Canvas`. Przypadkowe małe pociągnięcia nie uruchamiają głosu.

`Review Batch` grupuje miniatury z adnotacjami i tekstem; brak importowanego obrazu blokuje symulację wysłania. Wynik symulacji pozostaje w panelu i historii, wysłane w demo uwagi są odznaczane, a świadome ponowienie ma ostrzeżenie.

## Granice dowodów

To HTML na fixture data. Nie otwiera mikrofonu, nie przechowuje prawdziwego audio i nie kontaktuje się z T3 Code. Pencil Pro squeeze, trwałe zasoby, speech/OAuth/Tailscale i promocja baseline wymagają natywnego MVP. Rzeczywiste gesty iPad i dostępność wymagają weryfikacji na urządzeniu.

Uwagi, ustawienia i stash są zapisywane w browser localStorage v3; nie migrujemy danych prototypów v1/v2. Import obsługuje PNG/JPEG/WebP do 10 MiB oraz statyczny, samodzielny HTML do 2 MiB. Bajty importu pozostają wyłącznie w bieżącej sesji i nie trafiają do eksportu; po odświeżeniu widać placeholder, a nowe adnotacje na brakującym obrazie są zablokowane. Proporcje obrazów i znormalizowane kotwice są niezależne od transformacji canvasu.

HTML: narzędzie Select HTML Component wybiera element pod końcówką. Nacisk Pencila przechodzi do rodziców; mysz/klawiatura mają drzewo i pressure preview. Osobny wybór Layers rozróżnia element pod nakładką od rodzica. Zatwierdzenie zapisuje locator, hashe źródła/renderu i obrys, a potem startuje demo głosu. Zmienny nacisk wymaga testu fizycznego iPada; import HTML w tym prototypie nie wykonuje JS ani zasobów zewnętrznych.

Transkrypcja docelowa: ElevenLabs Scribe v2 po Stop. Gotowy jest adapter hosta Node i testy mock; nie ma jeszcze realnego capture, wdrożonego hosta ani połączenia z dostawcą. Klucz nie trafia do HTML. Szczegóły: [HTML i DOM](docs/HTML-REVIEW.md), [ElevenLabs](docs/ELEVENLABS.md).

Kierunek nowej wersji i uzasadnienie: [docs/DESIGN-V2.md](docs/DESIGN-V2.md). Krytyki osobnych modeli i decyzje po review: katalog `docs/reviews/`.

## Weryfikacja

Wyniki i zakres faktycznie uruchomionych sprawdzeń: [docs/VALIDATION.md](docs/VALIDATION.md). Podgląd HTML nie jest dowodem działania natywnego iPada, Pencil Pro, speech ani Tailscale.

Do sprawdzenia elementów pod nakładką: importuj prototype/fixtures/stacked-components.html, wybierz Select HTML Component, wskaż niebieską nakładkę, potem Views and Layers → warstwę pod spodem. Nacisk/suwak zmienia rodzica wybranej warstwy.

## Licencja

Drawspeak jest udostępniany na [licencji Apache 2.0](LICENSE). Copyright 2026 Rafał Wyderka. Informacje o prawach autorskich zawiera [NOTICE](NOTICE).

Cytaty i materiały osób trzecich wskazane w dokumentacji zachowują własne prawa i nie są objęte licencją tego projektu.
