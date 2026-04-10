import QtQuick
import org.kde.plasma.plasma5support as P5Support

/*
 * Dieses Projekt steht unter der MIT-Lizenz.
 * Nextcloud CalDAV-Synchronisation mit Secret Service fuer Passwortspeicherung.
 * Der Netzverkehr laeuft direkt ueber HTTPS-Requests statt ueber Shell und curl.
 */

Item {
    id: root
    visible: false

    property string benutzername: ""
    property string nextcloudUrl: ""
    property string kalenderPfad: "tasks"

    property string _passwort: ""
    property bool passwortGeladen: false
    property bool synchronisiertGerade: false
    property var _syncAufgaben: []
    property bool _syncNachPasswortLaden: false

    property string statusNachricht: ""
    property bool hatFehler: false

    readonly property bool hatSichereKonfiguration:
        _hatSichereServerUrl() &&
        _normalisiereKalenderPfad(kalenderPfad).length > 0 &&
        benutzername.trim().length > 0

    readonly property bool kannSynchronisieren:
        hatSichereKonfiguration &&
        passwortGeladen &&
        _passwort.length > 0

    signal passwortLadeFertig(bool erfolg)
    signal aufgabenEmpfangen(var aufgaben)
    signal synchronisationFertig(bool erfolg, string nachricht)

    Component.onCompleted: {
        if (benutzername.trim().length > 0) {
            ladePasswort();
        }
    }

    onBenutzernameChanged: {
        if (benutzername.trim().length > 0) {
            ladePasswort();
        }
    }

    function ladePasswort() {
        if (!benutzername.trim()) {
            root.hatFehler = true;
            root.statusNachricht = "Kein Benutzername konfiguriert";
            root.passwortLadeFertig(false);
            return;
        }

        const cmd = "secret-tool lookup service nextcloud-todo-kde username " + _sq(benutzername.trim());
        passwortLadenEngine.connectSource("sh -c " + _sq(cmd));
    }

    function speicherePasswort(passwort) {
        if (!benutzername.trim() || !passwort) {
            return;
        }

        root._passwort = passwort;
        root.passwortGeladen = true;
        root.hatFehler = false;
        root.statusNachricht = "";

        const label = "Nextcloud App-Passwort (" + benutzername.trim() + ")";
        const cmd = "printf '%s' " + _sq(passwort)
            + " | secret-tool store --label=" + _sq(label)
            + " service nextcloud-todo-kde username " + _sq(benutzername.trim());
        passwortSpeichernEngine.connectSource("sh -c " + _sq(cmd));
    }

    function loeschePasswort() {
        root._passwort = "";
        root.passwortGeladen = false;
        const cmd = "secret-tool clear service nextcloud-todo-kde username " + _sq(benutzername.trim());
        passwortSpeichernEngine.connectSource("sh -c " + _sq(cmd));
    }

    function synchronisiere(aufgaben) {
        if (root.synchronisiertGerade) {
            return;
        }

        // Basis-Konfiguration prüfen (ohne Passwort)
        if (!benutzername.trim()) {
            _fehlschlag("Benutzername fehlt – bitte Einstellungen öffnen");
            return;
        }
        if (!_hatSichereServerUrl()) {
            _fehlschlag("Nur HTTPS-URLs sind erlaubt");
            return;
        }

        // Aufgaben vormerken (für Passwort-Nachladen)
        const lokal = [];
        for (let i = 0; i < aufgaben.length; i++) {
            const a = aufgaben[i] || {};
            lokal.push({
                beschreibung: a.beschreibung || "",
                prioritaet: a.prioritaet || 0,
                faelligkeit: a.faelligkeit || "",
                erledigt: !!a.erledigt,
                untereintraege: _kloneUntereintraege(a.untereintraege),
                uid: (a.uid && a.uid.length > 0) ? a.uid : _generiereUuid(),
                etag: a.etag || "",
                caldavHref: a.caldavHref || ""
            });
        }
        root._syncAufgaben = lokal;

        // Passwort noch nicht geladen → erst laden, dann automatisch Sync starten
        if (!passwortGeladen || !_passwort) {
            root._syncNachPasswortLaden = true;
            root.statusNachricht = "Lade Passwort...";
            ladePasswort();
            return;
        }

        _startSync(lokal);
    }

    function _startSync(lokal) {
        root.synchronisiertGerade = true;
        root.hatFehler = false;
        root.statusNachricht = "Synchronisiere mit Nextcloud...";
        _syncLokaleAufgabe(0, lokal, [], {});
    }

    function _pruefeKonfiguration() {
        if (!benutzername.trim()) {
            return { gueltig: false, nachricht: "Benutzername fehlt" };
        }
        if (!_hatSichereServerUrl()) {
            return { gueltig: false, nachricht: "Nur HTTPS-URLs sind erlaubt" };
        }
        if (_normalisiereKalenderPfad(kalenderPfad).length === 0) {
            return { gueltig: false, nachricht: "Kalenderpfad ist ungueltig" };
        }
        if (!passwortGeladen || !_passwort) {
            return { gueltig: false, nachricht: "Passwort nicht geladen" };
        }
        return { gueltig: true, nachricht: "" };
    }

    function _hatSichereServerUrl() {
        const url = String(nextcloudUrl || "").trim();
        return /^https:\/\/.+/i.test(url);
    }

    function _baseUrl() {
        const url = String(nextcloudUrl || "").trim();
        try {
            // Extrahiert nur Protocol + Host aus beliebiger URL
            // Z.B.: "https://cloud.zakyx.de/apps/tasks/..." → "https://cloud.zakyx.de"
            const match = url.match(/^(https?:\/\/[^\/]+)/i);
            return match ? match[1] : url.replace(/\/+$/, "");
        } catch (error) {
            return url.replace(/\/+$/, "");
        }
    }

    function _normalisiereKalenderPfad(pfad) {
        const teile = String(pfad || "")
            .split("/")
            .map(function(segment) { return segment.trim(); })
            .filter(function(segment) {
                return segment.length > 0 && segment !== "." && segment !== "..";
            });

        for (let i = 0; i < teile.length; i++) {
            if (!/^[A-Za-z0-9._~-]+$/.test(teile[i])) {
                return "";
            }
        }

        return teile.join("/");
    }

    function _caldavUrl() {
        return _baseUrl()
            + "/remote.php/dav/calendars/"
            + encodeURIComponent(benutzername.trim())
            + "/" + _normalisiereKalenderPfad(kalenderPfad) + "/";
    }

    function _sq(text) {
        return "'" + String(text || "").replace(/'/g, "'\"'\"'") + "'";
    }

    function _generiereUuid() {
        return "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, function(c) {
            const r = Math.random() * 16 | 0;
            return (c === "x" ? r : (r & 0x3 | 0x8)).toString(16);
        });
    }

    function _utf8ZuBase64(text) {
        // Reine JS-Implementierung (btoa/TextEncoder nicht in QML verfügbar)
        const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
        // UTF-8 kodieren
        const str = String(text || "");
        let bytes = [];
        for (let i = 0; i < str.length; i++) {
            let c = str.charCodeAt(i);
            if (c < 128) {
                bytes.push(c);
            } else if (c < 2048) {
                bytes.push((c >> 6) | 192, (c & 63) | 128);
            } else {
                bytes.push((c >> 12) | 224, ((c >> 6) & 63) | 128, (c & 63) | 128);
            }
        }
        // Base64 kodieren
        let result = "";
        for (let i = 0; i < bytes.length; i += 3) {
            const b0 = bytes[i], b1 = bytes[i+1] || 0, b2 = bytes[i+2] || 0;
            result += chars[b0 >> 2];
            result += chars[((b0 & 3) << 4) | (b1 >> 4)];
            result += (i + 1 < bytes.length) ? chars[((b1 & 15) << 2) | (b2 >> 6)] : "=";
            result += (i + 2 < bytes.length) ? chars[b2 & 63] : "=";
        }
        return result;
    }

    function _authHeader() {
        return "Basic " + _utf8ZuBase64(benutzername.trim() + ":" + _passwort);
    }

    function _kloneUntereintraege(liste) {
        if (!Array.isArray(liste)) {
            return [];
        }

        return liste.map(function(u) {
            return {
                beschreibung: u.beschreibung || "",
                prioritaet: u.prioritaet || 0,
                erledigt: !!u.erledigt
            };
        });
    }

    function _icalDatumZuIso(wert) {
        const bereinigt = String(wert || "").replace(/T.*$/, "");
        if (bereinigt.length === 8) {
            return bereinigt.substring(0, 4) + "-" + bereinigt.substring(4, 6) + "-" + bereinigt.substring(6, 8);
        }
        return "";
    }

    function _isoDatumZuIcal(iso) {
        return String(iso || "").replace(/-/g, "");
    }

    function _icalPrioZuIntern(p) {
        const n = parseInt(p) || 0;
        if (n >= 1 && n <= 4) return 2;
        if (n === 5) return 1;
        return 0;
    }

    function _internPrioZuIcal(intern) {
        switch (intern) {
        case 2:
            return 1;
        case 1:
            return 5;
        default:
            return 9;
        }
    }

    function _icalEscapen(text) {
        return String(text || "")
            .replace(/\\/g, "\\\\")
            .replace(/;/g, "\\;")
            .replace(/,/g, "\\,")
            .replace(/\n/g, "\\n")
            .replace(/\r/g, "");
    }

    function _falteLinie(line) {
        if (line.length <= 75) {
            return line;
        }

        let result = line.substring(0, 75);
        let rest = line.substring(75);
        while (rest.length > 0) {
            result += "\r\n " + rest.substring(0, 74);
            rest = rest.substring(74);
        }
        return result;
    }

    function _aufgabeZuVtodo(aufgabe) {
        const jetzt = new Date();
        const ts = jetzt.toISOString().replace(/[-:.]/g, "").substring(0, 15) + "Z";
        const uid = aufgabe.uid || _generiereUuid();

        let ical = "BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//KDE Plasma ToDo//DE\r\n";
        ical += "BEGIN:VTODO\r\n";
        ical += "UID:" + uid + "\r\n";
        ical += "DTSTAMP:" + ts + "\r\n";
        ical += "LAST-MODIFIED:" + ts + "\r\n";
        ical += _falteLinie("SUMMARY:" + _icalEscapen(aufgabe.beschreibung)) + "\r\n";
        ical += "STATUS:" + (aufgabe.erledigt ? "COMPLETED" : "NEEDS-ACTION") + "\r\n";
        ical += "PERCENT-COMPLETE:" + (aufgabe.erledigt ? "100" : "0") + "\r\n";
        ical += "PRIORITY:" + _internPrioZuIcal(aufgabe.prioritaet) + "\r\n";
        if (aufgabe.faelligkeit) {
            ical += "DUE;VALUE=DATE:" + _isoDatumZuIcal(aufgabe.faelligkeit) + "\r\n";
        }
        if (aufgabe.untereintraege && aufgabe.untereintraege.length > 0) {
            ical += _falteLinie("X-KDE-SUBTASKS:" + JSON.stringify(aufgabe.untereintraege)) + "\r\n";
        }
        ical += "END:VTODO\r\nEND:VCALENDAR\r\n";
        return ical;
    }

    function _parsiereVtodo(icalText, href, etag) {
        const text = icalText
            .replace(/\r\n/g, "\n")
            .replace(/\r/g, "\n")
            .replace(/\n[ \t]/g, "");
        const zeilen = text.split("\n");

        let uid = "";
        let zusammenfassung = "";
        let prioritaet = "";
        let faelligkeit = "";
        let status = "";
        let unterJson = "";
        let inVtodo = false;

        for (let i = 0; i < zeilen.length; i++) {
            const l = zeilen[i].trim();
            if (l === "BEGIN:VTODO") {
                inVtodo = true;
                continue;
            }
            if (l === "END:VTODO") {
                break;
            }
            if (!inVtodo) {
                continue;
            }

            if (l.startsWith("UID:")) {
                uid = l.substring(4).trim();
            } else if (l.startsWith("SUMMARY:")) {
                zusammenfassung = l.substring(8)
                    .replace(/\\n/g, "\n")
                    .replace(/\\,/g, ",")
                    .replace(/\\;/g, ";")
                    .replace(/\\\\/g, "\\")
                    .trim();
            } else if (l.startsWith("PRIORITY:")) {
                prioritaet = l.substring(9).trim();
            } else if (l.startsWith("DUE;VALUE=DATE:")) {
                faelligkeit = _icalDatumZuIso(l.substring(15).trim());
            } else if (l.startsWith("DUE:")) {
                faelligkeit = _icalDatumZuIso(l.substring(4).trim());
            } else if (l.startsWith("STATUS:")) {
                status = l.substring(7).trim();
            } else if (l.startsWith("PERCENT-COMPLETE:")) {
                if ((parseInt(l.substring(17)) || 0) === 100) {
                    status = "COMPLETED";
                }
            } else if (l.startsWith("X-KDE-SUBTASKS:")) {
                unterJson = l.substring(15).trim();
            }
        }

        if (!uid || !zusammenfassung) {
            return null;
        }

        let untereintraege = [];
        if (unterJson) {
            try {
                untereintraege = JSON.parse(unterJson);
            } catch (error) {
                untereintraege = [];
            }
        }

        return {
            beschreibung: zusammenfassung,
            prioritaet: _icalPrioZuIntern(prioritaet),
            faelligkeit: faelligkeit,
            erledigt: status === "COMPLETED",
            untereintraege: untereintraege,
            uid: uid,
            etag: String(etag || "").replace(/"/g, ""),
            caldavHref: href
        };
    }

    function _xmlEntityDekodieren(text) {
        return String(text || "")
            .replace(/&amp;/g, "&")
            .replace(/&lt;/g, "<")
            .replace(/&gt;/g, ">")
            .replace(/&quot;/g, '"')
            .replace(/&#39;/g, "'");
    }

    function _parsiereMultistatus(xmlText) {
        const aufgaben = [];
        const respRegex = /<[^:>\s]*:?response[^>]*>([\s\S]*?)<\/[^:>\s]*:?response>/g;
        let match;

        while ((match = respRegex.exec(xmlText)) !== null) {
            const block = match[1];
            const hrefM = block.match(/<[^:>\s]*:?href[^>]*>\s*(.*?)\s*<\/[^:>\s]*:?href>/);
            if (!hrefM || !hrefM[1].endsWith(".ics")) {
                continue;
            }

            const href = _xmlEntityDekodieren(hrefM[1].trim());
            const etagM = block.match(/<[^:>\s]*:?getetag[^>]*>\s*"?([^"<\s]*)"?\s*<\/[^:>\s]*:?getetag>/);
            const calM = block.match(/<[^:>\s]*:?calendar-data[^>]*>([\s\S]*?)<\/[^:>\s]*:?calendar-data>/);
            if (!calM) {
                continue;
            }

            const aufgabe = _parsiereVtodo(_xmlEntityDekodieren(calM[1]), href, etagM ? etagM[1] : "");
            if (aufgabe) {
                aufgaben.push(aufgabe);
            }
        }

        return aufgaben;
    }

    function _request(method, url, body, extraHeaders, callback) {
        const request = new XMLHttpRequest();
        request.open(method, url);
        request.setRequestHeader("Authorization", _authHeader());
        request.setRequestHeader("Accept", "text/calendar, application/xml, text/xml, */*");

        if (extraHeaders) {
            const headerNamen = Object.keys(extraHeaders);
            for (let i = 0; i < headerNamen.length; i++) {
                request.setRequestHeader(headerNamen[i], extraHeaders[headerNamen[i]]);
            }
        }

        request.onreadystatechange = function() {
            if (request.readyState !== XMLHttpRequest.DONE) {
                return;
            }
            callback({
                status: request.status,
                text: request.responseText,
                etag: request.getResponseHeader("ETag") || ""
            });
        };

        request.send(body === undefined ? null : body);
    }

    function _syncLokaleAufgabe(index, lokal, konfliktUids, serverStand) {
        if (index >= lokal.length) {
            _ladeServerAufgaben(lokal, konfliktUids, serverStand);
            return;
        }

        const aufgabe = lokal[index];
        const url = _caldavUrl() + encodeURIComponent(aufgabe.uid) + ".ics";
        const headers = {
            "Content-Type": "text/calendar; charset=utf-8"
        };

        if (aufgabe.etag) {
            headers["If-Match"] = '"' + aufgabe.etag + '"';
        } else {
            headers["If-None-Match"] = "*";
        }

        _request("PUT", url, _aufgabeZuVtodo(aufgabe), headers, function(result) {
            if (result.status === 200 || result.status === 201 || result.status === 204) {
                _syncLokaleAufgabe(index + 1, lokal, konfliktUids, serverStand);
                return;
            }

            if (result.status === 412) {
                konfliktUids.push(aufgabe.uid);
                _syncLokaleAufgabe(index + 1, lokal, konfliktUids, serverStand);
                return;
            }

            _fehlschlag("Sync fehlgeschlagen (PUT " + result.status + ")");
        });
    }

    function _ladeServerAufgaben(lokal, konfliktUids, serverStand) {
        const reportXml =
            '<c:calendar-query xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">'
            + '<d:prop><d:getetag/><c:calendar-data/></d:prop>'
            + '<c:filter><c:comp-filter name="VCALENDAR"><c:comp-filter name="VTODO"/></c:comp-filter></c:filter>'
            + '</c:calendar-query>';

        _request("REPORT", _caldavUrl(), reportXml, {
            "Content-Type": "application/xml; charset=utf-8",
            "Depth": "1"
        }, function(result) {
            if (result.status < 200 || result.status > 299) {
                _fehlschlag("Sync fehlgeschlagen (REPORT " + result.status + ")");
                return;
            }

            const serverAufgaben = _parsiereMultistatus(result.text);
            const merged = _mergeServerStand(lokal, serverAufgaben);
            const konfliktAnzahl = konfliktUids.length;

            root.synchronisiertGerade = false;
            root.hatFehler = false;
            root.statusNachricht = konfliktAnzahl > 0
                ? konfliktAnzahl + " Konflikte erkannt, Server-Stand uebernommen"
                : merged.length + " Aufgaben synchronisiert";
            root.aufgabenEmpfangen(merged);
            root.synchronisationFertig(true, root.statusNachricht);
        });
    }

    function _mergeServerStand(lokal, serverAufgaben) {
        const serverNachUid = {};
        const merged = [];

        for (let i = 0; i < serverAufgaben.length; i++) {
            serverNachUid[serverAufgaben[i].uid] = serverAufgaben[i];
        }

        for (let i = 0; i < lokal.length; i++) {
            const lokalerEintrag = lokal[i];
            if (serverNachUid[lokalerEintrag.uid]) {
                merged.push(serverNachUid[lokalerEintrag.uid]);
                delete serverNachUid[lokalerEintrag.uid];
            } else {
                merged.push(lokalerEintrag);
            }
        }

        const restUids = Object.keys(serverNachUid);
        for (let i = 0; i < restUids.length; i++) {
            merged.push(serverNachUid[restUids[i]]);
        }

        return merged;
    }

    function _fehlschlag(nachricht) {
        root.synchronisiertGerade = false;
        root.hatFehler = true;
        root.statusNachricht = nachricht;
        root.synchronisationFertig(false, nachricht);
    }

    P5Support.DataSource {
        id: passwortLadenEngine
        engine: "executable"

        onNewData: function(src, data) {
            disconnectSource(src);
            removeSource(src);

            const code = data["exit code"] !== undefined ? data["exit code"] : 1;
            const pw = String(data["stdout"] || "").trim();
            if (code === 0 && pw.length > 0) {
                root._passwort = pw;
                root.passwortGeladen = true;
                root.hatFehler = false;
                root.statusNachricht = "";
                // Sync wurde angefordert während Passwort noch geladen wurde → jetzt starten
                if (root._syncNachPasswortLaden) {
                    root._syncNachPasswortLaden = false;
                    _startSync(root._syncAufgaben);
                }
            } else {
                root._passwort = "";
                root.passwortGeladen = false;
                root._syncNachPasswortLaden = false;
                root.hatFehler = true;
                root.statusNachricht = "Passwort nicht gefunden – bitte in Einstellungen eingeben";
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
                root.passwortGeladen = false;
                root.hatFehler = true;
                root.statusNachricht = "Passwort konnte nicht gespeichert werden";
            }
        }
    }
}
