# Przegląd poprawności HTML v3

Osobny subagent GPT-6.1 Sol, high, wykonał read-only przegląd prototype/index.html i scripts/check-model.cjs. Nie edytował kodu, nie uruchamiał przeglądarki, serwera ani testów; wynik zwrócił głównemu agentowi. To przegląd poprawności, nie ponowny audyt HIG/UX trzech modeli z v2.

## Dwa ustalenia i poprawki głównego agenta

1. Border zabierał 2 px live ramce, a podgląd HTML miał pełne 330×480. Responsive HTML mógł mieć inny layout. Poprawka: obramowanie przez box-shadow, wspólny viewport. Runtime QA w html_preview potwierdził live 330×480.
2. Zmiana na niegotowy HTML zostawiała poprzedni wybór i aktywny Confirm; gotowość ramki nie odświeżała pustego inspektora. Poprawka: czyszczenie pick i blokada Confirm przy zmianie, odświeżenie wyłącznie nadal wybranego, gotowego i podłączonego widoku. Testuje to rzeczywisty handler w check-model.cjs.

## Granice

Nie przeprowadzono ponownego niezależnego review po poprawkach. Weryfikację końcową prowadził główny agent. Fizyczne próbki Pencil, pointer capture na iPadzie, pełne egzekwowanie sandboxu, native audio oraz T3 wymagają osobnych dowodów.
