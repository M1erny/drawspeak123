# ADR-0002 — Niezmienne wersje i pętla prototypowania

Status: Przyjęte. Data: 2026-11-04.

## Kontekst

Review wymaga porównania istniejącego UI z kilkoma kierunkami oraz ich kolejnymi iteracjami. Komentarz musi pozostawać zrozumiały po kolejnej odpowiedzi agenta.

## Decyzja

- Now jest stabilnym baseline; Proposal A/B/N to niezależne kierunki obok siebie, każdy z Iteration 1/2/N.
- Każdy snapshot ma niezmienne źródło/capture, hashe, viewport i stan. Nadpisanie bajtów pod istniejącym id jest niedopuszczalne.
- Uwaga wskazuje konkretny snapshot. Ani geometria, ani locator DOM nie są automatycznie przenoszone na nową wersję.
- Pull dodaje wersje i statusy. Promote to Now tworzy jawną rewizję baseline i zachowuje poprzednie.
- Otwarcie starej uwagi daje jej oryginał oraz Show Source on Canvas.
- Skill ui-review-variants tworzy klikalne propozycje UI/funkcji z fixture data, screenshoty/HTML i manifest: proposalId, iteration, parentSnapshotId, hashe, zmiany i addressedNoteIds.
- Wybór kierunku, polecenie implementacji w aplikacji i promocja do Now są oddzielnymi intencjami.

## Konsekwencje

Potrzebny jest własny katalog wersji i importer manifestu. Rewizja assetu lub tymczasowy URL z T3 nie zastępuje trwałego snapshotu ani hasha. Oryginalne zasoby muszą pozostać dostępne dla dawnych uwag.

Nowe źródło, stan lub viewport HTML daje nowe capture. Dwie wersje tego samego ekranu w jednej paczce pozostają rozróżnione.

## Rozpatrzone alternatywy

Jedna liniowa historia nie opisuje niezależnych alternatyw. Zastępowanie Now przy każdym pull usuwa punkt odniesienia. Przepinanie uwag do podobnych elementów nowej wersji może zmienić znaczenie feedbacku.

Powiązania: [PRD 4 i 9](../PRD.md), [skill](../../.agents/skills/ui-review-variants/SKILL.md), [manifest](../../.agents/skills/ui-review-variants/references/manifest.md).
