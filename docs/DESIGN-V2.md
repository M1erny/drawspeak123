# Canvas v2 — kierunek

Aktualizacja wymagań: canvas zajmuje całe okno jak przestrzeń robocza Freeform. `Now`, `Proposal A` i `Proposal B` są widoczne równocześnie obok siebie. Palety i inspektory unoszą się nad przestrzenią. Każdy canvas ma jeden osobny wątek, własne uwagi, stash i pozycję kamery.

Automatyczny komentarz głosowy zaczyna się po zakończeniu nowego zaznaczenia. To domyślna opcja wskazana przez użytkownika; ustawienie `Auto-start voice after selection` wyłącza ją dla nowych zaznaczeń. Pierwsza rzeczywista próba w natywnej aplikacji wymaga systemowej zgody na mikrofon. Brak zgody daje natychmiast komentarz tekstowy, bez pętli próśb. Auto-start nie wznawia się po restarcie, zmianie wątku ani otwarciu starej uwagi. Zakończenie aktywnego nagrania pozostaje pod kontrolą użytkownika, zaś wyjście z canvasu kończy je i zapisuje dostępną część do pierwotnej uwagi.

## Tokens i struktura

- Surface: light `#ffffff`, dark `#24272b`; canvas light `#f5f6f8`, dark `#181b1f`; ink light `#20252d`, dark `#f2f3f5`; secondary ink light `#556171`, dark `#b9c2cf`; action light `#1758bd`, dark `#95baff`; annotation light `#bd3048`, dark `#ff8598`. W HTML oprawa używa zmiennych motywu; obraz screenshotu zachowuje oryginalne kolory.
- Systemowy font: tytuły canvasu 17 px, kontrolki i tekst 15–17 px, metadane 13 px. Rozmiar screenshotów wynika z kamery; etykiety i kontrolki są poza skalowaną treścią, jeśli jest to możliwe.
- Regular: lewa górna paleta canvas/wątek, prawa akcje, trzy widoki w jednej linii, dolna paleta rysowania i osobny zoom. Compact: krótsze etykiety, te same akcje, zoom/pan do treści; propozycje pozostają obok siebie w świecie canvasu.
- Signature: czerwony obrys i przypięta wypowiedź na niezmiennym screenshotcie. Bez powtarzanego logo, kart metryk czy dekoracyjnych sekcji.
- Motion: bez animacji wejścia; tylko bezpośrednia odpowiedź na zmianę kamery i narzędzia. Reduced transparency daje nieprzezroczyste palety.

```text
[Canvases / title / thread]           [Import] [Notes] [Settings]

       Now             Proposal A          Proposal B
     [image]             [image]             [image]
       ink                 ink                 ink

[− / zoom / + / Fit]     [Hand / Region / Arrow / Pen / Undo]
```

Przegląd planu: oprawa została zredukowana względem v1. Cała hierarchia wynika z pracy na obrazach i porównywania propozycji. Domyślny panel uwag usunięto, aby gest zaznaczenia i głos mogły być podstawowym przepływem.

Inspiracja: [Apple — Get started with Freeform on iPad](https://support.apple.com/guide/ipad/get-started-with-freeform-ipad9c59637d/27/ipados/27). To podobieństwo modelu pracy i układu; HTML nie jest natywnym Freeform ani deklaracją pełnej zgodności z HIG.

Źródła decyzji: `layout.md › Visual hierarchy` — „Differentiate controls from content”; `toolbars.md › Best practices` — „Choose items deliberately to avoid overcrowding”; `settings.md › Task-specific options` — „prefer letting people modify task-specific options without going to your settings area”. Odniesienia do lokalnych plików skilla apple-design, przeczytanych w tym przeglądzie. Zasady UX: **Progressive Disclosure**, **Juxtaposition**, **Mental Model**, **Feedback Loop**. Szczegóły krytyk i poprawki w `docs/reviews/`.
