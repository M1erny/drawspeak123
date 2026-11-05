# ADR-0010 — Polecenie dla agenta i monitorowanie runu

Status: Przyjęte (etap 1 wdrożony; etapy 2–3 to kierunek). Data: 2026-11-05.

## Kontekst

Wiadomość z uwagami zawsze kończyła się tą samą linią o skillu `ui-review-variants`. Skill bez podanej liczby tworzy dwie nowe propozycje, więc każda wysyłka dawała dwie makiety, także gdy uwagi dotyczyły propozycji, którą miała rozwinąć kolejna iteracja. Aplikacja nie pokazywała też, co agent robi po wysłaniu.

## Decyzja

**Etap 1 (wdrożony).** Podgląd wysyłki ma sekcję Agent z poleceniem (`AgentDirective`), zapisywanym w `OutboxEntry` i w treści wiadomości:

- **Continue** – następna iteracja propozycji, których dotyczą uwagi (`proposalId`, `screenId`, `parentSnapshotId`, numer iteracji = najwyższa + 1; `--previous` do ciągłości łańcucha). Uwagi na Now trafiają do jednej nowej propozycji. Domyślny, gdy wszystkie uwagi są na propozycjach.
- **New Variants** – 1, 2 lub 3 nowe propozycje; wiadomość podaje już użyte `proposalId`. Domyślny, gdy któraś uwaga jest na Now.
- **Reply Only** – odpowiedź tekstem, bez makiet i zmian plików.
- Dodatkowa instrukcja tekstowa jest przekazywana dosłownie.

Tryb podąża za wyborem uwag, dopóki osoba go sama nie wybierze. Ponowna wysyłka z historii używa zapisanego polecenia. Continue wymaga kontekstu agenta, więc przy New Thread podgląd ostrzega, że nowy wątek nie zna wcześniejszej pracy.

**Etap 2 (kierunek).** Monitor wątku po potwierdzonej wysyłce: pętla `t3_thread_wait` (≤ 25 s) i przyrostowy odczyt `t3_thread_read` (`view: activity`, `afterPosition`). Pasek statusu na canvasie: faza (wysłano, w kolejce, pracuje, czeka na decyzję, gotowe, błąd), jedna linia „teraz robi”, zwinięty podgląd aktywności. Auto-Pull po `completed`, włączony domyślnie, wyłączalny w Ustawieniach. Zatrzymanie po zniknięciu widoku lub wątku, wznowienie po powrocie z tła. MCP nie ma streamu (REST i WebSocket odrzucają token MCP), więc to long-poll.

**Etap 3 (kierunek).** Stop (`t3_thread_interrupt`, z potwierdzeniem) i Steer (`t3_thread_send` do trwającego runu) jako jawne akcje, nie domyślne zachowanie wysyłki.

## Konsekwencje

Wiadomość mówi agentowi, co ma zrobić, zamiast polegać na domyślnej liczbie w skillu. Stare wpisy bez polecenia dekodują się (`directive` opcjonalne). Dodatkowa instrukcja trafia do agenta bez filtrowania; jest treścią wpisaną przez właściciela urządzenia.

Powiązania: [ADR-0002](0002-immutable-versions-and-prototype-loop.md), [ADR-0004](0004-feedback-package-and-two-tap-delivery.md), [ADR-0009](0009-refine-numbering-and-new-thread.md), [kontrakt MCP §8](../T3-MCP-CONTRACT.md).
