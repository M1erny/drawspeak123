# ADR-0005 — T3 przez Tailscale i jawny outbox

Status: Przyjęty kierunek; live interoperability do weryfikacji. Data: 2026-11-04.

## Kontekst

Canvas jest związany z wątkiem T3, do którego ma przekazać wieloelementowy feedback oraz z którego ma pobrać warianty/status. Użytkownik wymaga natywnej integracji przez Tailscale.

## Decyzja

- Klient iPad łączy się z wybranym hostem T3 przez MCP/HTTPS w tailnecie.
- Autoryzacja T3 jest osobna od osiągalności przez Tailscale. Plan opiera się na odkrytym OAuth PKCE/bearer; działanie na iPadzie wymaga spike.
- Po wyborze Send to Agent aplikacja zamraża pokazaną paczkę, uploaduje załączniki i wykonuje jedną operację wiadomości. Może to uruchomić lub zakolejkować agenta.
- Lokalne OutboxEntry i receipt zapisują batchId, zakres, stan oraz potwierdzenie serwera. ACK nie oznacza ukończenia pracy agenta.
- Timeout po rozpoczęciu operacji daje Delivery Unknown. Najpierw uzgadniamy batchId z wątkiem; nie zakładamy idempotencji z lokalnego identyfikatora.
- Offline zachowuje dane. Powrót sieci lub restart nie wysyła automatycznie; użytkownik widzi Ready to Send.
- Draft MVP jest lokalny. Nie korzystamy z kolejki agenta jako ze szkicu ani nie synchronizujemy desktopowego localStorage.
- Pull weryfikuje manifest/hash i dodaje screenshoty/HTML, opis zmian oraz status, zachowując baseline i dawne wersje.

## Konsekwencje

Badanie zainstalowanego T3 jest datowanym dowodem kodu, nie działającą integracją. Zbadany build ograniczał wiadomość do 8 załączników, tekst do 120 000 znaków, obraz do 10 MiB, plik do 50 MiB. Limity docelowego hosta muszą być sprawdzone.

Wiele anotacji może dzielić jeden kompozyt. Obsługiwany format większego bundla HTML/obrazów/audio jest otwarty. Nie rozdzielamy feedbacku samoczynnie na wiadomości ani nie obiecujemy obsługi archiwum przez agenta bez testu.

Pozostają: host/port, pairing/redirect, magazyn tokenu, upload/ACK/reconcile, importer i adapter wyników skilla.

## Rozpatrzone alternatywy

Ręczny eksport/import nie realizuje docelowej natywnej pętli. Kolejka T3 uruchamia pracę i nie jest draftem. Ślepe retry może zdublować feedback lub wykonanie. Sam Tailscale nie daje autoryzacji aplikacji.

Powiązania: [PRD 8](../PRD.md), [datowane badanie T3](../T3-INTEGRATION.md), [ADR-0004](0004-feedback-package-and-two-tap-delivery.md).
