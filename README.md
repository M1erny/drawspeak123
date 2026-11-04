# Review Canvas

Nowy projekt aplikacji iPad do review UI: screenshoty na canvasie, zaznaczenia Apple Pencilem, komentarze głosowe i wymiana wersji z T3 Code przez Tailscale. Nazwa robocza.

Pierwszy etap: specyfikacja i interaktywny prototyp kluczowej interakcji. Aplikacja SwiftUI, rzeczywisty Pencil Pro, nagrywanie/transkrypcja oraz połączenie T3 Code to kolejne etapy opisane w specyfikacji.

## Pliki

- [Specyfikacja produktu](docs/PRODUCT.md) — wymagania, model, przepływy i kryteria akceptacji.
- [Prototyp interakcji](prototype/index.html) — samodzielny HTML; otwórz plik w przeglądarce, bez instalacji i serwera.
- [Integracja T3 Code](docs/T3-INTEGRATION.md) — możliwości potwierdzone w zainstalowanym buildzie i brakujące dowody.
- [Kierunek wizualny](docs/DESIGN.md).
- [Skill ui-review-variants](.agents/skills/ui-review-variants/SKILL.md) — źródło skilla projektu; kontrakt manifestu w podkatalogu `references`. Nie instalowano globalnie.

## Scenariusz prototypu

1. Porównaj `Now` i propozycję. Zmień wariant A/B lub iterację.
2. Zakreśl fragment, narysuj strzałkę lub swobodny ślad. Utworzona uwaga pozostaje przy tej wersji obrazu.
3. Wpisz komentarz albo wybierz `Demo voice`, sprawdź przykładową transkrypcję i zapisz.
4. Zaznacz kilka uwag. `Save stash` zapisuje lokalną kopię paczki. Zmiana komentarza nie zmienia zapisanej kopii.
5. `Review batch` pokazuje jedną paczkę i jej powiązania; `Simulate send` zapisuje wyłącznie symulację wysłania.
6. `Demo pull` dodaje przykładową wersję 3. `Export JSON` eksportuje dane demonstracyjne.

## Granice prototypu

Prototyp używa syntetycznych widoków SVG. Nie otwiera mikrofonu, nie zapisuje prawdziwego audio, nie kontaktuje się z T3 Code i nie obsługuje sprzętowego squeeze. Stany demo są jawnie oznaczone.

Uwagi i stash są zapisywane w localStorage przeglądarki, jeśli jest dostępne; nie jest to docelowy magazyn iPad. Import przyjmuje PNG/JPEG/WebP do 10 MB, jeden obraz na sesję. Obraz importowany zachowuje proporcje i otrzymuje własny identyfikator; jego bajty nie są utrwalane ani eksportowane. Po ponownym otwarciu mogą pozostać uwagi do niedostępnego obrazu. Natywne MVP ma przechowywać komplet obrazu, adnotacji i audio razem. Nie jest tu jeszcze zaimplementowany swobodny pan/zoom canvasu ani projekty z wieloma canvasami.

## Weryfikacja

Wyniki i zakres faktycznie uruchomionych sprawdzeń: [docs/VALIDATION.md](docs/VALIDATION.md). Podgląd HTML nie jest dowodem działania natywnego iPada, Pencil Pro, speech ani Tailscale.
