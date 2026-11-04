# ADR-0006 — Auto-głos, autosave i ElevenLabs

Status: Przyjęte. Data: 2026-11-04. Rzeczywisty capture i provider acceptance pozostają do weryfikacji.

## Kontekst

Pencil i głos mają ograniczyć przełączanie narzędzi podczas review. Użytkownik wskazał automatyczny start komentarza po zaznaczeniu oraz ElevenLabs jako dostawcę transkrypcji.

## Decyzja

- Nowy zatwierdzony region/DOMTarget automatycznie zaczyna głos. Auto-start jest domyślnie ON i ma ustawienie OFF; tekst oraz ręczny start pozostają dostępne.
- Stare uwagi, restart, zmiana canvasu, hover i sam podgląd hierarchii nie startują nagrania. Strzałka/ślad mogą istnieć bez komentarza.
- Widoczny stan z kotwicą oraz Stop/Discard daje kontrolę. Przypadkowy ruch nie tworzy nagrania. Pusty odrzucony region można usunąć odwracalnie.
- Stop kończy capture i zapisuje audio lokalnie przed wysyłką. W tym etapie transkrypcja jest batch, przez ElevenLabs Scribe v2, PL/EN.
- Audio, surowa transkrypcja i tekst po edycji pozostają osobne; autosave zastępuje osobne Save Comment.
- canvasId/noteId/recordingId są przechwycone przy starcie. Późny wynik nie zależy od obecnego zaznaczenia i nie nadpisuje nowszej pracy.
- Klucz dostawcy jest na zaufanym hoście, poza HTML, bundlem, eksportem i logami. Tailscale nie zastępuje autoryzacji hosta.
- Błąd/odmowa mikrofonu/offline zachowuje lokalne dane i ścieżkę tekstową. Brak automatycznych ponowień płatnego requestu; przerwanie nie fabrykuje transkrypcji.

## Konsekwencje

Auto-start jest świadomą preferencją użytkownika. Pierwsze użycie wymaga systemowej zgody; OFF i Discard muszą być łatwo dostępne. Po przejściu do innego canvasu dostępna część pozostaje u pierwotnej uwagi.

Audio opuszcza urządzenie przy uploadzie. Retencja, jakość PL/EN/mowy mieszanej, koszty i konfiguracja konta wymagają weryfikacji; nie obiecujemy zero retention.

Adapter Node jest funkcją hosta, nie serwerem/endpointem T3. Ma 13/13 grup mock; nie potwierdza mikrofonu, kodowania audio ani prawdziwego wywołania ElevenLabs.

## Rozpatrzone alternatywy

Ręczny start jako default zastąpiono wymaganym ON. Wyłącznie tekst usuwa podstawowy sposób review Pencilem i głosem. Realtime może być późniejszym rozszerzeniem; obecnie wybrano transkrypcję po Stop. Klucz zaszyty w HTML lub dystrybuowanym bundlu nie należy do przyjętej architektury.

Powiązania: [PRD 6–7](../PRD.md), [ELEVENLABS.md](../ELEVENLABS.md), [ADR-0004](0004-feedback-package-and-two-tap-delivery.md).
