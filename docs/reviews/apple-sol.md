## Design review: Review Canvas v2

### Summary

Ocena: **Critical issues** — główny przepływ nie ma alternatywy dla rysowania gestem, a kontrolki iteracji kurczą się razem z obrazami. Teza projektu jest czytelna: jedna przestrzeń do porównania Now i dwóch niezależnych propozycji oraz zebrania uwag w jedną paczkę. Charakter nadają czerwone kotwice na screenshotach i oszczędne pływające palety; warto zachować ten kierunek Freeform.

Przegląd HTML przeznaczonego do późniejszego przeniesienia do SwiftUI na iPad; odbiorcą jest osoba przeglądająca UI i przekazująca uwagi agentowi. Zweryfikowany SHA256 `prototype/index.html`: `2c69cfa0e2abce2e5943ce1f84f98285b2a4df9e94df79b1184ee83a4f0b2598`. Ustalenia opierają się na kodzie i trzech dostarczonych zrzutach, bez uruchamiania aplikacji.

### Critical

1. **[Critical] Nowej uwagi nie można utworzyć bez gestu rysowania.**
   - **Co:** `prototype/index.html:105` i `:107` tworzą uwagi wyłącznie z pointerdown/move/up; obsługa klawiatury w `:110` daje tylko pan/zoom. Istniejące kotwice mają Enter/Space (`:87`), lecz aktywacja narzędzia Region nie pozwala utworzyć pierwszej kotwicy klawiaturą. To luka potwierdzona statycznie, a nie wynik testu VoiceOver.
   - **Dlaczego:** `accessibility.md › Mobility`: „Offer alternatives to gestures”; `gestures.md › Custom gestures`: „Not the only way to perform an important action in your app or game”.
   - **Poprawka:** dodać dostępną akcję utworzenia regionu na wybranym obrazie z początkowym prostokątem, przesuwaniem i zmianą rozmiaru przyciskami/klawiaturą oraz zatwierdzeniem. Zatwierdzenie **nowego** regionu nadal natychmiast uruchamia głos przy Auto Voice ON; otwarcie istniejącej uwagi nie uruchamia go. Pokazać przy narzędziu krótką instrukcję: palec przesuwa, Pencil rysuje; obecne „Circle a detail” (`:95`) pomija domyślne zachowanie palca (`:105`).

2. **[Critical] Zoom pomniejsza także aktywne kontrolki porównania.**
   - **Co:** selektory iteracji znajdują się wewnątrz skalowanego `.world` (`prototype/index.html:9`, `:88`, `:92`). Na zrzucie 728 px kamera pokazuje 56%: nominalne minimum wysokości 44 CSS px staje się około **24,6 CSS px**, tekst 15 px około **8,4 px**. Średnica znacznika uwagi 28 jednostek (`:87`) spada do około **15,7 CSS px**. Przy 91% selektor ma minimum około 40 CSS px. Rozmiary screenshotu mogą się zmniejszać, lecz te elementy są kontrolkami aplikacji.
   - **Dlaczego:** `accessibility.md › Mobility`: „Offer sufficiently sized controls” — iPadOS: domyślnie 44×44 pt, minimum 28×28 pt; `typography.md › Ensuring legibility`: „Use font sizes that most people can read easily.” **CSS px nie są natywnymi punktami**; liczby pokazują utratę rozmiaru w HTML, a wartości pt są kryterium późniejszej implementacji.
   - **Poprawka:** przenieść nagłówki/selektory i hit regions kotwic do nieskalowanej warstwy lub kompensować skalę; zachować trzy obrazy obok siebie. Zapewnić cele 44×44 CSS px w prototypie, docelowo 44×44 pt. Przy compact zachować też nazwę dostępną Notes: `.wide-label{display:none}` (`:11`, przycisk `:21`) zostawia sam licznik, np. „2”; dodać niezależne `aria-label` z nazwą i liczbą.

### Improvements

3. **[High] Stan nagrywania pokazuje sprzeczne akcje.**
   - **Co:** zrzut `v2-recording-1194.png` pokazuje jednocześnie Demo Recording, Stop i Start Demo Voice. `recordingUI()` poprawnie ustawia `.hidden` (`prototype/index.html:99`), ale `button{display:inline-flex}` (`:9`) nadpisuje domyślne ukrywanie przycisku; jawny selektor `[hidden]` istnieje tylko dla paneli. Po Stop również grożą widoczne akcje nieaktywnego nagrania. Widok jest inscenizacją przez funkcje aplikacji, nie dowodem obsługi mikrofonu.
   - **Dlaczego:** `buttons.md › Content`: „Ensure that each button clearly communicates its purpose.” Jednoczesne Start i Stop utrudniają ocenę, czy automatyczny start już nastąpił.
   - **Poprawka:** zastosować konsekwentne `[hidden]{display:none!important}` albo warunkowo tworzyć akcje; nagrywanie: Stop + Cancel Recording, po zakończeniu: Start Demo Voice + zapis. Zachować domyślne ON, widoczny czas, tekstowy status i możliwość OFF dla nowych regionów. Close/Escape, zmiana panelu/canvasu i ukrycie dokumentu już kończą nagranie (`:78–79`, `:98`, `:135`); nie zgłaszam nagrywania ukrytego jako błędu.

4. **[High] Inspektor odbiera widok niezależnej propozycji.**
   - **Co:** na zrzucie nagrywania 1194 px prawy panel zasłania prawie cały Proposal B. Panel ma stałe 340 CSS px, pozycję top/right i nie wpływa na kamerę (`prototype/index.html:9`, `:77`, `:93`); Fit All liczy pełny viewport zamiast odsłoniętego obszaru. Wysokość panelu ogranicza stałe 590/580 px (`:9`, `:11`), a nie pozostała wysokość okna; ryzyko ucięcia w niskim oknie wynika z kodu, ale nie było testowane.
   - **Dlaczego:** `designing-for-ipados.md › Best practices`: „positioning onscreen controls where they’re easy to reach, but not in the way”; `layout.md › Adaptability` wymaga dostosowania do rozmiaru okna. Zachowanie pełnego porównania to również jawne wymaganie produktu.
   - **Poprawka:** utrzymać inspektor jako pływający element, lecz dobierać położenie i wysokość do wolnej przestrzeni; na compact zwijać drugorzędne pola i zostawiać widoczny pasek statusu/Stop. Fit powinien uwzględniać zajęty obszar, bez zmiany wzajemnej kolejności Now/A/B. Sprawdzić otwarty panel przy 728 px i klawiaturze ekranowej.

5. **[High] Otwarcie starej uwagi nie pokazuje jej oryginału.**
   - **Co:** zaznaczyć A/v2, przełączyć A/v1 i otworzyć dawną uwagę z Notes: `openNote()` (`prototype/index.html:100`) ustawia tekst/kontekst, ale nie przywraca wersji ani nie kadruje obrazu. `drawInk()` pokazuje kotwice tylko bieżącego snapshotu (`:87`); panel nie ma miniatury. Identyfikator oryginału jest zachowany (`:51`, `:84`), ale użytkownik widzi inne UI pod otwartym komentarzem. Ścieżka wywnioskowana z kodu, bez testu interakcyjnego.
   - **Dlaczego:** ocena projektowa na podstawie `docs/PRODUCT.md › 8. Wersje, propozycje i baseline`: stare anotacje mają otwierać oryginalny obraz. Samo zachowanie ID nie daje wizualnego punktu odniesienia.
   - **Poprawka:** przy otwarciu uwagi pokazać jej pierwotny snapshot i obrys — przez jawne przełączenie odpowiedniej iteracji z kadrowaniem lub niezmienny podgląd w inspektorze. Nie przepinać uwagi na aktualny obraz, nie zmieniać Now ani drugiej propozycji; dla niedostępnych bajtów pokazać stan brakującego oryginału.

6. **[High] Paczka przechodzi mimo brakującego importowanego obrazu.**
   - **Co:** po imporcie, dodaniu tekstowej uwagi i reloadzie `sessionImages` jest puste (`prototype/index.html:72`), placeholder i blokada **nowych** anotacji działają (`:89`, `:105`). Jednak `batch()` (`:52`) sprawdza tylko wybór, tekst i canvas, a Review Batch/Simulate Send (`:126`, `:129`) akceptują istniejącą uwagę bez obrazu. Podgląd zawiera tekst i JSON, więc nie pozwala zweryfikować screenshotu z obrysem. To ścieżka statyczna; nie przeprowadzono reloadu.
   - **Dlaczego:** ocena projektowa względem `docs/PRODUCT.md › 5. Ekrany i stany` i `› 7. Cykl paczki i bezpieczne dostarczanie`: brak załącznika ma blokować wysyłkę, a paczka obejmuje obrazy, anotacje i komentarze.
   - **Poprawka:** w podglądzie paczki grupować uwagi pod miniaturą właściwego snapshotu z obrysami; pokazać brak obrazu przy elemencie i zablokować Simulate Send. Nadal pozwolić odłożyć lokalny stash z jawnym oznaczeniem brakującego zasobu. Ponowny import tworzy nowy snapshot; nie przypisywać go automatycznie do dawnych uwag.

### Craft notes

Punkt widzenia jest spójny: duży, spokojny canvas, trzy kierunki równocześnie, jeden czerwony język anotacji. Systemowy krój słusznie oddaje pierwszeństwo obrazom; nie potrzeba dekoracyjnego brandingu. Zmniejszyć można instrukcję „Circle a detail” po pierwszym skutecznym zaznaczeniu, zachowując pomoc przy narzędziu; to ocena projektowa. Pływające warstwy warto zachować zgodnie z `layout.md › Visual hierarchy`: „Differentiate controls from content”; nie potrzeba obowiązkowego sidebaru ani tab bara.

### What works

- Osobne `versions.a/b`, niezależne selektory i Demo Pull zmieniający tylko A (`prototype/index.html:49`, `:88`, `:130`); Now pozostaje stabilne. Zrzuty 1194 i 728 potwierdzają układ Now + A + B obok siebie.
- Auto Voice domyślnie ON (`:48`), tylko nowy region uruchamia auto-start (`:107`); stare kotwice otwierają się bez auto-startu (`:87`). Stop/Cancel i edycja tekstu zachowują sprawczość; przełącznik OFF jest dostępny z pigułki głosu (`:114–115`).
- `canvasId/threadId`, osobne uwagi/stash/kamera oraz klonowanie batch/stash chronią separację wątków (`:49–55`, `:98`). Znormalizowana geometria i `snapshotId` nie są przepinane przy zmianie iteracji (`:51`, `:84`, `:103`).
- Jawne Prototype / disconnected / simulated, status bez mikrofonu oraz Simulate Send (`:22`, `:35`, `:39`, `:99`, `:129`) uczciwie opisują granice. Lokalny stash nie uruchamia agenta; jedna paczka zachowuje jeden wątek.
- Wiele kontrolek ma minimum 44 CSS px, etykiety ARIA, focus-visible, stany pressed, a kotwice obsługują Enter/Space (`:9`, `:19–40`, `:87`). Zachować te wzorce po naprawie skalowania.
- Kontrast obliczony z domyślnych wartości CSS, bez nadpisanych tokenów hosta: `#556171/#ffffff` **6,30:1**, `#556171/#f5f6f8` **5,82:1**, `#1758bd/#ffffff` **6,63:1**, dark `#b9c2cf/#24272b` **8,34:1** (`:8–10`). Przekraczają 4,5:1 dla zwykłego tekstu; nie jest to pomiar wszystkich pikseli zrzutów ani screenshotów treści. `color.md › Inclusive color` zaleca unikanie niewystarczającego kontrastu.

### Platform notes

- **Odczyty zakończone:** instrukcje AGENTS przekazane w zadaniu i `/Users/rafalw/.agents/skills/apple-design/AGENTS.md`; nie znaleziono AGENTS w projekcie ani sprawdzonych katalogach nadrzędnych. Przeczytano SKILL, routing table, cross-platform, code-audit, cały HTML, README, DESIGN-V2 i PRODUCT. Obejrzano narzędziem obrazu `docs/reviews/v2-before-1194.png`, `v2-before-728.png`, `v2-recording-1194.png`; obliczono kontrast i skalowanie, potwierdzono SHA256.
- **Źródła HIG:** lokalny zestaw `/Users/rafalw/.agents/skills/apple-design/references/hig/`: accessibility, layout, typography, color, designing-for-ios, designing-for-ipados, toolbars, buttons, gestures, privacy, materials, settings (12 plików). Cytaty odnoszą się wyłącznie do przeczytanych sekcji; nie sprawdzano aktualności online. Reguły natywne są kierunkiem dla SwiftUI, nie deklaracją zgodności HTML z iPadOS.
- **Natywne/do sprawdzenia:** VoiceOver/Switch Control/Full Keyboard Access, Dynamic Type do największych rozmiarów, Increase Contrast, safe areas w compact, klawiatura ekranowa, obrót/multitasking, faktyczne Pencil/palm rejection/pinch i anulowanie gestów. Nagrywający zrzut utworzono funkcjami aplikacji dla nowego regionu; nie dowodzi działania pointerów ani sprzętu.
- **Głos/integracja:** brak dowodu nagrywania audio, uprawnień systemowych, transkrypcji, trwałego audio lub działania T3/Tailscale. Przy natywnym wdrożeniu zachować auto-start ON i prosić o mikrofon w kontekście pierwszego nowego regionu; odmowa prowadzi do tekstu. `privacy.md › Requesting permission`: „Request permission only when your app clearly needs access to the data or resource.”
- **Materiały/ustawienia:** obecne palety są nieprzezroczyste; nie zgłaszam ich jako wadliwej imitacji Liquid Glass. Docelowo systemowe materiały w warstwie funkcjonalnej (`materials.md › Liquid Glass`) oraz kontekstowa regulacja głosu (`settings.md › Task-specific options`) pasują do tego modelu. Reduced motion/transparency mają reguły CSS (`:13–14`), lecz dostępność całego przepływu wymaga osobnej weryfikacji.
- **Zakres pracy:** zmieniono wyłącznie `docs/reviews/apple-sol.md`. Nie uruchamiano przeglądarki, serwera, buildów, instalacji ani testów sprzętowych; bez zmian źródeł, subagentów, commitów i PR.
