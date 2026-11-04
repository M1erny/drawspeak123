# UI Review — specyfikacja produktu

## 0. Kontekst i granice dowodów

Produkt docelowy to natywna aplikacja SwiftUI na iPad, dla jednej osoby, do przeglądania UI i przekazywania agentowi precyzyjnych uwag. Użytkownik pracuje nad projektem w T3 Code, otwiera jego screenshoty na canvasie, oznacza problemy Pencil lub palcem i zbiera je w jedną wiadomość. Zakładany kontekst to skupiona praca przerywana przełączaniem między kodem i porównywaniem wariantów; aplikacja ma ograniczać pamiętanie kontekstu (**Cognitive Load**, **Recognition Over Recall**).

Pierwszy kamień milowy obejmuje tę specyfikację oraz interaktywny prototyp HTML na danych fixture. Natywna aplikacja powstaje później. Zachowanie przycisków w prototypie nie stanowi dowodu integracji z T3 Code, Tailscale, mikrofonem, rozpoznawaniem mowy ani Apple Pencil. Każda symulacja połączenia, transkrypcji, wysyłki lub odpowiedzi musi mieć oznaczenie `Demo / fixture` (**Expectations Bias**, **Feedback Loop**).

Sukces użytkownika: „Przekazałem jeden spójny zestaw uwag i porównałem propozycje bez utraty punktu odniesienia”. Sukces produktu mierzymy poprawnością przypięcia uwag, czasem do pierwszej kompletnej paczki i skutecznością odzyskania szkicu. Nie ma celu konwersyjnego ani mechanizmów wymuszających powrót.

## 1. Docelowe doświadczenie

- **Peak:** kilka zaznaczeń na różnych obrazach pojawia się w jednej czytelnej paczce ze wspólnym kontekstem (**Chunking**, **Peak-End Rule**).
- **Ending:** `Saved locally` albo potwierdzony `Sent` z odbiorcą i następnym krokiem; użytkownik może zakończyć pracę przez `Back to canvas` (**Feedback Loop**, **Provide Exit Points**).
- **Negatywne momenty:** utrata nagrania, błędny screenshot, niepewna wysyłka i przypadkowa zmiana baseline. Ochrona danych i jawne stany mają pierwszeństwo przed animacjami (**Negativity Bias**).
- Podstawowy przebieg ma trzy kroki: `Annotate → Review batch → Choose action`. W panelu paczki pokazujemy rzeczywisty postęp `1 of 3`, bez fikcyjnego postępu (**Feedback Loop**).

## 2. Architektura informacji

Hierarchia: `Project → ReviewCanvas → T3Thread`. Projekt zawiera wiele canvasów, każdy związany z dokładnie jednym wątkiem T3 Code. Powiązanie jest widoczne w nagłówku; utworzenie kolejnego canvasu jest domyślną drogą do pracy z innym wątkiem (**Mental Model**, **Recognition Over Recall**).

Canvas zajmuje całe okno na wzór Freeform. `Now`, `Proposal A` i `Proposal B` są obok siebie w tej samej przestrzeni, a iteracje wybiera się osobno dla każdej propozycji. Pływające palety zawierają nawigację canvas/wątek, narzędzia i licznik uwag. Uwagi, ustawienia i szczegóły otwierają się jako czasowe panele nad canvasem; brak stałego sidebaru. Historia wersji i ustawienia połączenia są o jeden krok dalej (**Progressive Disclosure**, **Method of Loci**).

Priorytety zadań: 1) oznaczyć UI, 2) zebrać i przejrzeć uwagi, 3) wysłać lub odłożyć paczkę, 4) pobrać i porównać wynik. W danym kontekście tylko jedna akcja ma najsilniejszą wagę wizualną (**Pareto Principle**, **Hick's Law**).

## 3. Model obiektów

| Obiekt | Wymagany kontrakt |
|---|---|
| `Project` | `id`, nazwa, kolekcja canvasów; pojedynczy lokalny właściciel. |
| `ReviewCanvas` | `id`, `projectId`, jedno `threadId`, położenia elementów, zoom/pan, bieżący baseline. Brak mieszania wątków w jednej paczce. |
| `T3Thread` | Tożsamość z adaptera T3, etykieta i stan synchronizacji; transport i uprawnienia wymagają weryfikacji. |
| `Snapshot` | Niezmienny `id`, zasób obrazu, hash, wymiary, źródło `manual` lub `T3`, czas importu; commit/build ID tylko gdy rzeczywiście dostępny. |
| `ViewVersion` | Logiczny widok UI, `snapshotId`, wersja, lineage, informacja o viewport; nie nadpisuje obrazu poprzedniej wersji. |
| `Annotation` | `id`, `snapshotId`, typ `region / arrow / freehand`, geometria znormalizowana, opcjonalny `commentId`. |
| `Comment` | Edytowalny tekst, oryginalna transkrypcja, język `pl / en`, opcjonalny `audioAssetId`, stan zapisu. |
| `ReviewBatch` | `id`, canvas/wątek, uporządkowane elementy `snapshot + annotations + comments`, ogólny brief i jawny tryb dostarczenia. |
| `Proposal` | Niezależna linia wariantu wyprowadzona z konkretnego baseline; zawiera iteracje. |
| `ProposalIteration` | Numer, snapshoty, podsumowanie zmian, status i źródłowe identyfikatory odpowiedzi, jeśli dostępne. |
| `BaselineRevision` | Jawnie zatwierdzony zestaw wersji widoków pokazywany jako `Now`, z historią poprzednich rewizji. |
| `OutboxEntry` | Zamrożony payload, `batchId`, lokalny identyfikator operacji, stan dostarczenia, potwierdzenie zdalne jeśli istnieje. |

Geometria zapisuje współrzędne względem oryginalnego obrazu: `x / imageWidth`, `y / imageHeight`; rozmiary i punkty ścieżek analogicznie. Transformacje canvasu nie zmieniają danych anotacji. Region ma prostokąt obejmujący obrys oraz zachowaną ścieżkę zaznaczenia. Oryginalne uwagi zawsze wskazują pierwotny `Snapshot`; nowy screenshot wymaga nowej anotacji, nawet jeśli wizualnie jest podobny. Nie wykonujemy cichego remapowania (**Mental Model**, **Feedback Loop**).

## 4. Główny przebieg

`Open canvas → Import / Pull → Annotate → Review batch → Save draft / Stash / Send to agent → Pull result → Compare → Promote to Now`

| Krok | Wejście i wartość | Wyjście / powrót | Zasada |
|---|---|---|---|
| Import / Pull | Ręczny import obrazu albo pobranie przez zweryfikowany adapter; miniatura i źródło przed dalszą pracą. | `Cancel`, dotychczasowy canvas zachowany. | **Feedback Loop** |
| Annotate | Zaznaczenie regionu, komentarz tekstowy lub głosowy, natychmiastowy znacznik na właściwym obrazie. | `Undo`, automatyczny lokalny szkic. | **Recognition Over Recall** |
| Review batch | Obrazy, oznaczenia i komentarze w jednej kolejności; odbiorca i konsekwencja wybranej akcji. | Edycja, `Save draft`, `Stash`; bez automatycznej wysyłki. | **Chunking**, **Feedforward** |
| Deliver | Jawne `Send to agent` tworzy jedną wiadomość z całą paczką, nie osobną wiadomość dla każdej uwagi. | Status outbox oraz powrót do canvasu. | **Feedback Loop** |
| Compare | `Now` i wybrana iteracja obok siebie; opis i status zmian. | `Keep reviewing` lub jawne `Promote to Now`. | **Juxtaposition** |

## 5. Ekrany i stany

| Ekran | Hierarchia i główna akcja | Stany oraz odzyskanie |
|---|---|---|
| `Projects` | Tytuł, ostatnie projekty, `Open project`; przy braku danych `Create project`. | Empty: pierwszy projekt; loading: skeleton; error: `Could not open project` + ponowienie; success: otwarty canvas. |
| `Canvas` | Nazwa i wątek, `Now`/propozycje, obrazy, narzędzia, `Review batch (N)`; na pustym canvasie główne `Import screenshot`. | Empty: instrukcja importu; loading/pull: postęp; partial: zachowane dotychczasowe obrazy; error: `Pull failed — local work is saved`; success: licznik nowych wersji. |
| `Comment` | Miniatura regionu, tekst/nagranie, `Save comment`, wtórne `Cancel`. | Empty: placeholder; recording: czas + stop; transcribing: postęp; error: zachowane audio i możliwość wpisania tekstu; success: komentarz w paczce. |
| `Review batch` | Wątek i liczba obrazów/uwag, podgląd treści, wybór trybu, jedna główna akcja odpowiadająca trybowi. | Empty: powrót do oznaczania; partial: brak załącznika blokuje wysyłkę; error: szczegół przy elemencie; success: `Saved locally` lub potwierdzenie dostarczenia. |
| `Compare` | `Now` po lewej, propozycja i iteracja po prawej, podsumowanie zmian, główne `Promote to Now`. | Empty: brak propozycji; loading: jawny postęp; partial: brakujący widok oznaczony; error: poprzedni baseline zachowany; success: numer nowej rewizji `Now`. |
| `Connection` | Wybrany host i stan, diagnostyka, `Connect`; po połączeniu `Refresh status`. | Offline, connecting, connected, stale, unauthorized, error; instrukcja naprawy bez usuwania lokalnej pracy. |

Elementy mają etykiety i komunikaty obok obiektu, którego dotyczą; stany nie opierają się tylko na kolorze (**Law of Proximity**, **Signifiers**). Feedback wizualny docelowo w 100 ms; oczekiwanie powyżej 1 s ma wskaźnik, powyżej 4 s prawdziwy opis czynności, bez udawanych procentów (**Feedback Loop**, **Chronoception**). Cele dotykowe minimum 44×44 pt, kontrast AA, VoiceOver i reduced motion (**Fitts's Law**, **Contrast**).

## 6. Canvas, Pencil i głos

Canvas jest nieskończoną przestrzenią z pan/zoom i obrazami jako kartami; MVP nie obejmuje edytora layoutu aplikacji. Domyślnie palec przesuwa canvas, Pencil rysuje. Jawny tryb `Draw with finger` udostępnia te same narzędzia; gest nawigacji nie może przypadkowo tworzyć uwagi (**Mental Model**, **Signifiers**).

Paleta zawiera `Region`, `Arrow`, `Freehand`, `Select`, `Undo`. Pencil Pro squeeze otwiera ją przy narzędziu, a widoczny przycisk daje tę samą drogę na innych urządzeniach. Zamknięty obrys regionu tworzy kotwicę komentarza i otwiera panel `Add comment`; strzałka i freehand mogą istnieć bez komentarza. `Undo` dotyczy lokalnych zmian, a nie odwołania wysłanej wiadomości (**Fitts's Law**, **Feedforward**).

Sekwencja głosowa: `Select region → Auto-start recording → Stop → Review transcript → Save comment`. Po wyłączeniu auto-startu dostępne są tekst i ręczny `Record comment`. Użytkownik wybiera PL/EN, poprawia tekst i może odsłuchać audio. Zapis obejmuje audio oraz zatwierdzony tekst; transkrypcja źródłowa jest zachowana osobno. Domyślnie nagrywamy automatycznie po zakończeniu nowego zaznaczenia; ustawienie `Auto-start voice after selection` wyłącza auto-start. To jawne wymaganie użytkownika, zastępujące wcześniejszy ręczny start (**Default Bias**, **Feedforward**).

Zgoda na mikrofon i ewentualne rozpoznawanie mowy jest proszona w kontekście pierwszego nowego zaznaczenia uruchamiającego głos albo ręcznego `Record comment`, z wyjaśnieniem zastosowania. Odmowa daje edycję tekstową i link do ustawień, bez ponawiania próśb w pętli. Błąd transkrypcji zachowuje już zapisane audio; przerwanie nagrania zapisuje dostępną część z jawnym statusem. Brak miejsca blokuje nowe nagranie z czytelną naprawą. Wymagany lokalny zapis audio przed rozpoczęciem transkrypcji (**Reactance**, **Negativity Bias**).

## 7. Cykl paczki i bezpieczne dostarczanie

`Editing → Ready → Stashed` to wyłącznie lokalne stany, bez uruchomienia agenta. `Save draft` zapisuje bieżącą edycję; `Stash` odkłada nazwaną paczkę do wznowienia. Zmiana zapisanej paczki tworzy lokalną rewizję. Inspekcja zainstalowanego T3 Nightly wykazała desktopowy stash w browser localStorage, maksymalnie 20 wpisów, bez zaobserwowanego server draft sync. MVP przechowuje własny stash na iPadzie i nie obiecuje synchronizacji ze stashem desktopowym (**Expectations Bias**).

Tylko jawne `Send to agent` tworzy `OutboxEntry`: `Queued → Sending → Acknowledged`; możliwe `Failed` i `Delivery unknown`. Kliknięcie pokazuje wątek, zakres i informację `Sending this batch may start agent work`. W zbadanym T3 `send_attachments` uruchamia, kieruje lub kolejkuje pracę agenta: zapis bez wykonania pozostaje lokalny (**Feedforward**).

Paczka jest jedną logiczną wiadomością. Zbadany kontrakt T3: 1–8 załączników, tekst maksymalnie 120 tys. znaków, obraz maksymalnie 10 MiB, plik maksymalnie 50 MiB; przygotowanie podpisanego uploadu → upload bajtów → jedno `send_attachments`. Domyślny plan: do 6 kompozytów anotowanych screenshotów + manifest + archiwum audio, jeśli dopuszczalne dla danego typu pliku. Kilka uwag na jednym obrazie jest numerowanych i łączonych w jeden kompozyt; manifest wiąże numery z tekstem, geometrią, hashami i oryginałami. Oryginalne obrazy, audio i anotacje pozostają lokalnie. UI pokazuje faktyczny plan załączników i weryfikuje wszystkie limity przed wysyłką. Przekroczenie wymaga świadomej redukcji zakresu lub rozmiaru; aplikacja nie dzieli paczki po cichu na wiadomości. Obsługa archiwum audio wymaga potwierdzenia; jej brak jest jawną blokadą tej opcji (**Chunking**, **Feedforward**).

Domyślnie offline zapisuje paczkę lokalnie. Po jawnej próbie wysyłki offline element czeka jako `Queued`; powrót połączenia pokazuje `Ready to send`, a użytkownik uruchamia wysyłkę, bez niespodziewanego wykonania po restarcie. Timeout po rozpoczęciu wysyłki daje `Delivery unknown`, nie automatyczne ponowienie. Zbadany kontrakt nie ma klucza retry; lokalny operation ID sam nie zapewnia idempotencji. Najpierw sprawdzamy odczyt wątku i dostępne identyfikatory wiadomości. Jeśli nie rozstrzygają wyniku, użytkownik dostaje informację o ryzyku duplikatu przed świadomym ponowieniem (**Feedback Loop**, **Negativity Bias**).

`Acknowledged` oznacza przyjęcie wiadomości, nie zakończenie pracy agenta. Status wykonania jest oddzielny: `Unknown / Queued / Running / Completed / Failed`, wyłącznie na podstawie dostępnych dowodów. Potwierdzenie wysyłki nie obiecuje możliwości cofnięcia wykonania; `Cancel` jest dostępne tylko przed wysłaniem albo przy potwierdzonej obsłudze zdalnej (**Expectations Bias**).

## 8. Wersje, propozycje i baseline

`Now` pozostaje stabilnym zestawem screenshotów. `Pull` dodaje wersje i odpowiedzi, nie zastępuje baseline. `Proposal A` i `Proposal B` mają niezależne iteracje i jawny punkt startowy. Dwa warianty o wspólnym przodku nie stają się wzajemnymi iteracjami (**Mental Model**).

Porównanie pokazuje `Now` obok wybranej propozycji, wspólny widok/viewport, numery wersji i czas pobrania. Opcjonalnie można porównać dwie propozycje; brak zgodnego widoku jest opisany, bez sztucznego dopasowania. `Promote to Now` pokazuje dokładny zestaw przyjmowanych widoków i tworzy `BaselineRevision`. Historia umożliwia powrót do wcześniejszej rewizji; stare anotacje nadal otwierają swój oryginalny obraz (**Juxtaposition**, **Recognition Over Recall**).

Przepływ skillu dla agenta: brief/paczka → kilka klikalnych prototypów na fixture data → screenshoty i krótkie różnice → wybór wariantu → dopiero implementacja. `Choose variant` jest odrębną intencją od `Promote to Now`; wybór kierunku nie potwierdza wdrożenia. Sposób przekazania skillu do T3 wymaga uzgodnienia, nie zakładamy istniejącego polecenia ani endpointu (**Feedforward**).

## 9. Połączenie i przechowywanie

Docelowo wymagana jest natywna integracja Tailscale. Inspekcja zainstalowanego T3 `0.1.7-nightly.20261101.4016` potwierdziła w bundle serwera `/mcp` przez HTTP z OAuth PKCE i bearer oraz opcję CLI `--tailscale-serve` dla HTTPS, domyślnie port 443. To dowód możliwości kodu tej wersji, nie działającego hosta. Dokładny wariant integracji iPad, uprawnienia, zgodność dystrybucji, auth redirect i dostęp do wdrożonego T3 przez tailnet wymagają spike i próby urządzeniowej. Obecność hosta w tailnet nie oznacza autoryzacji do T3.

Pobieranie screenshotów wykorzystuje manifest należący do aplikacji, który wiąże widok, propozycję, iterację i wersję obrazu. Rewizja zasobu T3 nie jest hashem treści; adapter wylicza i przechowuje osobny hash otrzymanych bajtów. Nie zakładamy, że sam wątek dostarcza komplet semantyki wersjonowania (**Mental Model**).

UI odróżnia lokalny zapis, stan tailnet, dostępność usługi i świeżość danych. `Stale — last pulled …` zachowuje czas ostatniego sukcesu; `Pull` pozostaje jawne. Restart aplikacji przywraca lokalne paczki i nie uruchamia agenta. Docelowy zapis lokalny jest trwały, zasoby audio/obrazu mają własną tożsamość, a sekretów nie umieszczamy w komentarzach/logach. Polityka ochrony plików i Keychain wymaga weryfikacji natywnej.

## 10. Etapy i kryteria akceptacji

**M1 — specyfikacja i HTML (v1):** interaktywny canvas, fixture screenshoty, oznaczanie regionu/strzałki/freehand, edytowalne komentarze, podgląd jednej paczki, lokalny draft/stash, symulowana odpowiedź i porównanie. Swobodny pan/zoom, promotion baseline oraz zarządzanie wieloma projektami/canvasami pozostają w specyfikacji natywnego MVP; nie są zaimplementowane w demonstratorze M1. Nagranie/transkrypcja i squeeze mogą mieć opisany demonstrator; etykieta informuje o symulacji. Trwałość przeglądarkowego szkicu wymaga osobnego sprawdzenia i nie dowodzi natywnej trwałości.

**M2 — spike integracji:** walidacja odkrytego kontraktu T3 na uruchomionym hoście, manifestu screenshotów/statusów, uploadów i jednej wiadomości z załącznikami, potwierdzeń oraz uzgadniania niepewnej wysyłki. Decyzja oraz dowody dla natywnego Tailscale i speech PL/EN. Brak potwierdzonej funkcji pozostaje oznaczony jako niedostępny.

**M3 — natywny MVP:** SwiftUI, trwały canvas, Photos/Files import, Pencil/Pencil Pro, mikrofon i transkrypcja, adapter T3/Tailscale, outbox, wersjonowanie i porównanie. Testy urządzeniowe są wymagane; przeglądarka ani symulator nie potwierdzają działania squeeze, rękopisu, audio i sieci na iPadzie.

Kryteria akceptacji:

1. Dwie uwagi na różnych snapshotach trafiają do jednej paczki; powiększenie i przesunięcie canvasu nie zmienia ich kotwic. M1: fixture, M3: zapis/odczyt na urządzeniu.
2. `Save draft` i `Stash` nie wysyłają niczego ani nie uruchamiają agenta; M3 wymaga dowodu po stronie adaptera, nie samego komunikatu UI.
3. Nowa iteracja nie zmienia `Now`; jawna promocja pozostawia dostęp do starego baseline i jego anotacji.
4. Odmowa mikrofonu oraz błąd transkrypcji pozwalają dokończyć tekstowo; zapisane audio przetrwa przerwanie. Weryfikacja dopiero M3.
5. Timeout po wysyłce pokazuje `Delivery unknown`; odzyskanie połączenia nie powoduje ślepej powtórki ani automatycznej pracy agenta.
6. M1 ma jednoznaczne oznaczenia fixture; nie raportuje prawdziwej integracji na podstawie zasymulowanego sukcesu.

## 11. Otwarte decyzje i plan walidacji

Domyślne propozycje do spike: ręczny pull zamiast background sync; własny lokalny draft/stash iPada; jedna jawnie wybrana instancja T3 na canvas; audio przechowywane lokalnie i opcjonalnie wysyłane jako archiwum po potwierdzeniu obsługi. Dostawca rozpoznawania PL/EN, ewentualne przetwarzanie poza urządzeniem i retencja wymagają decyzji po sprawdzeniu jakości oraz prywatności. Nie blokuje to prototypu.

Hipoteza przed testem: użytkownik rozróżni zapis lokalny od wysyłki i wskaże snapshot każdej uwagi bez otwierania historii. Scenariusz neutralny: „Oznacz dwa problemy, odłóż uwagi, potem wyślij je i porównaj wynik”. Mierzymy ukończenie etapów, pomyłki w adresowaniu, czas do pierwszej paczki, odzyskanie po przerwaniu oraz subiektywną łatwość. Rejestrujemy również przerwane próby (**Observer-Expectancy Effect**, **Survivorship Bias**).

Zakładana krzywa emocji: import 0 → anotacja +1 → kompletna paczka +2 → niepewna wysyłka −2 → wyjaśniony stan i zachowany szkic 0 → porównanie +1. To hipoteza do obserwacji, nie wynik badań. Brak wymuszonego zakończenia i brak fikcyjnych sukcesów łagodzą najgorszy moment (**Peak-End Rule**, **Negativity Bias**).

Sprawdzenie etyczne: jawne domyślne `Save draft` pomaga zachować kontrolę; `Send to agent` pozostaje bezpośrednio dostępne. Spełnia transparency, symmetry, reversibility lokalnej edycji i alignment. Zdalne wykonanie może być nieodwracalne, więc jego skutki są widoczne przed akcją. Brak presji, manipulacyjnych liczników, nagabywania o zgody i ukrytego uruchamiania agenta. Nie projektujemy conversion moves; pierwszeństwo ma ukończenie zadania użytkownika.

## 12. Aktualizacja v2 — wymagania użytkownika

Cztery zmiany mają pierwszeństwo nad opisem v1: pełnoekranowa przestrzeń jak Freeform; propozycje obok siebie; automatyczny komentarz głosowy po zaznaczeniu z ustawieniem wyłączenia; osobne wątki na osobnych canvasach.

Prototyp v2 realizuje pan, zoom/Fit All, trzy widoki równocześnie, niezależne iteracje A/B, przełączanie fixture canvasów z izolacją uwag i stash, panel komentarza oraz automatyczny start jawnie symulowanego głosu. Palec domyślnie przesuwa canvas; ustawienie Draw with finger pozwala rysować. Region uruchamia głos; strzałka/freehand są dodatkowymi narzędziami i nie rozpoczynają go samoczynnie. Otwarcie istniejącej uwagi, restart i zmiana canvasu nie rozpoczynają nagrania.

Aktywne nagranie zawsze należy do canvasId/noteId, przy których się rozpoczęło. Zmiana canvasu lub ukrycie aplikacji kończy je, zapisując dostępną część do pierwotnej uwagi. Mikrofon, permission flow, transkrypcja i fizyczny Pencil Pro pozostają do implementacji natywnej. Nie wolno utożsamiać widocznego demo timera z działającym audio.

HTML ma własny magazyn localStorage v2; nie migruje prototypowych danych v1. Importy mają niezmienny snapshotId, lecz bajty są dostępne wyłącznie w bieżącej sesji; brakujące obrazy są oznaczone, a dodawanie nowych uwag na nich zablokowane. Natywne MVP ma trwały zapis całych zasobów. Jawna promocja baseline i adapter T3 nadal nie są zaimplementowane.
