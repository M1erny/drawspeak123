# Rejestr ADR — Drawspeak

Data decyzji: 2026-11-04. Źródło: ustalenia z użytkownikiem w wątku projektu. Status „Przyjęte” opisuje kierunek produktu/architektury, nie zakończenie implementacji lub testów live.

Bieżący zakres i kryteria akceptacji: [PRD](../PRD.md). Gdy zmienia się decyzja, należy dodać ADR zastępujący poprzedni i zaktualizować PRD; datowane dowody techniczne pozostają w notatkach.

| ADR | Decyzja | Status |
|---|---|---|
| [0001](0001-native-canvas-and-thread-scope.md) | Natywny iPad, pełnoekranowy canvas, osobny wątek na canvas | Przyjęte |
| [0002](0002-immutable-versions-and-prototype-loop.md) | Niezmienne wersje, Now/propozycje i skill prototypowania | Przyjęte |
| [0003](0003-html-component-selection.md) | Obrazy + HTML, wybór DOM naciskiem i osobny wybór warstw | Przyjęte; parametry do walidacji urządzeniowej |
| [0004](0004-feedback-package-and-two-tap-delivery.md) | Automatyczna paczka i Feedback → podgląd → agent/draft | Przyjęte; najnowszy flow do implementacji |
| [0005](0005-t3-transport-and-outbox.md) | MCP po Tailscale, jedna wiadomość, outbox i jawne potwierdzenia | Przyjęte; integracja live do weryfikacji |
| [0006](0006-auto-voice-and-elevenlabs.md) | Auto-głos ON, autosave, ElevenLabs Scribe v2 po Stop | Przyjęte; capture/live do implementacji |
| [0007](0007-native-mvp-implementation.md) | Natywny MVP: iPadOS 27, moduły SPM, JSON + bloby SHA-256, BYOK ElevenLabs, parowanie kodem T3, Pull przez text-bundle | Przyjęte |
| [0008](0008-built-in-key-and-live-transcription.md) | Wbudowany klucz ElevenLabs, nagrywanie od razu po zaznaczeniu, Scribe v2 Realtime | Przyjęte |
| [0009](0009-refine-numbering-and-new-thread.md) | Poprawa transkrypcji przez Claude Sonnet, ciągła numeracja, ukrywanie wysłanych, nowy wątek, auto-stop | Przyjęte |

Poprzednia specyfikacja z etapów v1–v3 jest [archiwum](../archive/PRODUCT-v1-v3.md). Zmiany od ostatniego kodu 08bd0da, w szczególności brak osobnego Save Comment, są wymaganiami, a nie opisem działającego prototypu.
