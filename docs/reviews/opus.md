# Review v2 — Opus (apple-design + uxled-psychology)

Kandydat: `prototype/index.html`, SHA256 `2c69cfa0e2abce2e5943ce1f84f98285b2a4df9e94df79b1184ee83a4f0b2598` (zweryfikowany). Tryb: Audit. Przegląd niezależny. Nie czytałem innych raportów z `docs/reviews/`.
Przyjmuję jako ustalone: pełnoekranowy canvas, trzy widoki obok siebie, auto-start głosu domyślnie ON, jeden wątek na canvas. Krytykuję realizację tych decyzji, nie same decyzje.
Oznaczenia: **[kod]** to błąd widoczny w źródle, **[zrzut]** to obserwacja ze screenshotu, **[urządzenie]** to rzecz do sprawdzenia natywnie, **[ocena]** to moja ocena bez źródła w HIG.

## Werdykt

Model danych jest dobry. Najważniejsze elementy działają: nagranie należy do canvasu i uwagi, przy których się zaczęło, uwagi są związane z niezmiennym snapshotem, a canvas jest sprawdzany przy wysyłce i przy ładowaniu stasha. Najsłabsza jest warstwa stanu i odzyskiwania. Stan nagrania wyświetla się błędnie. Przypadkowe pociągnięcie otwiera (symulowany) mikrofon i zostawia pustą uwagę, która blokuje paczkę. Undo i Delete bez ostrzeżenia usuwają gotowe komentarze. Po wysyłce nie zostaje trwały ślad, więc łatwo wysłać tę samą paczkę drugi raz. Przy małej szerokości kontrolki i piny skalują się razem z treścią poniżej minimów HIG.
To 2× P0 i 4× P1. Wszystkie da się naprawić bez zmiany kierunku.

## Najważniejsze ustalenia

### 1. P0 — Panel nagrania pokazuje błędny stan [kod][zrzut]
- `recordingUI()` przełącza `hidden` na `Stop`, `Cancel Recording` i `Start Demo Voice` (`index.html:99`). Reguła `button{display:inline-flex}` (`index.html:9`) nadpisuje jednak systemowe `[hidden]{display:none}`. Jedyna reguła `[hidden]` to `.panel[hidden]`. W efekcie wszystkie trzy przyciski są zawsze widoczne. `v2-recording-1194.png` pokazuje `Stop` i `Start Demo Voice` naraz, podczas nagrania. Po zatrzymaniu `Stop` i `Cancel Recording` zostają na ekranie i nic nie robią.
- Przy auto-starcie stan mikrofonu jest najważniejszą informacją w aplikacji. Dziś niesie go tylko czerwona kropka w panelu. Panel przy regionie na `Proposal B` zasłania sam region (zrzut 1194, `.panel` po prawej). HIG: `apple-pencil-and-scribble.md › Best practices` — „Provide visual feedback to indicate a direct connection with content… Avoid letting Apple Pencil appear to initiate seemingly disconnected actions”. `feedback.md › Best practices` — „Consider integrating status feedback into your interface… near the items it describes”. `color.md` — nie polegać na samym kolorze.
- Własność treści: przy zmianie canvasu toast „transcript saved to its original selection” (`:102`) od razu zastępuje toast „… opened” (`:98`). Użytkownik nie dowiaduje się, dokąd trafiło nagranie. Gdy pole tekstowe nie jest puste, transkrypcja przepada (`:102`, `if(!n.text.trim())`), a `audio` nie ma pola na transkrypcję źródłową. To niezgodne z PRODUCT §6: „transkrypcja źródłowa jest zachowana osobno”.
- Poprawka: dodać `[hidden]{display:none!important}`. Przy nagrywaniu widoczne mają być tylko `Stop` (primary) i `Discard Audio`, w spoczynku tylko `Record Again`. Na pinie regionu pokazać znacznik `REC 00:12` z ikoną i tekstem. Transkrypcję zapisywać w `audio.transcript` i przy niepustym tekście proponować `Append Transcript`. Przy przerwaniu pokazać jeden komunikat: „Recording saved to Comment 3 · Checkout”. (**Feedback Loop**, **Signifiers**)

### 2. P0 — Przypadkowy region włącza mikrofon i zostawia pustą uwagę, która blokuje paczkę [kod]
- Domyślnym narzędziem jest Region (`:72`). Notatka powstaje, gdy zakres pociągnięcia przekracza 0,012 obrazu (`:107`), czyli przy skali 70% to około 3 px ekranu. Kod nie sprawdza zamknięcia obrysu, choć PRODUCT §6 mówi o „zamkniętym obrysie”. Mysz albo Pencil oparty o ekran może więc uruchomić nagranie.
- `Cancel Recording` zostawia uwagę pustą i zaznaczoną (`:51` `selected:true`, `:102`). Potem `Review Batch` i `Save Stash` zwracają ogólny błąd „Add a comment to every selected note.” (`:52`), który nie mówi, której uwagi dotyczy.
- HIG: `privacy.md › Best practices` — „Request access only to data that you actually need… or asking for data before a person shows interest”. `design-principles.md › Responsibility` — „Be fully transparent about what your product does and why”.
- Poprawka: próg liczyć na ekranie (przekątna ≥ 24 pt). Obrys uznać za zamknięty, gdy koniec leży w odległości ≤ 25% przekątnej od początku. Krótsze pociągnięcie to brak akcji, bez mikrofonu. Gdy panel zamyka się bez tekstu i bez audio, usunąć uwagę i pokazać `Empty region removed · Undo`. Błąd paczki ma wskazywać uwagi („Comment 3 has no text”) i dawać akcję `Exclude Unfinished (1)`. (**Default Bias** — w pełni poinformowany użytkownik chce auto-startu tylko przy zamierzonym regionie; **Negativity Bias**; **Recognition Over Recall**)

### 3. P1 — Undo i Delete niszczą gotowy komentarz; Load cicho nadpisuje [kod]
- `Undo Annotation` wykonuje `notes.pop()` (`:122`). Usuwa ostatnio utworzoną uwagę razem z zapisanym tekstem i audio, niezależnie od tego, jaka była ostatnia akcja. Przerywa też trwające nagranie (`finishRecording(true)`). Nie ma Redo ani wielokrotnego cofania.
- `Delete Note` stoi obok primary `Save Comment` (`:37`) i nie ma Undo (`:121`).
- `loadStash` przez `Object.assign` (`:54`) cicho nadpisuje nowszy tekst wersją ze stasha.
- HIG: `undo-and-redo.md › Best practices` — „Help people predict the results”, „Show the results of an undo”, „Let people undo multiple times”. `feedback.md › Best practices` — „Warn people when they initiate a task that can cause data loss that's unexpected and irreversible”.
- Poprawka: stos akcji obejmujący tworzenie regionu, edycję tekstu, usunięcie i ładowanie stasha. Etykieta Undo nazywa akcję, np. `Undo Delete Comment 3`. Dodać Redo. Po Undo wycentrować kamerę na przywróconym pinie. `Delete Note` przenieść do menu `⋯` albo na lewą krawędź panelu. `Load` przy konflikcie ma pytać: `Replace 2 Changed Notes` / `Load as Copies`. (**Loss Aversion** — rzetelnie, bez straszenia; **Fitts's Law** — destrukcyjne daleko od primary)

### 4. P1 — Send kontra stash: brak trwałego wyniku, łatwy duplikat [kod]
- `deliveries` są tylko dopisywane (`:129`) i nigdzie nie są wyświetlane. Po `Simulate Send` uwagi zostają zaznaczone, więc kolejne `Review Batch` wyśle je ponownie. PRODUCT §7 wymaga przy tym ostrzeżenia o duplikacie.
- Każde `Save Stash` dopisuje kopię (`:53`). Wiersz stasha ma tylko `Stash N · n notes`, bez czasu, nazwy i usuwania (`:96`). Uwagi nie pokazują, że są w stashu.
- Jedyne zakończenie przepływu to toast, który znika po 6,5 s (`:74`) i ma `pointer-events:none`. HIG: `accessibility.md › Cognitive` — „Minimize use of time-boxed interface elements… Prefer dismissing views with an explicit action”. `feedback.md` — „confirm that a significant action or task has completed”.
- Poprawka: dodać stany uwag `Working / Stashed / Sent · 14:32`, jako sekcje w Notes. Po wysyłce odznaczać wysłane uwagi. `Send Again` tylko z informacją o ryzyku duplikatu. Stash dostaje nazwę z czasu i `Delete`. Dialog po wysyłce pozostaje otwarty i pokazuje: „Simulated: 3 comments → T3 / Checkout exploration. Notes marked Sent.” z przyciskiem `Back to Canvas`. Zachować dwustopniową wysyłkę. (**Peak-End Rule**, **Feedback Loop**, **Provide Exit Points**)

### 5. P1 — Mała szerokość: kontrolki i piny skalują się z treścią [kod][zrzut][urządzenie]
- Nagłówki boardów z wyborem wersji i piny (`r=14` w viewBox) leżą wewnątrz transformowanego `.world` (`:88`, `:87`). Przy 728 px Fit All daje 56%. Picker ma wtedy około 25 px wysokości, a etykieta około 9,5 px (`v2-before-728.png`). Przy około 375 pt (Split View lub Slide Over) skala to około 0,27: obraz ma 89 px, pin około 8 px, picker około 12 px.
- To łamie zasadę z samego DESIGN-V2: „kontrolki są poza skalowaną treścią”. HIG: `accessibility.md › Mobility` — minimum 28×28 pt. `typography.md` — minimum 11 pt. `layout.md › Size classes` — „Keep functionality the same as size classes change”.
- Na ≤430 px panel komentarza ma pełną szerokość (`:12`) i zasłania region, którego dotyczy wypowiedź.
- Poprawka: nagłówek boardu (nazwa, wersja, liczba uwag) jako nakładka w przestrzeni ekranu, przypięta nad boardem, z polem dotyku ≥ 44 pt. Piny w stałym rozmiarze ekranowym. Zostawić trzy widoki w Fit All i dodać `Fit Pair` (Now+A, Now+B, A+B) oraz podwójne stuknięcie w board, które go dopasowuje (`gestures.md › Standard gestures`: double tap = zoom). Na compact użyć dolnego panelu w średniej wysokości i przesunąć kamerę tak, by region był nad panelem. (**Juxtaposition**, **Fitts's Law**)

### 6. P1 — Uwaga na niewyświetlanej iteracji znika z widoku [kod]
- `drawInk` rysuje tylko uwagi wyświetlanego snapshotu (`:87`). Zmiana wersji albo `Demo Pull` (`:130`, ustawia `a3`) ukrywa uwagi na `a2` bez słowa o nich. `openNote` (`:100`) nie przełącza widoku ani kamery.
- Numery pinów wynikają z indeksu w tablicy (`:87`, `:96`). Po usunięciu uwagi numery się przesuwają, a „uwaga 3” z nagrania wskazuje inny region.
- Poprawka: `Show on Canvas` przełącza tylko wyświetlaną wersję, nigdy nie przepina uwagi, i centruje region. Na nagłówku boardu znacznik `1 note on Version 2`. Toast po Pull: „A shows Version 3 · 1 note stays on Version 2 · Show”. Numery uwag stałe w obrębie canvasu. (**Recognition Over Recall**, **Mental Model**)

Izolacja wątków: nie znalazłem materialnego błędu. Właściciel nagrania (`:101–102`), canvas importu przechwycony przed asynchronicznym odczytem (`:132`) oraz sprawdzenia canvasu przy stashu i wysyłce (`:54`, `:129`) są poprawne. Drobna uwaga: kontekst panelu komentarza (`:100`) nie zawiera nazwy wątku T3, a dialog paczki ją zawiera. Warto ją dodać.

## Etyka i kontrola: auto-start głosu

Bramka z `audit-and-ethics.md › Part B` (**Default Bias** ⚠):
- **Transparency:** pigułka `Auto Voice On · Demo`, podpowiedź i komunikat ARIA przechodzą test. Osłabia go błąd 1.
- **Symmetry:** wyłączenie zajmuje 2 stuknięcia (pigułka → przełącznik, `:114`). Dobrze.
- **Reversibility:** Cancel nie cofa regionu (błąd 2), a Undo cofa za dużo (błąd 3). Dziś test jest zaliczony częściowo.
- **Alignment:** auto-start to wybór użytkownika, więc domyślne ON jest uprawnione. Ryzyko leży w mikrofonie otwieranym przez przypadkowe pociągnięcie, a nie w samym domyślnym ustawieniu.

Kompromis **[ocena]**: zachować ON. Dołożyć bramkę intencji (błąd 2), stan na regionie (błąd 1) i natychmiastowe `Discard`, które usuwa audio i pusty region jednym ruchem. W natywnym MVP prośba o mikrofon ma się pojawić przy pierwszym regionie. Jeśli będzie ekran przed alertem, to z jednym przyciskiem `Continue` (`privacy.md › Pre-alert screens`). Po odmowie bez ponawiania (**Reactance**). `accessibility.md › Cognitive` wymaga przy autoodtwarzaniu kontroli start/stop i globalnego opt-outu. Przenoszę tę regułę na autonagrywanie **[ocena]**, a projekt już ją spełnia.

## Dobre wzorce do zachowania
- Nagranie należy do canvasId/noteId z chwili startu. Zapis trafia do właściciela także po zmianie canvasu, iteracji, przy `visibilitychange` i `pagehide` (`:101–102`, `:135`).
- Auto-start tylko dla nowego Regionu. Strzałka, freehand i otwarcie starej uwagi go nie uruchamiają (`:100`, `:107`).
- Niezmienny `snapshotId` i brak cichego przepinania. Brakujący obraz blokuje nowe adnotacje (`:105`).
- Dwustopniowa wysyłka z feedforward („may start agent work… A stash never starts the agent”, `:39`). Każdy toast stasha mówi „No agent started”.
- Palec domyślnie przesuwa canvas. Pigułka głosu działa jako status i jako skrót do ustawień. Etykiety `Demo` są uczciwe.
- Wpisany tekst nie jest nadpisywany transkrypcją (`:102`). Trzeba tylko dodatkowo zachować samą transkrypcję (błąd 1).

## Zakres sprawdzeń
Przeczytałem: `prototype/index.html` w całości (hash zgodny), `docs/DESIGN-V2.md`, `docs/PRODUCT.md`, `README.md`, trzy zrzuty (Read/obraz).
apple-design: `SKILL.md` i część `AGENTS.md` dotycząca procesu. Strony HIG: `accessibility.md` (Mobility, Cognitive), `layout.md` (Visual hierarchy, Adaptability, Size classes), `privacy.md` (Best practices, Requesting permission, Pre-alert), `apple-pencil-and-scribble.md` (Best practices), `feedback.md`, `modality.md`, `undo-and-redo.md` i `design-principles.md` (Agency, Responsibility). Z `typography.md`, `color.md`, `gestures.md` i `designing-for-ipados.md` tylko fragmenty znalezione grepem. `cross-platform.md` pominąłem, bo cel to SwiftUI.
uxled-psychology: `SKILL.md`, `audit-and-ethics.md` (Part A checklisty, Part B), nazwy z `principles.md`.
Nie uruchamiałem przeglądarki, serwera, buildów ani testów. Rozmiary w px przy skalach wyliczyłem z CSS i kodu, nie zmierzyłem.

## Do weryfikacji natywnej [urządzenie]
Odrzucanie dłoni i progi Pencil w PencilKit. Systemowy wskaźnik mikrofonu i zachowanie przy pierwszej zgodzie i po odmowie. Przerwanie przez połączenie, Siri, blokadę ekranu lub Stage Manager: czy zapis fragmentu działa i zostaje przy właściwej uwadze. VoiceOver dla pinów i stanu nagrania. Pinch i pan przy Split View 1/3. Dynamic Type w nagłówkach boardów przeniesionych do przestrzeni ekranu. Pencil Pro squeeze. Prawdziwa transkrypcja PL/EN i jej scalanie z wpisanym tekstem.
