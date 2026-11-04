# PRD — Review Canvas

Data: 2026-11-04. Status: przyjęty kierunek produktu i wymagania docelowe. Nazwa robocza: Review Canvas. Odbiorca MVP: jedna osoba pracująca z T3 Code na własnym iPadzie.

Ten dokument konsoliduje ustalenia rozmowy i zastępuje wcześniejszą specyfikację PRODUCT v1–v3. Powiązane decyzje są w [rejestrze ADR](adr/README.md). Status przyjętego wymagania nie oznacza, że funkcja jest zaimplementowana; stan kodu opisuje sekcja 12.

## 1. Problem i cel

Review UI wymaga dziś przełączania między widokiem aplikacji, zaznaczeniami, komentarzem i wątkiem agenta. Trudno wskazać właściwy komponent, zachować kontekst wersji oraz porównać kilka propozycji.

Aplikacja pozwala oznaczyć problem bezpośrednio na obrazie lub makiecie HTML, skomentować go głosem i przekazać wiele uwag w jednej wiadomości do właściwego wątku T3. Agent zwraca wersjonowane propozycje, które pozostają obok punktu odniesienia.

Sukces użytkownika: „Oznaczyłem UI, przekazałem spójną paczkę uwag i porównałem nowe propozycje bez utraty wersji, której dotyczył komentarz”.

## 2. Zakres MVP

| ID | Wymaganie |
|---|---|
| P-01 | Natywna aplikacja iPadOS w SwiftUI; trwały zapis lokalny i integracja T3 przez Tailscale. |
| P-02 | Pełnoekranowy canvas na wzór modelu pracy Apple Freeform: pan/zoom, swobodne rozmieszczenie widoków i pływające narzędzia/inspektory. |
| P-03 | Projekt zawiera wiele canvasów. Każdy canvas należy do dokładnie jednego wątku T3; różne wątki mają osobne canvasy. |
| P-04 | Obrazy i makiety HTML importowane ręcznie oraz pobierane z T3. |
| P-05 | Stabilne Now oraz niezależne propozycje obok siebie. Każda propozycja ma własne iteracje. |
| P-06 | Region/okrąg, strzałka i odręczny ślad; komentarze tekstowe i głosowe. |
| P-07 | Apple Pencil jako podstawowe narzędzie, Pencil Pro squeeze do palety, alternatywa palcem i dostępne odpowiedniki bez gestu. |
| P-08 | Wybór komponentu HTML przez nacisk: trafiony element → rodzice. Osobny wybór warstw dla elementów spod nakładki. |
| P-09 | Głos startuje automatycznie po zatwierdzeniu nowego zaznaczenia; ustawienie pozwala wyłączyć auto-start. |
| P-10 | Audio i transkrypcja PL/EN; dostawca ElevenLabs Scribe v2, po Stop. |
| P-11 | Automatyczne składanie feedbacku z gotowych, niewysłanych komentarzy; jedna wiadomość albo lokalny zapis paczki jako draft. |
| P-12 | Pull screenshotów/HTML, opisów zmian i statusów; własny manifest wersji, dostarczany przez skill. |
| P-13 | Skill tworzy klikalne propozycje UI i funkcji na fixture data, eksportuje materiały do review; implementacja w aplikacji po wyborze i poleceniu wdrożenia. |

Poza pierwszym zakresem: współpraca wielu osób, konta zespołowe, publiczna chmura współdzielenia, edycja layoutu aplikacji na canvasie, import Figmy i dowolnych publicznych stron WWW. Nie zastępuje to wymaganego runtime dla dostarczonych makiet HTML.

## 3. Canvas, nawigacja i wejście

Canvas jest główną przestrzenią pracy, zajmuje całe dostępne okno. Pływające palety zawierają wybór canvasu/wątku, import/pull, narzędzia, zoom i Feedback (N). Lista uwag, ustawienia i szczegóły są ujawniane na żądanie.

Now i wszystkie wybrane propozycje są obok siebie w jednym świecie canvasu. Fit All ułatwia orientację; zbliżenie pozwala ocenić detale. Kontrolki wersji i cele kotwic zachowują rozmiar ekranowy niezależnie od zoomu treści. Nagrywanie ma niewielki pasek Stop/Discard oraz widoczną kotwicę stanu.

Palec domyślnie przesuwa canvas, Pencil zaznacza/rysuje. Draw with finger udostępnia rysowanie palcem. Pencil Pro squeeze otwiera paletę przy końcówce; widoczny przycisk daje równoważną drogę. Gesty ustawione przez system należy respektować, gdy pasują do funkcji aplikacji.

Region można utworzyć także bez rysowania: wybór widoku i jawne określenie obszaru. Wybór komponentu HTML ma drzewo i kontrolki dla dotyku, myszy oraz klawiatury. Cele dotykowe projektujemy na 44×44 pt; stany mają etykiety, obsługę VoiceOver i systemowych ustawień dostępności.

## 4. Wersje i porównanie

Hierarchia: Project → ReviewCanvas → T3Thread; na canvasie: logiczny Screen → wersje/capture.

- Now jest jawnie przyjętym punktem odniesienia. Pull nie zmienia go samoczynnie.
- Proposal A/B/N są alternatywnymi kierunkami. Iteration 1/2/N to kolejne wersje w obrębie danego kierunku.
- Snapshot/capture jest niezmienny: źródło, hashe, viewport, stan, geometria i czas.
- Każda uwaga pozostaje na swoim źródłowym snapshotcie. Nowa wersja nie otrzymuje automatycznie starych kotwic ani locatorów.
- Otwarcie starej uwagi pokazuje jej oryginał; Show Source on Canvas pozwala odtworzyć właściwy kontekst.
- Promote to Now tworzy nową rewizję baseline i zachowuje historię.
- Wybór propozycji do dalszej pracy, polecenie implementacji i promocja do Now są oddzielnymi intencjami.

## 5. Obrazy i HTML

Obraz ma anotację geometryczną i komentarz. Wersja HTML ma również źródło/bundle, źródłowy hash, render policy, hash renderowanego dokumentu, viewport/stan i screenshot referencyjny.

Wybrany DOMTarget zawiera locator, nazwę komponentu, łańcuch trafienie→korzeń, wybraną głębokość/warstwę i obrys w przestrzeni capture. Preferowany locator to unikalne data-review-id, potem id, ostatecznie CSS ścieżka w tej wersji. Zmiana źródła, stanu lub viewportu wymaga nowego capture.

Lekki nacisk wybiera najwyżej położony element pod końcówką. Silniejszy nacisk przechodzi po jego rodzicach. Histereza i podgląd obrysu/nazwy stabilizują wybór. Podniesienie Pencila zatwierdza ostatnią stabilną głębokość; spadek siły przy release nie wraca do elementu na wierzchu. Hover i samo przeglądanie hierarchii nie tworzą komentarza.

Layers wybiera element spod nakładki w tym samym punkcie. To inny wymiar wyboru niż rodzic w DOM. Po wyborze warstwy nacisk nadal wybiera rodziców tej warstwy.

Runtime HTML musi izolować makietę od sekretów, poleceń T3 i zewnętrznych mutacji. Klikalne propozycje funkcji korzystają z fixture data. Obecny statyczny podgląd nie spełnia sam w sobie wymagań pełnego HTML/JS runtime; szczegóły w [HTML-REVIEW.md](HTML-REVIEW.md).

## 6. Głos i automatyczny zapis

Przebieg: zaznaczenie regionu lub zatwierdzenie DOMTarget → auto-start głosu → Stop → transkrypcja → automatyczny zapis uwagi. Użytkownik może poprawić tekst lub pominąć głos i wpisać komentarz.

Auto-start jest domyślnie ON, wyłączalny w ustawieniach. Dotyczy nowego zatwierdzonego wyboru; otwarcie starej uwagi, zmiana canvasu i restart nie zaczynają nagrania. Strzałka i odręczny ślad mogą pozostać samymi oznaczeniami.

Pencil musi wykazać intencję zaznaczenia; drobny przypadkowy ruch nie startuje mikrofonu. Dokładne progi siły/ruchu wymagają kalibracji na urządzeniu. Nagranie ma widoczny status, Stop i Discard.

Po Stop aplikacja zapisuje audio lokalnie przed uploadem do ElevenLabs. Oryginalne audio, surowa transkrypcja i tekst po edycji to osobne dane. Wynik przypisuje się przez canvasId/noteId/recordingId przechwycone przy starcie, również gdy użytkownik zmienił canvas. Późny wynik nie odtwarza usuniętej uwagi ani nie nadpisuje nowszego nagrania lub tekstu użytkownika.

Zgoda na mikrofon jest proszona w kontekście pierwszego użycia. Odmowa daje tekstową ścieżkę. Offline/błąd transkrypcji zachowuje audio i wpisany tekst; UI pokazuje stan oraz możliwość świadomego ponowienia. Nie fabrykujemy tekstu po przerwaniu.

**Osobne Save Comment nie należy do docelowego przepływu.** Stop, zakończona transkrypcja i edycja aktualizują trwały lokalny szkic automatycznie. Audio Capture/Transcribing to jeszcze nie gotowy komentarz do paczki.

## 7. Feedback: dokładne akcje użytkownika

Przyjęty przebieg: **Feedback (N) → podgląd → Send to Agent / Save Draft → potwierdzenie**.

| Krok | Działanie użytkownika | Działanie aplikacji |
|---|---|---|
| 1 | Zaznacza region lub komponent HTML. | Tworzy kotwicę; przy ON zaczyna głos. |
| 2 | Mówi i naciska Stop; opcjonalnie poprawia tekst. | Zapisuje audio, transkrybuje i autosave zapisuje uwagę. |
| 3 | Powtarza na innych widokach. | Aktualizuje automatycznie zbieraną paczkę i licznik gotowych uwag. |
| 4 | Naciska Feedback (N). | Otwiera podgląd paczki bieżącego canvasu i docelowego wątku. |
| 5a | Naciska Send to Agent. | Zamraża pokazany payload, uploaduje i tworzy jedną wiadomość. |
| 5b | Albo naciska Save Draft. | Odkłada pokazaną paczkę lokalnie, bez wykonania agenta. |
| 6 | Może wrócić przez Back to Canvas. | Pokazuje trwałe Sent / Draft Saved z odbiorcą i liczbą uwag. |

Po zebraniu gotowych uwag prawidłowa ścieżka to dwa tapnięcia: otwarcie podglądu i wybór akcji. Nie ma osobnego wyboru trybu przed podglądem ani dodatkowego potwierdzenia po Send to Agent.

### 7.1. Co trafia do paczki

- Domyślnie wszystkie gotowe, niewysłane komentarze bieżącego canvasu. Użytkownik może odznaczyć dowolne uwagi w podglądzie.
- Gotowa uwaga ma zapisaną niepustą treść tekstową i prawidłową kotwicę. Źródłem tekstu może być ukończona transkrypcja lub wpis użytkownika.
- Sam obrys/strzałka/ślad bez komentarza, aktywne nagranie i niedokończona transkrypcja zostają w lokalnym szkicu. Nie blokują pozostałych gotowych uwag.
- Dołączamy wyłącznie snapshoty, których dotyczą wybrane komentarze. Jeden snapshot jest pokazany/dołączony raz z wieloma numerowanymi anotacjami.
- Dwie wersje tego samego logicznego ekranu to dwa różne snapshoty, każdy z własnymi komentarzami.
- Uwaga z brakującym obrazem/HTML lub niezgodną wersją jest oznaczona jako niedostępna; wysyłka obejmująca ją jest blokowana do naprawy lub wyłączenia jej z zakresu.
- Paczka nigdy nie miesza canvasów ani wątków.

N wskazuje gotowe, niewysłane uwagi. Niedokończone mają osobny status/licznik; zakończenie transkrypcji podczas otwartego podglądu nie dopisuje jej po cichu do potwierdzanego zakresu.

### 7.2. Draft, wysłane uwagi i wznowienie

Bieżąca praca jest automatycznie zapisywana lokalnie. Save Draft odkłada konkretną paczkę wraz z zakresem/rewizjami do późniejszego wznowienia. To docelowa etykieta dla operacji nazywanej wcześniej stash; nie wprowadzamy osobnego kroku wyboru draft/stash.

Wznowienie nie nadpisuje nowszych edycji bez kontroli; zapisana paczka pozostaje odtwarzalna. Load Copies w prototypie jest istniejącym sposobem ochrony danych, nie obowiązkową nazwą docelowego UI.

Po potwierdzonym wysłaniu te rewizje uwag nie wracają domyślnie do kolejnej paczki. Nowa edycja stanowi nową rewizję; świadome Send Again wymaga widocznej informacji o powtórzeniu w tym samym podglądzie. Poprzedni payload pozostaje niezmienny.

## 8. Wysyłanie i odbieranie T3

Wybrany transport: natywny klient MCP do T3 Code po HTTPS w tailnecie. Tailscale zapewnia osiągalność, a autoryzacja T3 jest osobna. Cel wiadomości pochodzi z powiązania canvasu i jest widoczny w podglądzie.

Wiadomość zawiera brief, numerowane komentarze, anotowane obrazy/capture i manifest wiążący noteId z snapshotem. Dla HTML dochodzą DOMTarget oraz odwołanie do dokładnego źródła/bundla. Tekst po edycji ElevenLabs jest treścią uwagi; dołączanie audio jest opcjonalne. Oryginały zostają lokalnie.

Przebieg: plan załączników → przygotowanie uploadów → upload bajtów → jedna wiadomość w wątku → zapis potwierdzenia i identyfikatorów. Send to Agent może rozpocząć lub zakolejkować pracę.

Zbadany lokalny build T3 z 2026-11-01 obsługiwał 1–8 załączników, 120 000 znaków tekstu, 10 MiB/obraz i 50 MiB/plik. To datowany dowód, nie gwarancja wszystkich wydań. Wiążą nas możliwości zweryfikowanego docelowego hosta; nie narzucamy na tej podstawie produktowego limitu sześciu ekranów.

Przekroczenie limitów wymaga świadomego ograniczenia zakresu lub obsługiwanego bundla; nie dzielimy paczki samoczynnie na kilka wiadomości. Dokładny format zbiorczego bundla HTML/obrazów/audio jest otwarty i wymaga testu odbiorcy.

Sent oznacza ACK serwera, nie koniec pracy agenta. Status pracy jest oddzielny. Przy timeout po rozpoczęciu wysyłki pokazujemy Delivery Unknown i uzgadniamy batchId z wątkiem przed ponowieniem; lokalny identyfikator nie dowodzi idempotencji serwera.

Offline zachowujemy paczkę lokalnie. Powrót połączenia pokazuje Ready to Send i wymaga jawnego działania, bez wysyłki/uruchamiania agenta po restarcie. Draft MVP jest lokalny; nie synchronizuje się z desktopowym stashem T3 bez dodatkowego wspieranego API.

Pull pobiera nowe wersje, screenshoty/HTML, opis zmian i statusy. Import weryfikuje manifest, hash i powiązanie wątku. Zwracane warianty pojawiają się obok Now i wcześniejszych wersji.

## 9. Skill i pętla prototypowania

Brief/paczka → kilka klikalnych wariantów UI/funkcji na danych przykładowych → eksport HTML i screenshotów z manifestem → pull na iPad → review → kolejna iteracja lub polecenie wdrożenia.

Skill nadaje proposalId, iteration i parentSnapshotId, dodaje stabilne data-review-id do HTML i opisuje zmiany/adresowane noteId. Nie zastępuje starego źródła nowymi bajtami pod tym samym snapshotId. Działanie z fixture data nie jest dowodem funkcji produkcyjnej.

Źródło skilla: [.agents/skills/ui-review-variants](../.agents/skills/ui-review-variants/SKILL.md). Manifest i transport to kontrakt aplikacji, nie automatyczna funkcja istniejącego T3.

## 10. Model i trwałość

| Obiekt | Odpowiedzialność |
|---|---|
| Project / ReviewCanvas / T3Thread | Hierarchia projektu, jedno powiązanie wątku, własna kamera, uwagi i paczki. |
| Screen / Snapshot / ViewVersion | Logiczny widok i jego niezmienne źródła, capture, hashe, viewport oraz stan. |
| Proposal / ProposalIteration / BaselineRevision | Alternatywy, iteracje i historia Now. |
| Annotation / DOMTarget | Znormalizowana geometria lub wersjonowany cel komponentu. |
| Comment / Recording / Transcript | Stabilny numer/id, audio, surowy wynik i tekst po edycji; niezależny stan gotowości. |
| ReviewBatch / SavedDraft | Zakres wybranych rewizji, wątek, kolejność i zamrożony payload. |
| OutboxEntry / DeliveryReceipt | Stan uploadu/dostarczenia, batchId, ACK, błędy i historia ponowień. |

Przesunięcie/zoom nie zmienia kotwicy; numery uwag nie zależą od indeksu tablicy. Undo przywraca tożsamość i dane właściwej operacji. Usunięcie, wznowienie draftu i spóźniona transkrypcja nie mogą usuwać lub nadpisywać innej uwagi.

Natywny magazyn musi odzyskać komplet obrazów/HTML/audio i metadanych po restarcie, bez uruchamiania agenta. Wybór silnika trwałości jest otwartą decyzją implementacyjną. Nie utrwalamy sekretów w HTML, manifeście, eksporcie ani logach.

## 11. Etapy i kryteria akceptacji

Etap 1: specyfikacja i prototyp kluczowych interakcji. Etap 2: spike T3/OAuth/Tailscale, native capture/Pencil/HTML runtime i ElevenLabs na izolowanych danych testowych. Etap 3: natywny MVP i pełna pętla z fizycznego iPada.

| ID | Sprawdzalny wynik |
|---|---|
| AC-01 | Dwa canvasy mają własne wątki, kamerę, uwagi i drafty; żadna paczka nie miesza ich danych. |
| AC-02 | Now i co najmniej dwie propozycje są obok siebie; iteracja A nie zmienia B ani Now. |
| AC-03 | Region obrazu i DOMTarget pozostają przy oryginale po zoomie, pull i zmianie wersji. |
| AC-04 | Lekki/mocny nacisk zmienia głębokość; release zachowuje cel; warstwa spod nakładki ma oddzielny wybór. Alternatywa bez nacisku daje ten sam cel. |
| AC-05 | Nowe zaznaczenie przy ON startuje głos, przy OFF nie; stare uwagi, hover i restart nie startują nagrania. |
| AC-06 | Po Stop i transkrypcji uwaga zapisuje się bez Save Comment; poprawki tekstu są automatycznie zapisywane. |
| AC-07 | Z trzech snapshotów tylko dwa z gotowymi komentarzami trafiają do podglądu. Dwie uwagi na jednym snapshotcie dają jeden obraz z dwoma oznaczeniami. |
| AC-08 | Pusty region i transkrypcja w toku zostają w szkicu, nie blokując gotowych uwag. Brak źródła jest opisany przy konkretnej uwadze. |
| AC-09 | Po zebraniu gotowych uwag dwa tapnięcia wystarczają do Send to Agent lub Save Draft; bez dodatkowych ekranów potwierdzania. |
| AC-10 | Save Draft nie wykonuje send/queue i nie uruchamia agenta; wznowienie nie nadpisuje nowszych danych. |
| AC-11 | Wiele wybranych uwag tworzy jedną wiadomość do pokazanego wątku; Sent pojawia się po ACK, status wykonania osobno. |
| AC-12 | Timeout daje Delivery Unknown; powrót sieci/restart nie powoduje ślepej powtórki. |
| AC-13 | Audio i surowy wynik ElevenLabs zostają przy pierwotnym nagraniu po zmianie canvasu; wpisany tekst nie zostaje nadpisany. |
| AC-14 | Odmowa mikrofonu/błąd/offline pozwala komentować tekstowo; zapisane zasoby przetrwają restart. |
| AC-15 | Skill zwraca identyfikowalne klikalne warianty i manifest, które można pobrać, porównać i ponownie skomentować. |

Metryki walidacji: ukończenie pętli, czas do pierwszej gotowej paczki, liczba dodatkowych tapnięć, pomyłki celu/wersji/wątku, odzyskanie po przerwaniu i przypadkowe powtórki. Nie ma celu konwersji.

## 12. Stan kodu i dowodów

Snapshot implementacji: lokalny commit 08bd0da. Niniejszy PRD dokumentuje też nowszy zaakceptowany flow; nie oznacza jego wdrożenia.

| Obszar | Stan |
|---|---|
| Canvas, warianty, obraz + statyczny HTML, DOM/layers i pressure preview | HTML prototyp v3; część stanów sprawdzona programatycznie w podglądzie. Brak dowodu fizycznego Pencila. |
| Głos, push/pull i potwierdzenie wysyłki | Symulacje; brak mikrofonu, natywnego klienta i połączenia T3. |
| ElevenLabs | Adapter hosta Node i 13/13 grup mock; bez live API, sekretu, capture lub wdrożonego hosta. |
| Najnowszy flow Feedback (N) i autosave | Do wdrożenia: prototyp nadal ma Save Comment, Notes/Review Batch i wcześniejsze zasady kwalifikacji pustych uwag. |
| Trwałość | Prototypowe metadane w localStorage; importowane bajty session-only. Natywna trwałość wymagana. |
| Klikalne HTML/JS, squeeze, dostępność urządzeniowa | Do wdrożenia i weryfikacji na iPadzie. |

Pełne dowody: [VALIDATION.md](VALIDATION.md). Raporty krytyk Sol, Grok 4.7 i Opus 5.5 dotyczą wcześniejszych kandydatów; nie są certyfikacją obecnego ani docelowego MVP.

## 13. Otwarte kwestie implementacyjne

- Minimalny iPadOS, urządzenia testowe i kalibracja nacisku/odrzucania dłoni.
- Izolowany scripted HTML runtime, zapis stanu i capture do rzeczywistej paczki.
- Silnik trwałości, backup/retencja lokalnych zasobów i pełna historia Undo/Redo.
- Docelowy host/port, pairing i redirect OAuth na iPadzie; kontrakt uploadów i potwierdzeń na wdrożonym T3.
- Format większego bundla HTML/obrazów/audio i sposób jego odczytu przez agenta w limicie załączników.
- Host transkrypcji, autoryzacja i magazyn sekretów; jakość PL/EN/mowy mieszanej, retencja i koszty konta ElevenLabs.
- Synchronizacja draftu na desktop: poza MVP, wymaga wspieranego API.

Szczegóły techniczne: [T3-INTEGRATION.md](T3-INTEGRATION.md), [ELEVENLABS.md](ELEVENLABS.md), [HTML-REVIEW.md](HTML-REVIEW.md). Te notatki zachowują datowane obserwacje; bieżące wymagania produktu rozstrzyga PRD i powiązane ADR-y.
