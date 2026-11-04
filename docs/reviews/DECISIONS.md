# V2 — trzy krytyki i decyzje

Recenzenci oceniali tego samego kandydata: commit 8e7f21f, prototype/index.html SHA-256 2c69cfa0e2abce2e5943ce1f84f98285b2a4df9e94df79b1184ee83a4f0b2598. To raporty historyczne sprzed poprawek, a nie oceny końcowego kodu.

| Model | Skill | Raport i werdykt kandydata |
|---|---|---|
| GPT-6.1 Sol, high | apple-design | [apple-sol.md](apple-sol.md): 2 Critical, 4 High |
| Grok 4.7, high | uxled-psychology | [ux-grok.md](ux-grok.md): 6 P1; Ethics PASS |
| Claude Opus 5.5, high | oba | [opus.md](opus.md): 2 P0, 4 P1; odwracalność auto-startu częściowa |

Przeczytano pełne raporty i sprawdzono zarzuty w źródle. Każdy recenzent pisał własny plik, bez edycji prototypu i bez czytania raportów pozostałych. Raporty podają zakres przeczytanych referencji i brak testów urządzeniowych. Liczby CSS px w prototypie nie są pomiarem natywnych pt.

## Wprowadzone

| Problem | Decyzja / wynik |
|---|---|
| Start i Stop widoczne jednocześnie | Globalne [hidden]; w nagrywaniu tylko Stop/Discard; widoczny timer i REC przy kotwicy. |
| Nagrywanie zasłania B | Wąski pasek nad paletą; wszystkie trzy obrazy pozostają widoczne w stanie nagrywania. Inspektor edycji jest osobnym stanem. |
| Zbyt mały przypadkowy ruch startuje głos | Próg w przestrzeni ekranu, minimalna powierzchnia, zamknięty obrys lub świadomy diagonalny drag. Auto-start pozostaje ON. |
| Kontrolki kurczą się z obrazem | Nagłówki i selektory poza world; cele kotwic 44×44 CSS px w nieskalowanej warstwie. Podpisy są również nieskalowane. |
| Brak alternatywy dla gestu | Notes → Add Region: wybór screenshotu, cztery pola geometrii i jawne potwierdzenie; ta sama ścieżka auto-startu. |
| Niejasny tekst po przerwaniu | Tylko jawne Stop tworzy sample; przerwanie zachowuje wpisany tekst, zapisuje status interrupted i odznacza pustą uwagę. Nie dopisuje zdania. |
| Wpisany tekst wypiera źródłową transkrypcję | audio.transcript i historia metadanych poprzednich nagrań; Append Transcript; bez nadpisania edytowanego tekstu. To nadal fixture. |
| Pusty region po Discard | Jawne Discard usuwa pusty region; Undo odtwarza go. Błąd paczki wskazuje stały numer uwagi. |
| Delete obok Save; Undo usuwa inną uwagę | Delete w oddzielnej sekcji, nieaktywny podczas nagrania; stos dodania/usunięcia odtwarza ten sam id, indeks i dane. |
| Stash nadpisuje nowszy tekst | Load Copies tworzy nowe uwagi; oryginalne edycje pozostają. Stałe numery, sourceNoteId i ten sam snapshotId. Stashe mają czas; identyczny zapis nie duplikuje wpisu. |
| Uwaga znika po zmianie iteracji | Podgląd niezmiennego oryginału w uwadze; Show Source przełącza właściwą iterację i kadruje ją; link do uwag innych iteracji. Brak remapowania. |
| Numery pinów zmieniają znaczenie | Monotoniczny ordinal w canvasie, niezależny od indeksu tablicy; tożsamością wymiany pozostaje noteId. |
| Paczka bez obrazu i bez podglądu | Grupy miniatur z obrysami i numerami, tekst przy właściwym obrazie; brak bajtów importu blokuje wysyłkę demo, lokalny stash pozostaje dostępny. |
| Wysyłka kończy się samym toastem | Trwały wynik z odbiorcą, liczbą i Back to Canvas, historia w Notes; odznaczenie uwag; jawna informacja przy ponowieniu tej samej paczki. |

## Świadome granice

- Inspektor tekstu może czasowo zasłaniać część canvasu. Ma podgląd źródła; Fit All uwzględnia zajęty obszar. Samo nagrywanie pozostawia B widoczne. Nie przywracamy stałego sidebaru.
- Undo dotyczy anotacji i kopii, nie edycji tekstu. Redo, pełna historia edycji, Fit Pair i zarządzanie stashem jak w natywnej bibliotece są dalszym zakresem.
- Opus proponował wyłącznie zamknięty obrys. Zachowano również celowy drag do utworzenia regionu, istniejący w prototypie; oba wymagają progu intencji. Wartości CSS to decyzja prototypowa do pomiarów urządzeniowych.
- Rzeczywiste gesty Pencil, odrzucanie dłoni, Dynamic Type/VoiceOver i permission flow nie są potwierdzone przez screenshoty lub testy modelu.
- Oryginalne obrazy importów pozostają session-only w HTML. Brakujące zasoby są jawne; trwały magazyn należy do natywnego MVP.
- Nie wykonano ponownej niezależnej krytyki końcowego kodu. Końcowe sprawdzenia i zrzuty wykonał główny agent; nie nadajemy poprawionej wersji nowej oceny HIG ani UX score.
