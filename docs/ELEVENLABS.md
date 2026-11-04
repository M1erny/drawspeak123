# Transkrypcja ElevenLabs

Aktualny zakres i UX określa [PRD](PRD.md) oraz [ADR-0006](adr/0006-auto-voice-and-elevenlabs.md). Ten dokument zachowuje szczegóły techniczne i datowane granice dowodów; nie oznacza wdrożenia wszystkich wymagań.

Decyzja: ElevenLabs, batch Scribe v2 po `Stop`. Stan na 2026-11-04: istnieje adapter funkcji Node 22 i testy z mockowanym `fetch`; HTML nadal symuluje nagranie/transkrypcję. Nie uruchomiono mikrofonu, API ElevenLabs, provisioningu ani połączenia z T3. Adapter nie jest serwerem HTTP ani endpointem T3.

## Przebieg docelowy

1. Przy rozpoczęciu nagrania przechwyć `canvasId`, `noteId`, `recordingId`. Automatyczny start po anotacji podlega ustawieniu użytkownika; ponowne otwarcie uwagi nie zaczyna nagrania.
2. Po `Stop` trwale zapisz audio na iPadzie pod tymi identyfikatorami **przed uploadem**. Zmiana canvasu i przerwanie zapisują dostępną część przy pierwotnej uwadze. Adapter nie implementuje zapisu plików.
3. Zaufany host pobiera zapisany plik i wywołuje adapter. W tej wersji całe audio wysyłamy po zakończeniu nagrania. Realtime wymaga osobnego transportu i walidacji; nie jest częścią adaptera.
4. Wynik zapisz automatycznie jako oryginalną transkrypcję nagrania, oddzielnie od edytowalnego tekstu. Gdy tekst nie był edytowany, gotowa transkrypcja zasila komentarz bez osobnego Save Comment. Istniejący tekst użytkownika zachowujemy; wynik można do niego jawnie dołączyć. Późna odpowiedź musi trafić do identyfikatorów z `result.scope`, niezależnie od aktualnego canvasu.

Przed zapisem sprawdź nadal istniejącą uwagę i tożsamość nagrania. Usunięta uwaga, nowe nagranie lub nowszy wynik nie mogą zostać odtworzone/nadpisane przez spóźnioną odpowiedź. Nie wiąż wyniku z „aktualnie zaznaczoną uwagą”.

## Kontrakt funkcji

Plik: [`adapters/elevenlabs-transcription.mjs`](../adapters/elevenlabs-transcription.mjs). Bez zależności; Node 22 zapewnia `Blob`, `FormData`, `fetch` i `AbortSignal`.

```js
import { createElevenLabsTranscriber } from './adapters/elevenlabs-transcription.mjs';

// apiKeyFromTrustedStore pochodzi z magazynu sekretów hosta, nigdy z HTML.
const transcribe = createElevenLabsTranscriber({ apiKey: apiKeyFromTrustedStore });
const result = await transcribe({
  audio: locallySavedAudioBlob,
  language: 'pl-PL', // pl / pol / pl-PL → pol; en / eng / en-US / en-GB → eng
  scope: { canvasId, noteId, recordingId },
  signal: abortController.signal, // opcjonalne
});
// result.scope, rawTranscript, words, requestedLanguage, detectedLanguage,
// languageProbability, provider, modelId — odrębnie od comment.text.
```

`scope` jest kopiowany przed pierwszym `await`; wynik, scope i tablica słów są zamrożone. Słowa zachowują `text`, `type`, `start`, `end`, `speaker_id`, `logprob`; brakujące opcjonalne wartości to `null`. Innych pól odpowiedzi nie przechowujemy. Pusta transkrypcja jest poprawnym wynikiem; nie dodajemy przykładowego tekstu. Funkcja nie modyfikuje wejścia i nie przyjmuje edytowalnego tekstu jako docelowego pola zapisu.

Lokalna polityka: niepusty Blob do 25 MiB; opcja `maxAudioBytes` może ten limit zmniejszyć. To **limit aplikacji**, nie limit dostawcy. Akceptowane typy: MP4/M4A, MP3/MPEG, AAC, WAV, FLAC, WebM, Ogg, 3GPP oraz pusty MIME/octet-stream do rozpoznania przez dostawcę. Walidacja bajtów kodeka i długości nagrania należy do warstwy capture; sama etykieta MIME nie dowodzi poprawności audio. API wymaga co najmniej 100 ms audio. Brak przycinania lub konwersji w adapterze.

Adapter wykonuje jeden `POST` do stałego `https://api.elevenlabs.io/v1/speech-to-text`. FormData zawiera `file`, `model_id=scribe_v2`, język ISO, `diarize=false`, `tag_audio_events=false`, `timestamps_granularity=word`. Nagłówek `xi-api-key` pochodzi z konfiguracji; Content-Type wraz z boundary ustawia runtime. Redirect kończy się błędem zamiast przenieść sekret na inny adres. Identyfikatory scope nie trafiają do formularza. Kontrakt i parametry: [oficjalne API Create transcript](https://elevenlabs.io/docs/api-reference/speech-to-text/convert).

## Sekret i retencja

Rekomendowana ścieżka: klucz dostawcy w Keychain lub innym magazynie sekretów **zaufanego hosta**, wstrzykiwany do funkcji dopiero podczas działania. Przyszły klient iPad może przechowywać w Keychain token sesji tego hosta. Host wymaga własnej autoryzacji, limitów uploadu i kosztów; sama osiągalność przez Tailscale nie autoryzuje żądania. Żadna z tych warstw nie jest jeszcze zaimplementowana.

Ewentualny model BYOK w natywnej aplikacji wymaga osobnej decyzji; wtedy indywidualny klucz w Keychain, nigdy w bundlu, repo, localStorage, eksporcie ani logach. Nie należy umieszczać stałego klucza w prototypie HTML. Nie pobieramy prawdziwego klucza na etapie testów mock.

Adapter nie loguje konfiguracji, danych ani błędów dostawcy. Błędy mają stałe komunikaty bez przyczyny upstream. Warstwa hosta również nie może logować nagłówków, argumentów funkcji, audio ani pełnej transkrypcji. Scope jest lokalną metadaną, nie identyfikatorem do logowania bez potrzeby.

Audio opuszcza urządzenie w momencie uploadu. Lokalna kopia pozostaje do poprawienia tekstu lub świadomego ponowienia; adapter jej nie usuwa. Domyślne `enable_logging=true` oznacza, że **nie obiecujemy zero retention**. Dokumentacja dopuszcza `enable_logging=false` wyłącznie dla klientów enterprise; adapter nie ustawia tej opcji. Okres retencji, region przetwarzania i warunki konta wymagają sprawdzenia przed live MVP. [Dokumentacja API i retencji](https://elevenlabs.io/docs/api-reference/speech-to-text/convert), [możliwości Speech to Text](https://elevenlabs.io/docs/overview/capabilities/speech-to-text).

## Błędy i lokalna kolejka

`TranscriptionError` udostępnia `code`, `scope` (jeśli poprawnie przechwycone), `status` albo `null` i `requestMayHaveBeenProcessed`. Kody: `invalid_config`, `invalid_request`, `auth`, `rate_limited`, `network`, `upstream`, `invalid_response`, `aborted`. Nie zawiera body błędu, klucza, obcego komunikatu ani `cause`. `AbortSignal` zatrzymuje oczekiwanie/transport, lecz po rozpoczęciu żądania nie gwarantuje anulowania przetwarzania ani kosztu u dostawcy.

Offline: audio i stan `Queued locally` zostają w trwałym magazynie klienta. Powrót sieci może pokazać `Ready to transcribe`; świadome ponowienie uruchamia nowe wywołanie. Autoryzacja wymaga naprawy konfiguracji hosta; 429 wymaga odczekania. Użytkownik zawsze może pisać komentarz ręcznie. Adapter nie implementuje kolejki i **nigdy automatycznie nie ponawia** płatnego żądania. Błąd sieci, timeout, abort lub niepoprawna odpowiedź po rozpoczęciu uploadu mogą oznaczać zakończone przetwarzanie: ręczne ponowienie może powtórzyć koszt. Lokalny `recordingId` nie zapewnia idempotencji ElevenLabs.

## Weryfikacja i brakujące dowody

Uruchom: `~/.local/bin/heavy-check node scripts/check-elevenlabs.mjs`. Wykonano lokalnie: **13/13 grup sprawdzeń, exit 0** (2026-11-04). Testy używają wyłącznie syntetycznych bajtów, sztucznego klucza i wstrzykniętego `fetch`; sprawdzają multipart, PL/EN, bezpieczne błędy, abort, scope, niezależność danych i brak retry. Nie potwierdzają zgodności rzeczywistego kodeka, jakości, ceny, opóźnienia ani uprawnień konta.

Przed live MVP pozostają: natywny capture i zgody mikrofonu; trwałe zapisanie/odzyskanie audio na fizycznym iPadzie; zaufany host i autoryzowany transport; magazyn sekretów; realna transkrypcja PL i EN oraz mowy mieszanej; test ciszy i przerwań; jakość słów technicznych; realny 401/429/offline i anulowanie; potwierdzenie retencji oraz kosztów; integracja wyniku z właściwym nagraniem po zmianie canvasu. T3/Tailscale wymagają odrębnych dowodów z [planu integracji](T3-INTEGRATION.md).
