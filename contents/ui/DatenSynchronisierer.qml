import QtQuick
import org.kde.plasma.plasma5support as P5Support

/*
 * Dieses Projekt steht unter der MIT-Lizenz.
 * Nextcloud CalDAV-Synchronisation via secret-tool (Secret Service API).
 * Kompatibel mit KeePassXC, KWallet und GNOME Keyring.
 */

Item {
    id: root
    visible: false

    // === Konfiguration (von main.qml gesetzt) ===
    property string benutzername: ""
    property string nextcloudUrl: ""
    property string kalenderPfad: "tasks"

    // === Interner Laufzeitzustand (Passwort nur im RAM, nie persistiert) ===
    property string _passwort: ""
    property bool passwortGeladen: false
    property bool synchronisiertGerade: false
    property var _syncAufgaben: []

    // === UI-Status ===
    property string statusNachricht: ""
    property bool hatFehler: false

    readonly property bool kannSynchronisieren:
        nextcloudUrl.length > 0 &&
        benutzername.length > 0 &&
        passwortGeladen &&
        _passwort.length > 0

    // === Signale ===
    signal passwortLadeFertig(bool erfolg)
    signal aufgabenEmpfangen(var aufgaben)        // Array von Aufgaben-Objekten
    signal synchronisationFertig(bool erfolg, string nachricht)

    // -------------------------------------------------------------------
    // Passwort-Verwaltung  (Secret Service API über secret-tool)
    // Funktioniert mit KeePassXC (SecretService-Integration aktiviert),
    // KWallet und GNOME Keyring.
    // -------------------------------------------------------------------

    function ladePasswort() {
        if (!benutzername) {
            root.hatFehler = true;
            root.statusNachricht = "Kein Benutzername konfiguriert";
            root.passwortLadeFertig(false);
            return;
        }
        const cmd = "secret-tool lookup service nextcloud-todo-kde username " + _sq(benutzername);
        passwortLadenEngine.connectSource("sh -c " + _sq(cmd));
    }

    function speicherePasswort(passwort) {
        if (!benutzername || !passwort) return;
        root._passwort = passwort;
        const label = "Nextcloud App-Passwort (" + benutzername + ")";
        const cmd = "printf '%s' " + _sq(passwort)
            + " | secret-tool store --label=" + _sq(label)
            + " service nextcloud-todo-kde username " + _sq(benutzername);
        passwortSpeichernEngine.connectSource("sh -c " + _sq(cmd));
    }

    function loeschePasswort() {
        root._passwort = "";
        root.passwortGeladen = false;
        const cmd = "secret-tool clear service nextcloud-todo-kde username " + _sq(benutzername);
        passwortSpeichernEngine.connectSource("sh -c " + _sq(cmd));
    }

    // -------------------------------------------------------------------
    // Synchronisation (bidirektional, einfach):
    //   1. Lokale Aufgaben (ohne uid → neue uid generieren) → PUT zum Server
    //   2. REPORT vom Server → Server-Aufgaben einlesen
    //   3. Merge: lokale Etags aktualisieren, server-exklusive Aufgaben lokal hinzufügen
    // -------------------------------------------------------------------

    function synchronisiere(aufgaben) {
        if (!kannSynchronisieren) {
            root.statusNachricht = "Nicht konfiguriert – bitte Einstellungen öffnen";
            root.synchronisationFertig(false, root.statusNachricht);
            return;
        }
        if (root.synchronisiertGerade) return;

        // Sicherheitskopie erstellen, neue UIDs für lokale Aufgaben generieren
        const lokal = [];
        for (let i = 0; i < aufgaben.length; i++) {
            const a = aufgaben[i];
            lokal.push({
                beschreibung: a.beschreibung || "",
                prioritaet:   a.prioritaet  || 0,
                faelligkeit:  a.faelligkeit || "",
                erledigt:     !!a.erledigt,
                untereintraege: _kloneUntereintraege(a.untereintraege),
                uid:       (a.uid  && a.uid.length  > 0) ? a.uid  : _generiereUuid(),
                etag:      a.etag      || "",
                caldavHref: a.caldavHref || ""
            });
        }

        root._syncAufgaben       = lokal;
        root.synchronisiertGerade = true;
        root.hatFehler           = false;
        root.statusNachricht     = "Synchronisiere mit Nextcloud…";

        syncEngine.connectSource("sh -c " + _sq(_baueSyncScript(lokal)));
    }

    // -------------------------------------------------------------------
    // Interne Hilfsfunktionen
    // -------------------------------------------------------------------

    function _baseUrl() {
        return (nextcloudUrl || "").replace(/\/$/, "");
    }

    function _caldavUrl() {
        return _baseUrl()
            + "/remote.php/dav/calendars/"
            + encodeURIComponent(benutzername)
            + "/" + kalenderPfad + "/";
    }

    // Einfaches single-quote Escaping für Shell-Argumente
    function _sq(text) {
        return "'" + String(text || "").replace(/'/g, "'\"'\"'") + "'";
    }

    function _generiereUuid() {
        return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
            const r = Math.random() * 16 | 0;
            return (c === 'x' ? r : (r & 0x3 | 0x8)).toString(16);
        });
    }

    // Unicode-String → UTF-8 → Base64 (für Einbettung in Shell-Skript)
    function _zumBase64(text) {
        try {
            const enc = new TextEncoder();
            const bytes = enc.encode(text);
            let bin = "";
            for (let i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i]);
            return btoa(bin);
        } catch (e) {
            return btoa(unescape(encodeURIComponent(text)));
        }
    }

    function _kloneUntereintraege(liste) {
        if (!Array.isArray(liste)) return [];
        return liste.map(function(u) {
            return { beschreibung: u.beschreibung || "", prioritaet: u.prioritaet || 0, erledigt: !!u.erledigt };
        });
    }

    // iCal-Datum (20240105 oder 20240105T120000Z) → YYYY-MM-DD
    function _icalDatumZuIso(wert) {
        const bereinigt = String(wert || "").replace(/T.*$/, "");
        if (bereinigt.length === 8) {
            return bereinigt.substring(0, 4) + "-" + bereinigt.substring(4, 6) + "-" + bereinigt.substring(6, 8);
        }
        return "";
    }

    // YYYY-MM-DD → 20240105
    function _isoDatumZuIcal(iso) {
        return String(iso || "").replace(/-/g, "");
    }

    // iCal-Priorität (1-9) → intern (0/1/2)
    function _icalPrioZuIntern(p) {
        const n = parseInt(p) || 0;
        if (n >= 1 && n <= 4) return 2;   // Hoch
        if (n === 5)          return 1;   // Mittel
        return 0;                          // Niedrig / undefiniert
    }

    // Intern (0/1/2) → iCal-Priorität
    function _internPrioZuIcal(intern) {
        switch (intern) { case 2: return 1; case 1: return 5; default: return 9; }
    }

    // Sonderzeichen in iCal-Text-Properties escapen (RFC 5545)
    function _icalEscapen(text) {
        return String(text || "")
            .replace(/\\/g, "\\\\")
            .replace(/;/g,  "\\;")
            .replace(/,/g,  "\\,")
            .replace(/\n/g, "\\n")
            .replace(/\r/g, "");
    }

    // RFC 5545: Zeilen auf 75 Zeichen falten (CRLF + Leerzeichen)
    function _falteLinie(line) {
        if (line.length <= 75) return line;
        let result = line.substring(0, 75);
        let rest   = line.substring(75);
        while (rest.length > 0) {
            result += "\r\n " + rest.substring(0, 74);
            rest    = rest.substring(74);
        }
        return result;
    }

    // Aufgaben-Objekt → iCal VTODO-String
    function _aufgabeZuVtodo(aufgabe) {
        const jetzt = new Date();
        const ts = jetzt.toISOString().replace(/[-:.]/g, "").substring(0, 15) + "Z";
        const uid = aufgabe.uid || _generiereUuid();

        let ical = "BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//KDE Plasma ToDo//DE\r\n";
        ical += "BEGIN:VTODO\r\n";
        ical += "UID:"           + uid + "\r\n";
        ical += "DTSTAMP:"       + ts  + "\r\n";
        ical += "LAST-MODIFIED:" + ts  + "\r\n";
        ical += _falteLinie("SUMMARY:" + _icalEscapen(aufgabe.beschreibung)) + "\r\n";
        ical += "STATUS:"            + (aufgabe.erledigt ? "COMPLETED"  : "NEEDS-ACTION") + "\r\n";
        ical += "PERCENT-COMPLETE:"  + (aufgabe.erledigt ? "100" : "0") + "\r\n";
        ical += "PRIORITY:"          + _internPrioZuIcal(aufgabe.prioritaet) + "\r\n";
        if (aufgabe.faelligkeit) {
            ical += "DUE;VALUE=DATE:" + _isoDatumZuIcal(aufgabe.faelligkeit) + "\r\n";
        }
        if (aufgabe.untereintraege && aufgabe.untereintraege.length > 0) {
            ical += _falteLinie("X-KDE-SUBTASKS:" + JSON.stringify(aufgabe.untereintraege)) + "\r\n";
        }
        ical += "END:VTODO\r\nEND:VCALENDAR\r\n";
        return ical;
    }

    // iCal VTODO-String → Aufgaben-Objekt (null wenn nicht parsierbar)
    function _parsiereVtodo(icalText, href, etag) {
        // Zeilenfortsetzungen entfalten (RFC 5545)
        const text = icalText
            .replace(/\r\n/g, "\n").replace(/\r/g, "\n")
            .replace(/\n[ \t]/g, "");
        const zeilen = text.split("\n");

        let uid = "", zusammenfassung = "", prioritaet = "",
            faelligkeit = "", status = "", unterJson = "";
        let inVtodo = false;

        for (const z of zeilen) {
            const l = z.trim();
            if (l === "BEGIN:VTODO")          { inVtodo = true;  continue; }
            if (l === "END:VTODO")            { break; }
            if (!inVtodo)                     continue;

            if      (l.startsWith("UID:"))               uid           = l.substring(4).trim();
            else if (l.startsWith("SUMMARY:"))            zusammenfassung = l.substring(8)
                .replace(/\\n/g, "\n").replace(/\\,/g, ",")
                .replace(/\\;/g, ";").replace(/\\\\/g, "\\").trim();
            else if (l.startsWith("PRIORITY:"))          prioritaet    = l.substring(9).trim();
            else if (l.startsWith("DUE;VALUE=DATE:"))    faelligkeit   = _icalDatumZuIso(l.substring(15).trim());
            else if (l.startsWith("DUE:"))               faelligkeit   = _icalDatumZuIso(l.substring(4).trim());
            else if (l.startsWith("STATUS:"))            status        = l.substring(7).trim();
            else if (l.startsWith("PERCENT-COMPLETE:"))  { if ((parseInt(l.substring(17)) || 0) === 100) status = "COMPLETED"; }
            else if (l.startsWith("X-KDE-SUBTASKS:"))   unterJson     = l.substring(15).trim();
        }

        if (!uid || !zusammenfassung) return null;

        let untereintraege = [];
        if (unterJson) {
            try { untereintraege = JSON.parse(unterJson); } catch (e) { untereintraege = []; }
        }

        return {
            beschreibung:  zusammenfassung,
            prioritaet:    _icalPrioZuIntern(prioritaet),
            faelligkeit:   faelligkeit,
            erledigt:      (status === "COMPLETED"),
            untereintraege: untereintraege,
            uid:           uid,
            etag:          String(etag || "").replace(/"/g, ""),
            caldavHref:    href
        };
    }

    // CalDAV Multistatus-XML → Array von Aufgaben-Objekten
    function _parsiereMultistatus(xmlText) {
        const aufgaben = [];
        // Namespace-agnostische Regex für <X:response> Blöcke
        const respRegex = /<[^:>\s]*:?response[^>]*>([\s\S]*?)<\/[^:>\s]*:?response>/g;
        let m;
        while ((m = respRegex.exec(xmlText)) !== null) {
            const block = m[1];
            const hrefM = block.match(/<[^:>\s]*:?href[^>]*>\s*(.*?)\s*<\/[^:>\s]*:?href>/);
            if (!hrefM || !hrefM[1].endsWith(".ics")) continue;
            const href  = hrefM[1].trim();
            const etagM = block.match(/<[^:>\s]*:?getetag[^>]*>\s*"?([^"<\s]*)"?\s*<\/[^:>\s]*:?getetag>/);
            const etag  = etagM ? etagM[1] : "";
            const calM  = block.match(/<[^:>\s]*:?calendar-data[^>]*>([\s\S]*?)<\/[^:>\s]*:?calendar-data>/);
            if (!calM) continue;
            const ical  = calM[1]
                .replace(/&amp;/g, "&").replace(/&lt;/g, "<")
                .replace(/&gt;/g,  ">").replace(/&quot;/g, '"');
            const aufgabe = root._parsiereVtodo(ical, href, etag);
            if (aufgabe) aufgaben.push(aufgabe);
        }
        return aufgaben;
    }

    // Baut das Shell-Skript: PUT alle lokalen Aufgaben → REPORT (Download)
    function _baueSyncScript(aufgaben) {
        const calUrl = _caldavUrl();
        let s = "#!/bin/sh\n";
        s += "NC_USER=" + _sq(benutzername) + "\n";
        s += "NC_PASS=" + _sq(_passwort)    + "\n";
        s += "CAL_URL=" + _sq(calUrl)       + "\n\n";

        // Jede Aufgabe als iCal → Base64 → Temp-Datei → PUT
        for (let i = 0; i < aufgaben.length; i++) {
            const a    = aufgaben[i];
            const ical = _aufgabeZuVtodo(a);
            const b64  = _zumBase64(ical);
            const uid  = a.uid;
            const tmp  = "/tmp/nc_todo_" + uid.replace(/-/g, "") + ".ics";

            s += "printf '%s' " + _sq(b64) + " | base64 -d > " + _sq(tmp) + "\n";
            s += "curl -sf -o /dev/null -u \"${NC_USER}:${NC_PASS}\" -X PUT";
            s += " -H 'Content-Type: text/calendar; charset=utf-8'";
            if (a.etag) {
                // If-Match verhindert versehentliches Überschreiben bei Konflikt
                s += " -H " + _sq("If-Match: \"" + a.etag + "\"");
            }
            s += " --data-binary @" + _sq(tmp) + " \"${CAL_URL}" + uid + ".ics\"";
            s += " || true\n";   // 412 Precondition Failed ignorieren
            s += "rm -f " + _sq(tmp) + "\n";
        }

        // CalDAV REPORT: alle VTODO-Einträge vom Server laden
        const reportXml =
            '<c:calendar-query xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">'
            + '<d:prop><d:getetag/><c:calendar-data/></d:prop>'
            + '<c:filter><c:comp-filter name="VCALENDAR">'
            + '<c:comp-filter name="VTODO"/>'
            + '</c:comp-filter></c:filter>'
            + '</c:calendar-query>';

        s += "\ncurl -s -w '\\n__STATUS__%{http_code}'";
        s += " -u \"${NC_USER}:${NC_PASS}\"";
        s += " -X REPORT";
        s += " -H 'Content-Type: application/xml; charset=utf-8'";
        s += " -H 'Depth: 1'";
        s += " --data " + _sq(reportXml);
        s += " \"${CAL_URL}\"\n";
        return s;
    }

    // -------------------------------------------------------------------
    // DataSource-Instanzen (P5Support Executable Engine)
    // -------------------------------------------------------------------

    P5Support.DataSource {
        id: passwortLadenEngine
        engine: "executable"
        onNewData: function(src, data) {
            disconnectSource(src);
            removeSource(src);
            const code = data["exit code"] !== undefined ? data["exit code"] : 1;
            const pw   = String(data["stdout"] || "").trim();
            if (code === 0 && pw.length > 0) {
                root._passwort      = pw;
                root.passwortGeladen = true;
                root.hatFehler      = false;
                root.statusNachricht = "";
            } else {
                root._passwort      = "";
                root.passwortGeladen = false;
                root.hatFehler      = true;
                root.statusNachricht = "Passwort nicht im Schlüsselbund – bitte in Einstellungen eingeben";
            }
            root.passwortLadeFertig(root.passwortGeladen);
        }
    }

    P5Support.DataSource {
        id: passwortSpeichernEngine
        engine: "executable"
        onNewData: function(src, data) {
            disconnectSource(src);
            removeSource(src);
            const code = data["exit code"] !== undefined ? data["exit code"] : 1;
            if (code !== 0) {
                root.statusNachricht = "Passwort konnte nicht im Schlüsselbund gespeichert werden";
                root.hatFehler = true;
            }
        }
    }

    P5Support.DataSource {
        id: syncEngine
        engine: "executable"
        onNewData: function(src, data) {
            disconnectSource(src);
            removeSource(src);
            root.synchronisiertGerade = false;

            const code   = data["exit code"] !== undefined ? data["exit code"] : 1;
            const ausgabe = String(data["stdout"] || "").trim();

            // HTTP-Statuscode aus Ausgabe extrahieren
            const statusM  = ausgabe.match(/__STATUS__(\d+)\s*$/m);
            const httpCode  = statusM ? parseInt(statusM[1]) : 0;
            const xmlBody   = ausgabe.replace(/\n?__STATUS__\d+\s*$/, "").trim();

            if (code !== 0 || (httpCode !== 0 && (httpCode < 200 || httpCode > 299))) {
                root.hatFehler      = true;
                root.statusNachricht = "Sync fehlgeschlagen (HTTP " + (httpCode || code) + ")";
                root.synchronisationFertig(false, root.statusNachricht);
                return;
            }

            // Server-Aufgaben parsen
            const serverAufgaben = root._parsiereMultistatus(xmlBody);

            // Merge: lokale Aufgaben behalten, Etags aktualisieren,
            // server-exklusive Aufgaben lokal hinzufügen
            const lokal    = root._syncAufgaben.slice();
            const lokaleUids = {};
            for (let i = 0; i < lokal.length; i++) lokaleUids[lokal[i].uid] = true;

            for (let i = 0; i < serverAufgaben.length; i++) {
                const srv = serverAufgaben[i];
                let gefunden = false;
                for (let j = 0; j < lokal.length; j++) {
                    if (lokal[j].uid === srv.uid) {
                        // Etag und Href vom Server aktualisieren
                        lokal[j].etag       = srv.etag;
                        lokal[j].caldavHref = srv.caldavHref;
                        gefunden = true;
                        break;
                    }
                }
                // Aufgabe nur auf Server → lokal hinzufügen
                if (!gefunden) lokal.push(srv);
            }

            root.hatFehler      = false;
            root.statusNachricht = lokal.length + " Aufgaben synchronisiert";
            root.aufgabenEmpfangen(lokal);
            root.synchronisationFertig(true, root.statusNachricht);
        }
    }
}
