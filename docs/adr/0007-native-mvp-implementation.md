# ADR-0007 — Decyzje implementacyjne natywnego MVP

Status: Przyjęte. Data: 2026-11-04. Rozstrzyga otwarte kwestie z PRD sekcja 13 dla pierwszego buildu TestFlight.

## Kontekst

PRD i ADR-0001–0006 pozostawiły otwarte: minimalny iPadOS, silnik trwałości, magazyn klucza ElevenLabs, sposób parowania z T3 Code oraz pobieranie wyników agenta. Badanie zainstalowanego T3 (docs/T3-MCP-CONTRACT.md) wykazało, że klient MCP z tokenem OAuth nie może pobrać plików binarnych z wątku.

## Decyzja

- **Platforma.** iPadOS 27, wyłącznie iPad, SwiftUI i Swift 6.4 ze ścisłą współbieżnością. UIKit tylko tam, gdzie SwiftUI nie daje danych: warstwa wejścia (typ dotyku i siła Pencila) i WKWebView.
- **Moduły.** Pakiet `DrawspeakKit`: `DrawspeakCore` (model, trwałość, reguły paczki i outboxu), `T3Kit`, `VoiceKit`, `HTMLKit`, `CanvasKit`, `NotesKit`, `FeedbackKit`. Aplikacja tylko składa moduły.
- **Trwałość.** Jeden dokument JSON (`library.json`, zapis atomowy z opóźnieniem 250 ms i przy przejściu w tło) oraz magazyn blobów adresowany SHA-256. Bajty pod hashem są niezmienne, co realizuje niezmienność snapshotów z ADR-0002. Bez SwiftData: prosty format, łatwe testy i migracje.
- **ElevenLabs: BYOK.** To osobna decyzja przewidziana w ELEVENLABS.md. Aplikacja jednej osoby nie ma zaufanego hosta. Klucz wpisuje użytkownik w Ustawieniach (AutoFill z menedżera haseł). Klucz jest w Keychain (`AfterFirstUnlockThisDeviceOnly`), nigdy w bundlu, eksporcie, manifestach ani logach. Brak automatycznych ponowień płatnego żądania.
- **Parowanie T3.** Kod parowania z T3 Code na Macu (Settings › Sharing & access). Aplikacja rejestruje klienta, wysyła decyzję z kodem i wymienia kod autoryzacji z PKCE. Redirect `http://127.0.0.1/drawspeak/oauth/callback` jest tylko parsowany. Token 30 dni bez odświeżania jest w Keychain; po wygaśnięciu trzeba sparować ponownie.
- **Pull.** Agent zwraca manifest review i samodzielny HTML jako bloki tekstowe w odpowiedzi (format w skillu ui-review-variants). Aplikacja weryfikuje SHA-256, sama renderuje capture HTML i dodaje wersje obok Now. Pobieranie PNG z wątku wymaga drugiego tokenu poza MCP i pozostaje poza tym buildem.
- **Wysyłka.** Kompozyty PNG (jeden na snapshot) i manifest `drawspeak.feedback.v1` w jednej wiadomości `t3_thread_send_attachments`. Znacznik `drawspeak-batch:<id>` w treści służy do uzgadniania stanu Delivery Unknown.

## Konsekwencje

Pull obejmuje propozycje HTML; zrzuty PNG zwrócone przez agenta trzeba na razie zaimportować ręcznie. Klucz ElevenLabs pozostaje na urządzeniu; koszt i retencja są po stronie konta użytkownika. Wysyłka może uruchomić agenta (tryb `auto` T3), zgodnie z ADR-0005.

Powiązania: [PRD 13](../PRD.md), [T3-MCP-CONTRACT](../T3-MCP-CONTRACT.md), [ADR-0005](0005-t3-transport-and-outbox.md), [ADR-0006](0006-auto-voice-and-elevenlabs.md).
