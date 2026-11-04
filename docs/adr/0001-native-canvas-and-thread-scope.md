# ADR-0001 — Natywny canvas i zakres wątku

Status: Przyjęte. Data: 2026-11-04.

## Kontekst

Użytkownik chce prowadzić review UI na iPadzie, głównie Apple Pencilem, z modelem pracy jak w Freeform. Uwagi mają trafiać do odpowiedniego wątku T3 bez mieszania kontekstów.

## Decyzja

- Produkt docelowy jest natywną aplikacją iPadOS w SwiftUI dla jednej osoby.
- Główną przestrzenią jest pełnoekranowy canvas z pan/zoom, swobodnym układem widoków i pływającymi paletami/inspektorami.
- Project zawiera wiele ReviewCanvas. Każdy canvas jest powiązany z jednym T3Thread; osobne wątki mają osobne canvasy.
- Kamera, uwagi, zasoby i paczki należą do canvasu. Nagranie i asynchroniczny import zachowują pierwotnego właściciela.
- Pencil jest podstawowym narzędziem; Pencil Pro squeeze otwiera paletę. Domyślnie palec przesuwa canvas, a Draw with finger pozwala włączyć rysowanie palcem.
- Istotne funkcje mają odpowiedniki bez gestu; kontrolki i piny zachowują ekranowy rozmiar przy zoomie.

## Konsekwencje

Natywna trwałość, gesty/Pencil Pro, safe areas i dostępność wymagają implementacji i testów na fizycznym iPadzie. HTML prototyp waliduje układ/interakcje, nie potwierdza native acceptance.

Stały sidebar nie jest podstawą układu; szczegóły pojawiają się na żądanie. UI musi adaptować się do dostępnej przestrzeni, z zachowaniem tych samych funkcji i informacji o wątku.

## Rozpatrzone alternatywy

Jeden canvas dla wielu wątków odrzucono z powodu niejednoznacznego odbiorcy paczki. Osobny canvas na każdy screenshot utrudnia porównywanie. Docelowa aplikacja webowa nie daje przyjętej natywnej ścieżki Pencil/audio/zasobów.

Powiązania: [PRD 2–3](../PRD.md), [ADR-0004](0004-feedback-package-and-two-tap-delivery.md).
