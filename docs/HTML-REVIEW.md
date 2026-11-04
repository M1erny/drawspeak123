# Obrazy, HTML i wybór komponentu

Aktualny zakres i UX określa [PRD](PRD.md) oraz [ADR-0003](adr/0003-html-component-selection.md). Ten dokument zachowuje szczegóły techniczne i datowane granice dowodów; nie oznacza wdrożenia wszystkich wymagań.

Ten sam canvas przyjmuje obrazy i wersjonowane makiety HTML. Obraz ma anotacje geometryczne. HTML oprócz geometrii ma wskazanie konkretnego elementu DOM i jego wersji.

## Wybór

- Lekki nacisk wskazuje najwyżej położony element pod końcówką. Większy nacisk przechodzi po jego rodzicach do korzenia makiety. Podgląd pokazuje obrys, nazwę i głębokość.
- Rodzic w DOM i inny element za nakładką to różne cele. Osobny wybór Layers pokazuje kandydatów z tego samego punktu, z pominięciem ich powtarzających się rodziców.
- Po podniesieniu Pencila zapisujemy ostatnią stabilną głębokość, bez powrotu na wierzch przy spadku siły do zera. Dopiero zatwierdzony wybór uruchamia auto-głos przy ustawieniu ON.
- Mysz/klawiatura: Select HTML Component lub Notes → Select HTML Component, przyciski hierarchii, symulator nacisku, wybór widoku/komponentu, Select and Comment. Zmiana samego suwaka nie tworzy kolejnych uwag.
- Histereza ogranicza przeskakiwanie między poziomami przy wahaniach. Prototyp używa pasma 0,04 znormalizowanej siły. Ruch końcówki ponad 24 ekranowe CSS px lub pinch anuluje wybór. To parametry do kalibracji, nie pomiar natywnego Pencila.

To eksperyment projektowy. HIG wymaga intuicyjnej reakcji na nacisk i bezpośredniego feedbacku; nie narzuca mapowania na DOM. Widoczna nazwa/obrys i jawne alternatywy należą do kontraktu (**Feedback Loop**, **Recognition Over Recall**, **Fitts's Law**).

## Kontrakt uwagi

Note zachowuje canvasId, snapshotId i znormalizowaną geometrię. Dla HTML dodaje domTarget:

```json
{
  "artifactKind": "html",
  "snapshotId": "checkout:html-a2",
  "sourceHash": "<SHA-256 źródłowych bajtów>",
  "renderHash": "<SHA-256 dokumentu po polityce renderowania>",
  "renderPolicy": "static-no-script",
  "viewport": {"width": 330, "height": 480},
  "locator": {"strategy": "data-review-id", "value": "pay-action"},
  "label": "Pay Button",
  "tagName": "button",
  "ancestry": [{"label": "Button Label", "locator": {}}, {"label": "Pay Button", "locator": {}}],
  "selectedDepth": 1,
  "layer": 0,
  "selectionMethod": "pencil-pressure",
  "pressure": 0.5,
  "bounds": [{"x": 0.07, "y": 0.75}, {"x": 0.93, "y": 0.75}]
}
```

Przykład skrócony: bounds to zamknięta ścieżka, a ancestry to pełny łańcuch od trafionego elementu do korzenia, z locatorami; selectedDepth wskazuje jego wybraną pozycję. Hashy w prototypie nie zastępujemy tekstem przykładu — są wyliczane.

Locator: najpierw unikalne data-review-id, potem id, ostatecznie CSS nth-of-type w tym dokumencie. Nie jest to tożsamość między wersjami. Nowe źródło, stan lub viewport wymaga nowego snapshotu; brak dokumentu nie może przepinać komentarza do podobnego elementu. Docelowa paczka zawiera też obraz stanu z obrysem i referencję do HTML/bundla.

## Prototyp

Now to obraz; A/B to rzeczywisty HTML w iframe. Są niezależne iteracje, import obrazów i samodzielnego HTML, inspekcja aktualnego DOM, rodzice, warstwy, pressure preview, locator/hashes w paczce i auto-start symulowanego głosu po zatwierdzeniu. Piny i kontrolki nie skalują się z treścią.

Widoki i podglądy mają wspólny viewport 330×480. Obramowanie jest wizualne, nie zabiera pikseli iframe. Inspekcja czeka na gotowość ramki i hashe; zmiana na niegotowy widok czyści poprzedni wybór i blokuje potwierdzenie.

Import HTML jest statyczny: skrypty, nawigacja i zewnętrzne zasoby są usuwane/blokowane; brak allow-scripts, CSP odmawia sieci. HTML/CSS i rastrowe obrazy data URI pozostają. To nie pełny runtime React ani potwierdzona produkcyjna granica bezpieczeństwa. Limit aplikacji: 2 MiB, viewport 330×480. Bajty importów są session-only; po reloadzie brakuje źródła i taka paczka nie przechodzi symulacji wysyłki.

## Natywny MVP

SwiftUI canvas + izolowany WKWebView na wersję, kontrolowana sonda DOM, oddzielny kanał komunikatów i brak dostępu makiety do sekretów/poleceń T3. Pełne klikalne HTML/JS wymaga izolowanego loadera bundli, polityki zasobów/nawigacji i wersjonowanego stanu. Prototyp statyczny tego nie dowodzi.

Siła docelowo: UITouch.force / maximumPossibleForce z kontrolą możliwości sprzętu i estymowanych próbek. Nie traktować domyślnego nacisku myszy jako pomiaru Pencil. Po zatwierdzeniu nie zmieniać celu retroaktywnie przez aktualizację estymacji. Progi, odrzucanie dłoni i obsługa lewo-/praworęcznych wymagają iPada.

Po zatwierdzeniu anotacji głos zachowuje canvasId/noteId/recordingId. Po Stop audio transkrybuje ElevenLabs — [adapter i granice dowodów](ELEVENLABS.md). HTML nie dostaje klucza dostawcy.

Źródła: [Apple force](https://developer.apple.com/documentation/uikit/uitouch/force), [maximumPossibleForce](https://developer.apple.com/documentation/uikit/uitouch/maximumpossibleforce), [Pointer Events](https://www.w3.org/TR/pointerevents3/). Lokalny apple-design: apple-pencil-and-scribble.md, Best practices i Hover, przeczytane w tej zmianie. Mapping DOM jest decyzją projektu.
