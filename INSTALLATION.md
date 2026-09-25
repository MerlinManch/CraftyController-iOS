# Installation auf einem iPhone

Der Workflow **Unsigned iOS IPA** erzeugt eine absichtlich **unsignierte** IPA. Sie dient als Build-Artefakt und kann auf einem normalen iPhone nicht direkt aus der Dateien-App installiert oder gestartet werden.

## Direkt mit Xcode installieren

1. Repository auf einem Mac klonen und `CraftyNative.xcodeproj` in Xcode öffnen.
2. Beim Target **CraftyNative** unter **Signing & Capabilities** ein eigenes Team auswählen und die Bundle-ID `com.example.CraftyNative` durch eine eindeutige ID ersetzen.
3. Ein iPhone mit iOS 17 oder neuer als Ziel wählen. Auf dem Gerät bei Bedarf den Entwicklermodus aktivieren.
4. In Xcode auf **Run** klicken. Xcode baut und signiert die App für das verbundene Gerät.

Apple beschreibt den Ablauf unter [Running your app on simulated or physical devices](https://developer.apple.com/documentation/xcode/building-and-running-an-app).

## IPA-Artefakt verwenden

Der Download eines GitHub-Actions-Artefakts ist eine ZIP-Datei. Nach dem Entpacken liegt darin `CraftyNative-unsigned.ipa`. Diese IPA braucht vor der Installation eine gültige Apple-Signatur und ein zum Gerät und zur Bundle-ID passendes Provisioning Profile. Das aktuelle Artefakt enthält beides absichtlich nicht.

Wenn eine signierte Variante ebenfalls nicht startet, sind die genaue iOS-Fehlermeldung, die verwendete Installationsmethode und die iOS-Version nötig, um den nächsten Fehler einzugrenzen.
