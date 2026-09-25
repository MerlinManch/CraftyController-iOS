# Funktionsstand

Die App ist vollständig in SwiftUI gebaut und verwendet Craftys API v2 direkt. Die folgende Übersicht trennt vorhandene Oberflächen von Funktionen, die für echte Web-Parität noch eine Implementierung und Tests an einer Crafty-Instanz benötigen.

| Bereich | Stand | Einschränkung |
| --- | --- | --- |
| Verbindung, API-Schlüssel, Passwortanmeldung | Umgesetzt | HTTPS mit vertrauenswürdigem Zertifikat erforderlich; MFA-Abläufe noch offen. |
| Serverliste, Status, Kennzahlen | Umgesetzt | Datenfelder können je nach Crafty-Version variieren. |
| Starten, Stoppen, Neustarten | Umgesetzt | Berechtigungen werden von Crafty geprüft. |
| Konsole und Befehle | Umgesetzt | Logabruf erfolgt durch Aktualisieren, ohne dauerhaften Stream. |
| Dateien und Texteditor | Teilweise | API-Routen und Schreibformat müssen mit der Zielversion geprüft werden; binäre Uploads/Downloads fehlen. |
| Backups | Teilweise | Konfigurationen und Startaktion vorhanden; Wiederherstellen und Archivdownload fehlen. |
| Zeitpläne und Webhooks | Teilweise | Native Listen und JSON-Editor; spezialisierte Formulare und alle Einzelaktionen fehlen. |
| Server anlegen und konfigurieren | Teilweise | Native JSON-Eingabe; Assistent für Servertypen, Importe und Vorlagen fehlt. |
| Benutzer, Rollen und Profil | Teilweise | Listen und JSON-Editor; MFA, Passkeys, Passwort-Reset und detaillierte Rechteformulare fehlen. |
| Spieleraktionen, Serverreihenfolge, öffentliche Statusseite, Crafty-Updates | Offen | Individuelle native Abläufe fehlen. API-Werkzeug erlaubt vorhandene Endpunkte manuell aufzurufen. |

Vor einer Produktivfreigabe: Xcode-Build und Gerätetest, API-Abgleich mit der eingesetzten Crafty-Version, Testkonto mit differenzierten Rechten sowie Tests für große Dateien, Fehlerfälle und Hintergrundzustände.
