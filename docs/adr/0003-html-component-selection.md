# ADR-0003 — Obrazy i wybór komponentu HTML

Status: Przyjęte jako model produktu. Data: 2026-11-04. Kalibracja nacisku i scripted runtime pozostają do walidacji.

## Kontekst

Sam zaznaczony obszar obrazu nie wskazuje jednoznacznie elementu HTML. Użytkownik chce wykorzystać siłę nacisku Pencila do wskazania elementu na wierzchu lub jego rodzica.

## Decyzja

- Canvas obsługuje obrazy i makiety HTML. Obrazy mają anotacje geometryczne; HTML dodatkowo wersjonowany DOMTarget.
- Lekki nacisk wybiera trafiony element. Mocniejszy przechodzi po jego rodzicach, z podglądem nazwy, obrysu i głębokości.
- Histereza stabilizuje wybór. Release zatwierdza ostatnią stabilną pozycję, bez resetu do elementu na wierzchu po spadku siły.
- Rodzic DOM i element spod nakładki są różnymi celami. Layers wybiera element w stosie w tym samym punkcie; nacisk wybiera rodziców wybranej warstwy.
- Mysz, klawiatura i dotyk mają jawny wybór komponentu/hierarchii. Hover i zmiana podglądu nie tworzą komentarza.
- DOMTarget zapisuje snapshotId, source/render hash, viewport, locator, łańcuch trafienie→korzeń, głębokość/warstwę i znormalizowany obrys.
- Locator preferuje unikalne data-review-id. Jest odniesieniem w obrębie wersji, nie tożsamością między iteracjami.
- Makieta HTML jest izolowana od sekretów, poleceń T3 i rzeczywistych mutacji usług. Pełne klikalne HTML/JS wymaga kontrolowanego runtime z fixture data.

## Konsekwencje

Nacisk musi być kalibrowany na fizycznym iPadzie; reguły CSS/Pointer Events w prototypie nie dowodzą obsługi Pencil Pro. Nie zmieniamy zatwierdzonego celu retroaktywnie przez spóźnione estymacje siły.

Wersja statyczna prototypu nie wykonuje skryptów ani zewnętrznych zasobów. Nie jest dowodem pełnego runtime React/JS ani produkcyjnej izolacji.

## Rozpatrzone alternatywy

Sam screenshot pozostaje użyteczny, lecz gubi semantykę komponentu. Sam CSS selector bez wersji jest niestabilny. Wyłącznie gest nacisku nie daje dostępnej alternatywy. Mapowanie większego nacisku jednocześnie na rodzica i element zza nakładki byłoby niejednoznaczne.

Powiązania: [PRD 5](../PRD.md), [HTML-REVIEW.md](../HTML-REVIEW.md), [ADR-0002](0002-immutable-versions-and-prototype-loop.md).
