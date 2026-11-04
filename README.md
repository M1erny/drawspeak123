# Review Canvas

Nowy projekt aplikacji iPad do review UI: screenshoty na canvasie, zaznaczenia Apple Pencilem, komentarze głosowe i wymiana wersji z T3 Code przez Tailscale. Nazwa robocza.

Pierwszy etap: specyfikacja i interaktywny prototyp kluczowej interakcji. Aplikacja SwiftUI, rzeczywisty Pencil Pro, nagrywanie/transkrypcja oraz połączenie T3 Code to kolejne etapy opisane w specyfikacji.

## Pliki

- [Specyfikacja produktu](docs/PRODUCT.md) — wymagania, model, przepływy i kryteria akceptacji.
- [Prototyp interakcji](prototype/index.html) — samodzielny HTML; otwórz plik w przeglądarce, bez instalacji i serwera.
- [Integracja T3 Code](docs/T3-INTEGRATION.md) — możliwości potwierdzone w zainstalowanym buildzie i brakujące dowody.
- [Kierunek wizualny](docs/DESIGN.md).
- [Skill ui-review-variants](.agents/skills/ui-review-variants/SKILL.md) — źródło skilla projektu; kontrakt manifestu w podkatalogu `references`. Nie instalowano globalnie.

## Prototyp v2

Pełnoekranowy canvas z pływającymi paletami, pan/zoom i Fit All. `Now`, `Proposal A` i `Proposal B` są obok siebie. Każda propozycja ma osobny wybór iteracji. Przycisk Canvases otwiera inne review, z osobnym wątkiem, uwagami, stash i kamerą.

1. Zakreśl region myszą/Pencilem. Automatycznie otworzy się panel symulowanego nagrania. Palec domyślnie przesuwa canvas; rysowanie palcem można włączyć.
2. `Stop` tworzy przykładową transkrypcję PL/EN; popraw tekst i `Save Comment`. `Cancel Recording` zatrzymuje demo i zachowuje zaznaczenie oraz wpisany tekst.
3. `Auto Voice On` otwiera ustawienia; wyłączenie auto-startu dotyczy nowych zaznaczeń. Wtedy można pisać lub wybrać `Start Demo Voice`.
4. Otwórz `Notes`, wybierz uwagi i `Save Stash` albo `Review Batch`. Wszystkie uwagi w paczce należą do jednego canvasu/wątku. `Simulate Send` nie wysyła prawdziwej wiadomości.
5. Zmień canvas. Własne uwagi i stash nie mieszają się z drugim wątkiem. Aktywne nagranie kończy się na pierwotnym zaznaczeniu.
6. Menu `Canvas Actions` zawiera import, demo pull i eksport JSON.

## Granice dowodów

To HTML na fixture data. Nie otwiera mikrofonu, nie przechowuje prawdziwego audio i nie kontaktuje się z T3 Code. Pencil Pro squeeze, trwałe zasoby, speech/OAuth/Tailscale i promocja baseline wymagają natywnego MVP. Rzeczywiste gesty iPad i dostępność wymagają weryfikacji na urządzeniu.

Uwagi, ustawienia i stash są zapisywane w browser localStorage v2; nie migrujemy danych prototypu v1. Import obsługuje PNG/JPEG/WebP do 10 MB. Bajty importu pozostają wyłącznie w bieżącej sesji i nie trafiają do eksportu; po odświeżeniu widać placeholder, a nowe adnotacje na brakującym obrazie są zablokowane. Proporcje obrazów i znormalizowane kotwice są niezależne od transformacji canvasu.

Kierunek nowej wersji i uzasadnienie: [docs/DESIGN-V2.md](docs/DESIGN-V2.md). Krytyki osobnych modeli i decyzje po review: katalog `docs/reviews/`.

## Weryfikacja

Wyniki i zakres faktycznie uruchomionych sprawdzeń: [docs/VALIDATION.md](docs/VALIDATION.md). Podgląd HTML nie jest dowodem działania natywnego iPada, Pencil Pro, speech ani Tailscale.
