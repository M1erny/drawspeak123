# ADR-0009 — Poprawa transkrypcji przez Claude, numeracja i nowy wątek

Status: Przyjęte. Data: 2026-11-04.

## Decyzja

- **Poprawa (Refine with Claude).** Po końcowej transkrypcji wycinek zaznaczonego obszaru (z oznaczeniem i kontekstem) oraz tekst idą do Claude Sonnet 5.5 (`claude-sonnet-5-5`, Messages API, `effort: low`, serwerowy fallback). Wraca zwięzły, techniczny opis w języku wypowiedzi. Surowa transkrypcja zostaje przy nagraniu („Show Original”). Tekst wpisany ręcznie nie jest nadpisywany: poprawka czeka na „Use Refined Text”. Domyślnie włączone, wyłączalne w Ustawieniach. Klucz Anthropic jest wbudowany przy wydaniu, tak jak klucz ElevenLabs (ADR-0008); dziś używany jest ogólny klucz z Apassy („revision Anthropic API key”).
- **Numeracja.** Numer uwagi na pinie i w paczce to kolejna pozycja wśród widocznych uwag canvasu, ciągła (1, 2, 3…). `ordinal` zostaje wewnętrznym, stałym identyfikatorem, a `noteId` mapowaniem w manifeście.
- **Wysłane uwagi** znikają z canvasu i listy; „Show Sent” je pokazuje. Edycja wysłanej uwagi tworzy nową rewizję, więc uwaga wraca.
- **Nowy wątek przy już wybranym.** „New Thread” jest dostępne zawsze. Po potwierdzonej wysyłce canvas kontynuuje w nowym wątku (jeden wątek na raz, ADR-0001). Historia wysyłek zachowuje swoich odbiorców.
- **Głos.** Nagrywanie kończy się po narysowaniu kolejnego zaznaczenia albo po 10 s ciszy. Panel uwag nie otwiera się sam; tekst na żywo pokazuje dymek przy pinie.

Powiązania: [ADR-0004](0004-feedback-package-and-two-tap-delivery.md), [ADR-0006](0006-auto-voice-and-elevenlabs.md), [ADR-0008](0008-built-in-key-and-live-transcription.md).
