# ADR-0008 — Wbudowany klucz ElevenLabs i transkrypcja na żywo

Status: Przyjęte. Data: 2026-11-04. Zastępuje w ADR-0007 punkt „ElevenLabs: BYOK” oraz w ADR-0006 transkrypcję wyłącznie po Stop.

## Kontekst

Właściciel: klucz ElevenLabs ma być globalny, a nie wpisywany przez użytkownika. Tekst ma pojawiać się na żywo, a nagranie ma startować od razu po narysowaniu zaznaczenia.

## Decyzja

- Klucz jest wstrzykiwany przy buildzie wydania: `scripts/testflight.sh`, uruchomiony przez Apassy, zapisuje go do ignorowanego przez git `App/Config/Secrets.xcconfig`. Stamtąd trafia do `Info.plist` (`DSElevenLabsAPIKey`), a plik jest usuwany po archiwizacji. Klucza nie ma w repozytorium, logach, eksportach ani manifestach. Ustawienia nie mają pola na klucz.
- Nagrywanie startuje synchronicznie po zatwierdzeniu regionu lub komponentu. Sesja audio jest przygotowana wcześniej, a fragmenty audio są buforowane, dopóki łączy się WebSocket.
- Transkrypcja: ElevenLabs Scribe v2 Realtime (`scribe_v2_realtime`, WebSocket, PCM 16 kHz, commit przez VAD). Zatwierdzone segmenty od razu trafiają do treści uwagi, chyba że użytkownik pisał po starcie nagrania. Audio dalej zapisuje się lokalnie przed zakończeniem.
- Gdy transkrypcja na żywo zawiedzie, po Stop wykonywana jest jedna transkrypcja wsadowa Scribe v2. Nie ma automatycznych ponowień.

## Konsekwencje

Klucz jest w binarce i można go z niej wydobyć. Akceptowalne dla wewnętrznej dystrybucji TestFlight do jednej osoby. Przed szerszą dystrybucją trzeba przejść na krótkotrwałe tokeny (`token` w realtime API) wydawane przez zaufany host. Koszt i retencja dotyczą konta właściciela.

Powiązania: [ADR-0006](0006-auto-voice-and-elevenlabs.md), [ADR-0007](0007-native-mvp-implementation.md).
