# ADR-0004 — Automatyczna paczka i dwa tapnięcia do agent/draft

Status: Przyjęte przez użytkownika. Data: 2026-11-04.

Zastępuje wcześniejsze docelowe przebiegi z Save Comment, Notes/Review Batch, osobnym wyborem trybu lub blokowaniem całej paczki przez pusty region. Prototyp v3 nadal zawiera część tych dawnych zachowań.

## Kontekst

Użytkownik chce zebrać wiele par obraz/zaznaczenie/uwaga w jedną wiadomość, szybko przejrzeć zakres i wybrać agenta albo draft. Automatyczne zbieranie nie jest zgodą na automatyczną wysyłkę.

## Decyzja

Przebieg: **Feedback (N) → podgląd → Send to Agent / Save Draft → Sent / Draft Saved**.

1. Zaznaczenie uruchamia głos przy ON. Stop kończy nagranie; transkrypcja i poprawki zapisują się automatycznie lokalnie. Osobny Save Comment znika z docelowego flow.
2. Aplikacja domyślnie zbiera gotowe, niewysłane komentarze bieżącego canvasu. N liczy te uwagi.
3. Same oznaczenia bez tekstu, aktywne nagrania i transkrypcje w toku pozostają w szkicu; nie blokują gotowej części.
4. Podgląd zawiera odbiorcę, wybrane rewizje, numerowane anotacje i komentarze. Użytkownik może odznaczyć uwagi.
5. Dołączane są tylko snapshoty z wybranym komentarzem. Jeden snapshot raz, wiele oznaczeń na nim; różne wersje jednego ekranu pozostają osobne.
6. Wybrana uwaga z brakującym/niezgodnym źródłem jest jawnym problemem: trzeba naprawić źródło lub wyłączyć ją z wysyłanego zakresu.
7. Send to Agent wykonuje jedną wiadomość do przypisanego wątku. Save Draft odkłada paczkę lokalnie bez send/queue i wykonania agenta.
8. Po zebraniu gotowych uwag są dwa tapnięcia: Feedback i wybrana akcja. Bez osobnego mode pickera i dodatkowego potwierdzenia wysyłki.
9. Sent pojawia się po ACK serwera, z odbiorcą/liczbą; stan pracy agenta jest osobny. Draft Saved potwierdza trwały lokalny zapis. Wynik pozostaje dostępny, nie tylko w toast.

## Konsekwencje

Bieżący autosave i zapis konkretnej paczki to różne operacje. W UI wystarcza Save Draft; wcześniejszy stash jest technicznym/historycznym określeniem takiej odłożonej paczki. MVP nie synchronizuje draftu z desktopowym T3.

Podgląd i wysyłka dotyczą konkretnego zakresu/rewizji. Późna transkrypcja nie dopisuje uwagi po cichu do zatwierdzanego payloadu. Potwierdzone rewizje nie trafiają ponownie do domyślnej paczki; świadome powtórzenie jest opisane w tym samym podglądzie.

Natywna aplikacja wymaga trwałego magazynu i stanu gotowości uwag niezależnego od zaznaczenia checkboxa. Najnowsza kwalifikacja gotowych/niewysłanych i usunięcie Save Comment są do implementacji.

## Rozpatrzone alternatywy

Wyślij jako etykieta przycisku otwierającego tylko podgląd nie mówi precyzyjnie, co się stanie. Wysyłanie każdej uwagi osobno rozbija wspólny kontekst. Automatyczne wysłanie po Stop lub powrocie sieci może uruchomić agenta bez końcowej decyzji. Kolejne potwierdzenia po podglądzie zwiększają liczbę czynności.

Powiązania: [PRD 6–8 i AC-06–12](../PRD.md), [ADR-0005](0005-t3-transport-and-outbox.md), [ADR-0006](0006-auto-voice-and-elevenlabs.md).
