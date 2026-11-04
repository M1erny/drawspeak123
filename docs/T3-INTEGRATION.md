# T3 Code przez Tailscale

Aktualny zakres i UX określa [PRD](PRD.md) oraz [ADR-0005](adr/0005-t3-transport-and-outbox.md). Ten dokument zachowuje szczegóły techniczne i datowane granice dowodów; nie oznacza wdrożenia wszystkich wymagań.

Stan badania: 2026-11-04. Inspekcja kodu lokalnie zainstalowanego T3 Code Nightly, bez uruchamiania połączenia, zmieniania konfiguracji lub odczytywania sekretów.

Build: `0.1.7-nightly.20261101.4016`, commit `7195b699547b`.
Archiwum: `/Applications/T3 Code (Nightly).app/Contents/Resources/app.asar`.
Poniższe numery linii odnoszą się do elementu archiwum `/apps/server/dist/binCli-Cos3Z5rn.mjs`, a nie pliku w tym projekcie.

## Potwierdzone w kodzie

| Obszar | Zachowanie | Linie bundle |
|---|---|---|
| Transport | HTTP MCP `/mcp`, protokół `2025-06-18`, middleware auth | 349330–349336 |
| Tailnet | `--tailscale-serve` udostępnia HTTPS; `--tailscale-serve-port`; `--lan` dopuszcza LAN/tailnet | 135275–135277 |
| Uwierzytelnienie | OAuth authorization code + PKCE S256, public client `none`; bearer token wymagany i sprawdzany | 4538–4568, 348822–348846 |
| Pairing | Decyzja parowania przez kod lub sesję przeglądarki; discovery, rejestracja klienta, authorize i token | 4595–4611, 20542–20558 |
| Załączniki | Przygotowanie uploadu, POST bajtów, jedna wiadomość z tablicą 1–8 załączników i tekstem do 120 000 znaków | 346309–346333 |
| Rozmiary | Obraz do 10 MiB, plik do 50 MiB; URL uploadu ważny 10 minut | 1905–1907, 35019 |
| Wykonanie | Send attachments używa `mode: auto`; rozpoczyna, steruje lub kolejkuje pracę. Brak retry key | 346322, 346371–346400 |
| Odczyt wątku | MCP read/list oraz autoryzowany REST shell/thread/transcript/bounded/history; REST wymaga nagłówka protokołu `2` | 20237–20240, 20587–20614 |
| Assety | WS `/ws`, RPC `assets.createUrl`: signed URL, expiry, dimensions, `fileRevision` | 334440, 37180, 37998–38002, 35006–35017 |
| Rewizja assetu | Identyfikator z dev/inode/size/mtime/ctime; nie hash zawartości ani archiwum wersji | 312243 |

W elemencie klienta `/apps/server/dist/client/assets/_chat-BTlfWs5R.js`, linie 12–13, stash zapisuje się w browser localStorage, limit 20 wpisów. W badanym kodzie nie znaleziono serwerowego API draft/stash. To wynik inspekcji tego buildu, nie gwarancja dla wszystkich wydań.

## Projektowany klient iPad

Natywny klient MCP przez wybrany adres HTTPS T3 Code w tailnecie. Aplikacja korzysta z obsługiwanego procesu autoryzacji T3 Code. Tailscale zapewnia osiągalność sieciową; nie zastępuje autoryzacji aplikacji. Domyślne ustawienia buildu (Serve wyłączony, port HTTPS 443, backend port 0) nie potwierdzają bieżącego adresu ani działającego serwera.

Draft/stash jest trwałym zapisem lokalnym na iPadzie. Nie korzysta z `send`, `queue` ani localStorage desktopu. Widoczność stash na desktopie wymagałaby osobnego, obsługiwanego rozszerzenia T3 Code.

Przy wysyłce aplikacja przygotowuje plan załączników i wyświetla odbiorcę oraz liczbę uwag. Wiele uwag na tym samym screenshotcie może być zebranych na jednym kompozycie z numerami; opis zachowuje mapowanie numer → noteId → snapshotId → tekst. Przykładowy budżet z wcześniejszego etapu: do 6 kompozytów, manifest i opcjonalne archiwum audio; razem maksymalnie 8 plików. Nie jest to produktowy limit sześciu ekranów. Format większego bundla HTML/obrazów/audio pozostaje do ustalenia według PRD. Oryginały, warstwy Pencil i nagrania pozostają w lokalnym review. Obsługa archiwum przez agenta jest do zweryfikowania. Przekroczenie budżetu zatrzymuje wysłanie i pokazuje sposób ograniczenia paczki; aplikacja nie rozdziela jej automatycznie na wiadomości.

Po przygotowaniu uploadów wykonywana jest jedna operacja wysłania. ACK i identyfikatory serwera zapisujemy lokalnie. Brak odpowiedzi po wysłaniu daje stan `deliveryUnknown`. Nie ponawiamy automatycznie wysłania: najpierw odczyt wątku i uzgodnienie batchId umieszczonego w treści. Lokalny batchId nie zapewnia idempotencji serwera.

Pull pobiera wiadomości/status i manifest skilla. Importer aplikacji tworzy własny katalog niezmiennych screenshotów, sprawdza SHA-256 i wiązanie review/wątek. Nie traktuje krótkotrwałego URL lub `fileRevision` jako trwałej wersji obrazu.

## Brakujące dowody przed natywnym MVP

- Osiągalny host i konfiguracja Tailscale Serve użytkownika.
- Pełny OAuth pairing na fizycznym iPadzie, w tym akceptacja redirect URI i przechowywanie tokenu w Keychain.
- Odczyt, upload i jedna wiadomość w izolowanym wątku testowym, z dowodem ACK i zachowania przy przerwaniu sieci.
- Parsowanie manifestu, wygasanie URL, ponowne pobranie i zachowanie lokalnych wersji.
- Faktyczna obsługa manifestu i archiwum audio przez docelowego agenta.

Nie uruchomiono Tailscale, pairing, uploadu ani wysłania do istniejącego wątku. Nie zmieniono kodu T3 Code. Badanie potwierdza możliwości kodu, nie działającą integrację urządzeń.
