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
    property var geloeschteUids: []
    property var _reportFallbackCallback: null
    property var _propfindFallbackState: null
    property string _aktiveCaldavUrl: ""

    property string statusNachricht: ""
    property bool hatFehler: false

    readonly property bool hatSichereKonfiguration:
        _hatSichereServerUrl() &&
        _hatGueltigeKalenderKonfiguration() &&
        benutzername.trim().length > 0

    readonly property bool kannSynchronisieren:
        hatSichereKonfiguration &&
        passwortGeladen &&
        _passwort.length > 0

    signal passwortLadeFertig(bool erfolg)
    signal aufgabenEmpfangen(var aufgaben)
    signal geloeschteUidsAktualisiert(var uids)
    signal synchronisationFertig(bool erfolg, string nachricht)

    Component.onCompleted: {
        if (benutzername.trim().length > 0) {
            ladePasswort();
        }
    }

    onBenutzernameChanged: {
        _aktiveCaldavUrl = "";
        if (benutzername.trim().length > 0) {
            ladePasswort();
        }
    }

    onNextcloudUrlChanged: _aktiveCaldavUrl = "";
    onKalenderPfadChanged: _aktiveCaldavUrl = "";

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
        root.statusNachricht = "Lade Server-Stand...";

        _ladeServerStand(function(serverAufgaben) {
            const vereinigung = _vereinigeBeidseitig(lokal, serverAufgaben);
            root.statusNachricht = "Synchronisiere in beide Richtungen...";
            _loescheServerAufgaben(0, _eindeutigeUids(geloeschteUids), function(verbleibendeTombstones) {
                root.geloeschteUidsAktualisiert(verbleibendeTombstones);
                _syncLokaleAufgabe(0, vereinigung.pushAufgaben, vereinigung.konfliktUids);
            });
        });
    }

    function _eindeutigeUids(liste) {
        const seen = {};
        const out = [];
        const arr = Array.isArray(liste) ? liste : [];

        for (let i = 0; i < arr.length; i++) {
            const uid = String(arr[i] || "").trim();
            if (!uid || seen[uid]) {
                continue;
            }
            seen[uid] = true;
            out.push(uid);
        }

        return out;
    }

    function _loescheServerAufgaben(index, tombstones, callback) {
        if (index >= tombstones.length) {
            callback([]);
            return;
        }

        const uid = tombstones[index];
        const url = _caldavUrl() + encodeURIComponent(uid) + ".ics";
        _request("DELETE", url, null, {}, function(result) {
            if (result.status === 200 || result.status === 204 || result.status === 404 || result.status === 410) {
                _loescheServerAufgaben(index + 1, tombstones, callback);
                return;
            }

            // Fallback: Manche QML-XMLHttpRequest-Backends/Proxies unterstützen DELETE nicht stabil.
            if (result.status === 0 || result.status === 405 || result.status === 501) {
                _request("POST", url, "", {
                    "X-HTTP-Method-Override": "DELETE"
                }, function(fallbackResult) {
                    if (fallbackResult.status === 200 || fallbackResult.status === 204 || fallbackResult.status === 404 || fallbackResult.status === 410) {
                        _loescheServerAufgaben(index + 1, tombstones, callback);
                        return;
                    }

                    const restFallback = [uid];
                    for (let i = index + 1; i < tombstones.length; i++) {
                        restFallback.push(tombstones[i]);
                    }
                    callback(_eindeutigeUids(restFallback));
                });
                return;
            }

            // Nicht blockierend: UID als Tombstone behalten und später erneut versuchen.
            const rest = [uid];
            for (let i = index + 1; i < tombstones.length; i++) {
                rest.push(tombstones[i]);
            }
            callback(_eindeutigeUids(rest));
        });
    }

    function _pruefeKonfiguration() {
        if (!benutzername.trim()) {
            return { gueltig: false, nachricht: "Benutzername fehlt" };
        }
        if (!_hatSichereServerUrl()) {
            return { gueltig: false, nachricht: "Nur HTTPS-URLs sind erlaubt" };
        }
        if (!_hatGueltigeKalenderKonfiguration()) {
            return { gueltig: false, nachricht: "Kalenderpfad ist ungueltig" };
        }
        if (!passwortGeladen || !_passwort) {
            return { gueltig: false, nachricht: "Passwort nicht geladen" };
        }
        return { gueltig: true, nachricht: "" };
    }

    function _hatSichereServerUrl() {
        const url = String(nextcloudUrl || kalenderPfad || "").trim();
        return /^https:\/\/.+/i.test(url);
    }

    function _hatGueltigeKalenderKonfiguration() {
        return _normalisiereKalenderPfad(kalenderPfad).length > 0
            || _istHttpsUrl(kalenderPfad)
            || _istHttpsUrl(nextcloudUrl);
    }

    function _istHttpsUrl(text) {
        return /^https:\/\/.+/i.test(String(text || "").trim());
    }

    function _baseUrl() {
        const url = String(nextcloudUrl || kalenderPfad || "").trim();
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
        if (_istHttpsUrl(pfad)) {
            return "";
        }

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
        if (String(_aktiveCaldavUrl || "").length > 0) {
            return _aktiveCaldavUrl;
        }

        const direkteKalenderUrl = _direkteKalenderUrlAusWert(kalenderPfad);
        if (direkteKalenderUrl) {
            return direkteKalenderUrl;
        }

        return _standardCaldavUrl();
    }

    function _standardCaldavUrl() {
        const davRoot = _davRootUrlAusWert(nextcloudUrl) || _davRootUrlAusWert(kalenderPfad);
        const basis = davRoot ? davRoot.replace(/\/+$/, "") : (_baseUrl() + "/remote.php/dav");
        const normalisiert = _normalisiereKalenderPfad(kalenderPfad);

        if (normalisiert.length === 0) {
            return basis + "/calendars/" + encodeURIComponent(benutzername.trim()) + "/";
        }

        return basis
            + "/calendars/"
            + encodeURIComponent(benutzername.trim())
            + "/" + normalisiert + "/";
    }

    function _davRootUrlAusWert(wert) {
        const raw = String(wert || "").trim();
        if (!_istHttpsUrl(raw)) {
            return "";
        }

        const match = raw.match(/^(https:\/\/[^\s]+\/remote\.php\/dav)(?:[\/?#].*)?$/i);
        if (!match || !match[1]) {
            return "";
        }

        return match[1].replace(/\/+$/, "") + "/";
    }

    function _direkteKalenderUrlAusWert(wert) {
        const raw = String(wert || "").trim();
        if (!_istHttpsUrl(raw)) {
            return "";
        }

        const match = raw.match(/^(https:\/\/[^\s]+\/remote\.php\/dav\/calendars\/[^\s?#]+)(?:[?#].*)?$/i);
        if (!match || !match[1]) {
            return "";
        }

        return match[1].replace(/\/+$/, "") + "/";
    }

    function _direkteCaldavUrlAusNextcloudUrl() {
        return _direkteKalenderUrlAusWert(nextcloudUrl);
    }

    function _direkteCaldavUrlAusKalenderPfad() {
        return _direkteKalenderUrlAusWert(kalenderPfad);
    }

    function _kalenderSammlungsUrl() {
        const direkteKalenderUrl = _direkteKalenderUrlAusWert(kalenderPfad) || _direkteKalenderUrlAusWert(nextcloudUrl);
        if (direkteKalenderUrl) {
            const m = direkteKalenderUrl.match(/^(https:\/\/[^\s]+\/remote\.php\/dav\/calendars\/[^\/]+\/)/i);
            if (m && m[1]) {
                return m[1].replace(/\/+$/, "") + "/";
            }
        }

        const davRoot = _davRootUrlAusWert(kalenderPfad) || _davRootUrlAusWert(nextcloudUrl);
        if (davRoot) {
            return davRoot.replace(/\/+$/, "") + "/calendars/" + encodeURIComponent(benutzername.trim()) + "/";
        }

        return _baseUrl() + "/remote.php/dav/calendars/" + encodeURIComponent(benutzername.trim()) + "/";
    }

    function _caldavUrlKandidaten() {
        const seen = {};
        const out = [];

        function add(url) {
            const u = String(url || "").trim();
            if (!u) {
                return;
            }
            const key = u.replace(/\/+$/, "") + "/";
            if (seen[key]) {
                return;
            }
            seen[key] = true;
            out.push(key);
        }

        add(_aktiveCaldavUrl);
        add(_direkteCaldavUrlAusKalenderPfad());
        add(_standardCaldavUrl());
        add(_direkteCaldavUrlAusNextcloudUrl());
        return out;
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

    function _parsiereKalenderHrefs(xmlText, sammlungsUrl) {
        const hrefs = [];
        const vtodoHrefs = [];
        const seen = {};
        const respRegex = /<[^:>\s]*:?response[^>]*>([\s\S]*?)<\/[^:>\s]*:?response>/g;
        const parentUrl = String(sammlungsUrl || "").replace(/\/+$/, "") + "/";
        let match;

        while ((match = respRegex.exec(xmlText)) !== null) {
            const block = match[1];
            const hrefM = block.match(/<[^:>\s]*:?href[^>]*>\s*(.*?)\s*<\/[^:>\s]*:?href>/);
            if (!hrefM || !hrefM[1]) {
                continue;
            }

            const blockLower = block.toLowerCase();
            if (blockLower.indexOf("calendar") === -1) {
                continue;
            }

            const hrefRaw = _xmlEntityDekodieren(hrefM[1].trim());
            let url = "";
            if (/^https?:\/\//i.test(hrefRaw)) {
                url = hrefRaw;
            } else if (hrefRaw.startsWith("/")) {
                url = _baseUrl() + hrefRaw;
            }

            url = String(url || "").replace(/\/+$/, "") + "/";
            if (!/^https:\/\//i.test(url)) {
                continue;
            }
            if (url === parentUrl) {
                continue;
            }
            if (parentUrl !== "/" && url.indexOf(parentUrl) !== 0) {
                continue;
            }
            if (seen[url]) {
                continue;
            }
            seen[url] = true;
            hrefs.push(url);

            const comps = block.match(/name="VTODO"/i);
            if (comps) {
                vtodoHrefs.push(url);
            }
        }

        const out = vtodoHrefs.length > 0 ? vtodoHrefs : hrefs;
        out.sort(function(a, b) {
            return b.length - a.length;
        });
        return out;
    }

    function _entdeckeKalenderUndLadeServerStandMitCurl(reportXml, callback, letzterStatus, rootUrl) {
        const discoveryUrl = String(rootUrl || _kalenderSammlungsUrl()).trim();
        _propfindFallbackState = {
            reportXml: reportXml,
            callback: callback,
            letzterStatus: letzterStatus || 404,
            rootUrl: discoveryUrl
        };

        const body =
            '<d:propfind xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">'
            + '<d:prop><d:resourcetype/><d:displayname/></d:prop>'
            + '</d:propfind>';

        const script =
            "NC_USER=" + _sq(benutzername.trim()) + "; "
            + "PW=$(secret-tool lookup service nextcloud-todo-kde username \"$NC_USER\" 2>/dev/null); "
            + "if [ -z \"$PW\" ]; then echo __STATUS__:000; exit 0; fi; "
            + "AUTH=$(printf '%s' \"$NC_USER:$PW\" | base64 -w0); "
            + "curl -sS --request PROPFIND " + _sq(discoveryUrl) + " "
            + "-H \"Authorization: Basic $AUTH\" "
            + "-H \"Accept: application/xml, text/xml, */*\" "
            + "-H \"Content-Type: application/xml; charset=utf-8\" "
            + "-H \"Depth: 1\" "
            + "--data " + _sq(body) + " "
            + "-w '\n__STATUS__:%{http_code}'";

        propfindFallbackEngine.connectSource("sh -c " + _sq(script));
    }

    function _reportAufKandidaten(reportXml, kandidaten, callback, nachFehlschlag) {
        function versuch(index, letzterStatus) {
            if (index >= kandidaten.length) {
                if (nachFehlschlag) {
                    nachFehlschlag(letzterStatus || 404);
                    return;
                }
                _fehlschlag("Sync fehlgeschlagen (REPORT " + (letzterStatus || 404) + ")");
                return;
            }

            const zielUrl = kandidaten[index];

            _request("REPORT", zielUrl, reportXml, {
                "Content-Type": "application/xml; charset=utf-8",
                "Depth": "1"
            }, function(result) {
                if (result.status === 0 && index === 0) {
                    _ladeServerStandMitCurl(reportXml, callback, zielUrl);
                    return;
                }

                if (result.status >= 200 && result.status <= 299) {
                    _aktiveCaldavUrl = zielUrl;
                    callback(_parsiereMultistatus(result.text));
                    return;
                }

                if (result.status === 404 || result.status === 301 || result.status === 302 || result.status === 307 || result.status === 308) {
                    versuch(index + 1, result.status);
                    return;
                }

                _fehlschlag("Sync fehlgeschlagen (REPORT " + result.status + ")");
            });
        }

        versuch(0, 0);
    }

    function _entdeckeKalenderUndLadeServerStand(reportXml, callback, letzterStatus) {
        const rootUrl = _kalenderSammlungsUrl();

        const body =
            '<d:propfind xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">'
            + '<d:prop><d:resourcetype/><d:displayname/></d:prop>'
            + '</d:propfind>';

        _request("PROPFIND", rootUrl, body, {
            "Content-Type": "application/xml; charset=utf-8",
            "Depth": "1"
        }, function(result) {
            if (result.status === 0) {
                _entdeckeKalenderUndLadeServerStandMitCurl(reportXml, callback, letzterStatus, rootUrl);
                return;
            }

            if (result.status >= 200 && result.status <= 299) {
                const discovered = _parsiereKalenderHrefs(result.text, rootUrl);
                if (discovered.length === 0) {
                    _fehlschlag("Sync fehlgeschlagen (REPORT " + (letzterStatus || 404) + ")");
                    return;
                }

                _reportAufKandidaten(reportXml, discovered, callback, function(status) {
                    _fehlschlag("Sync fehlgeschlagen (REPORT " + (status || letzterStatus || 404) + ")");
                });
                return;
            }

            _fehlschlag("Sync fehlgeschlagen (REPORT " + (letzterStatus || result.status || 404) + ")");
        });
    }

    function _normalisiereAufgabeFuerVergleich(a) {
        return {
            beschreibung: String((a && a.beschreibung) || ""),
            prioritaet: parseInt((a && a.prioritaet) || 0),
            faelligkeit: String((a && a.faelligkeit) || ""),
            erledigt: !!(a && a.erledigt),
            untereintraege: _kloneUntereintraege(a && a.untereintraege ? a.untereintraege : [])
        };
    }

    function _aufgabenInhaltlichGleich(a, b) {
        return JSON.stringify(_normalisiereAufgabeFuerVergleich(a))
            === JSON.stringify(_normalisiereAufgabeFuerVergleich(b));
    }

    function _request(method, url, body, extraHeaders, callback) {
        // qmllint disable unqualified
        const request = new XMLHttpRequest();
        // qmllint enable unqualified

        const gewuenschteMethode = String(method || "GET").toUpperCase();
        let effektiveMethode = gewuenschteMethode;
        const headers = {};

        if (extraHeaders) {
            const headerNamen = Object.keys(extraHeaders);
            for (let i = 0; i < headerNamen.length; i++) {
                headers[headerNamen[i]] = extraHeaders[headerNamen[i]];
            }
        }

        try {
            request.open(effektiveMethode, url);
        } catch (error) {
            callback({
                status: 0,
                text: String(error || ""),
                etag: ""
            });
            return;
        }
        request.setRequestHeader("Authorization", _authHeader());
        request.setRequestHeader("Accept", "text/calendar, application/xml, text/xml, */*");

        {
            const headerNamen = Object.keys(headers);
            for (let i = 0; i < headerNamen.length; i++) {
                request.setRequestHeader(headerNamen[i], headers[headerNamen[i]]);
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

    function _aufgabenRessourcenUrl(aufgabe) {
        const href = String((aufgabe && aufgabe.caldavHref) || "").trim();
        if (href.length > 0 && href.endsWith(".ics")) {
            if (/^https?:\/\//i.test(href)) {
                return href;
            }
            // Server liefert i.d.R. absolute HREFs wie /remote.php/dav/...
            if (href.startsWith("/")) {
                return _baseUrl() + href;
            }
            return _caldavUrl() + href;
        }

        return _caldavUrl() + encodeURIComponent(aufgabe.uid) + ".ics";
    }

    function _syncLokaleAufgabe(index, lokal, konfliktUids) {
        if (index >= lokal.length) {
            _ladeServerAufgaben(konfliktUids);
            return;
        }

        const aufgabe = lokal[index];
        const url = _aufgabenRessourcenUrl(aufgabe);
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
                _syncLokaleAufgabe(index + 1, lokal, konfliktUids);
                return;
            }

            // Einige Server liefern bei veralteten HREFs 404.
            // Dann einmal über die kanonische UID-URL neu anlegen/aktualisieren.
            if (result.status === 404 && aufgabe.caldavHref) {
                const fallbackUrl = _caldavUrl() + encodeURIComponent(aufgabe.uid) + ".ics";
                const fallbackHeaders = {
                    "Content-Type": "text/calendar; charset=utf-8",
                    "If-None-Match": "*"
                };

                _request("PUT", fallbackUrl, _aufgabeZuVtodo(aufgabe), fallbackHeaders, function(fallbackResult) {
                    if (fallbackResult.status === 200 || fallbackResult.status === 201 || fallbackResult.status === 204) {
                        _syncLokaleAufgabe(index + 1, lokal, konfliktUids);
                        return;
                    }

                    if (fallbackResult.status === 412) {
                        konfliktUids.push(aufgabe.uid);
                        _syncLokaleAufgabe(index + 1, lokal, konfliktUids);
                        return;
                    }

                    _fehlschlag("Sync fehlgeschlagen (PUT " + fallbackResult.status + ")");
                });
                return;
            }

            if (result.status === 412) {
                konfliktUids.push(aufgabe.uid);
                _syncLokaleAufgabe(index + 1, lokal, konfliktUids);
                return;
            }

            _fehlschlag("Sync fehlgeschlagen (PUT " + result.status + ")");
        });
    }

    function _ladeServerStand(callback) {
        const reportXml =
            '<c:calendar-query xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">'
            + '<d:prop><d:getetag/><c:calendar-data/></d:prop>'
            + '<c:filter><c:comp-filter name="VCALENDAR"><c:comp-filter name="VTODO"/></c:comp-filter></c:filter>'
            + '</c:calendar-query>';

        const kandidaten = _caldavUrlKandidaten();
        _reportAufKandidaten(reportXml, kandidaten, callback, function(letzterStatus) {
            _entdeckeKalenderUndLadeServerStand(reportXml, callback, letzterStatus);
        });
    }

    function _ladeServerStandMitCurl(reportXml, callback, zielUrl) {
        _reportFallbackCallback = callback;

        const reportUrl = String(zielUrl || _caldavUrl()).trim();

        const script =
            "NC_USER=" + _sq(benutzername.trim()) + "; "
            + "PW=$(secret-tool lookup service nextcloud-todo-kde username \"$NC_USER\" 2>/dev/null); "
            + "if [ -z \"$PW\" ]; then echo __STATUS__:000; exit 0; fi; "
            + "AUTH=$(printf '%s' \"$NC_USER:$PW\" | base64 -w0); "
            + "curl -sS --request REPORT " + _sq(reportUrl) + " "
            + "-H \"Authorization: Basic $AUTH\" "
            + "-H \"Accept: text/calendar, application/xml, text/xml, */*\" "
            + "-H \"Content-Type: application/xml; charset=utf-8\" "
            + "-H \"Depth: 1\" "
            + "--data " + _sq(reportXml) + " "
            + "-w '\n__STATUS__:%{http_code}'";

        reportFallbackEngine.connectSource("sh -c " + _sq(script));
    }

    function _ladeServerAufgaben(konfliktUids) {
        _ladeServerStand(function(serverAufgaben) {
            const konfliktAnzahl = konfliktUids.length;

            root.synchronisiertGerade = false;
            root.hatFehler = false;
            root.statusNachricht = konfliktAnzahl > 0
                ? konfliktAnzahl + " Konflikte erkannt, Server-Stand uebernommen"
                : serverAufgaben.length + " Aufgaben in beide Richtungen synchronisiert";
            root.aufgabenEmpfangen(serverAufgaben);
            root.synchronisationFertig(true, root.statusNachricht);
        });
    }

    function _vereinigeBeidseitig(lokal, serverAufgaben) {
        const serverNachUid = {};
        const merged = [];
        const konfliktUids = [];
        const pushAufgaben = [];
        const geloeschteSet = {};

        for (let i = 0; i < (Array.isArray(geloeschteUids) ? geloeschteUids.length : 0); i++) {
            const uid = String(geloeschteUids[i] || "").trim();
            if (uid) {
                geloeschteSet[uid] = true;
            }
        }

        for (let i = 0; i < serverAufgaben.length; i++) {
            const s = serverAufgaben[i];
            if (s && s.uid && !geloeschteSet[s.uid]) {
                serverNachUid[s.uid] = s;
            }
        }

        for (let i = 0; i < lokal.length; i++) {
            const l = lokal[i];
            if (!l || !l.uid) {
                continue;
            }
            if (geloeschteSet[l.uid]) {
                continue;
            }

            const s = serverNachUid[l.uid];
            if (!s) {
                merged.push(l);
                pushAufgaben.push(l);
                continue;
            }

            // ETag hat sich seit letztem Stand verändert -> Serverversion bevorzugen.
            // So vermeiden wir, dass fremde/neuere Nextcloud-Änderungen überschrieben werden.
            if (l.etag && s.etag && l.etag !== s.etag) {
                merged.push(s);
                konfliktUids.push(l.uid);
            } else {
                const lokalGewinnt = !_aufgabenInhaltlichGleich(l, s);
                const kandidat = lokalGewinnt ? {
                    beschreibung: l.beschreibung,
                    prioritaet: l.prioritaet,
                    faelligkeit: l.faelligkeit,
                    erledigt: l.erledigt,
                    untereintraege: _kloneUntereintraege(l.untereintraege),
                    uid: l.uid,
                    etag: l.etag || s.etag || "",
                    caldavHref: l.caldavHref || s.caldavHref || ""
                } : s;

                merged.push(kandidat);
                if (lokalGewinnt) {
                    pushAufgaben.push(kandidat);
                }
            }

            delete serverNachUid[l.uid];
        }

        const restUids = Object.keys(serverNachUid);
        for (let i = 0; i < restUids.length; i++) {
            merged.push(serverNachUid[restUids[i]]);
        }

        return {
            aufgaben: merged,
            pushAufgaben: pushAufgaben,
            konfliktUids: konfliktUids
        };
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
                    root._startSync(root._syncAufgaben);
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

    P5Support.DataSource {
        id: reportFallbackEngine
        engine: "executable"

        onNewData: function(src, data) {
            disconnectSource(src);
            removeSource(src);

            const callback = root._reportFallbackCallback;
            root._reportFallbackCallback = null;
            if (!callback) {
                return;
            }

            const stdout = String(data["stdout"] || "");
            const match = stdout.match(/__STATUS__:(\d{3})\s*$/);
            const status = match ? parseInt(match[1]) : 0;
            const body = match ? stdout.replace(/\n?__STATUS__:\d{3}\s*$/, "") : stdout;

            if (status >= 200 && status <= 299) {
                callback(_parsiereMultistatus(body));
                return;
            }

            _fehlschlag("Sync fehlgeschlagen (REPORT " + status + ")");
        }
    }

    P5Support.DataSource {
        id: propfindFallbackEngine
        engine: "executable"

        onNewData: function(src, data) {
            disconnectSource(src);
            removeSource(src);

            const state = root._propfindFallbackState;
            root._propfindFallbackState = null;
            if (!state) {
                return;
            }

            const stdout = String(data["stdout"] || "");
            const match = stdout.match(/__STATUS__:(\d{3})\s*$/);
            const status = match ? parseInt(match[1]) : 0;
            const body = match ? stdout.replace(/\n?__STATUS__:\d{3}\s*$/, "") : stdout;

            if (status >= 200 && status <= 299) {
                const discovered = _parsiereKalenderHrefs(body, state.rootUrl);
                if (discovered.length === 0) {
                    _fehlschlag("Sync fehlgeschlagen (REPORT " + (state.letzterStatus || 404) + ")");
                    return;
                }

                _reportAufKandidaten(state.reportXml, discovered, state.callback, function(reportStatus) {
                    _fehlschlag("Sync fehlgeschlagen (REPORT " + (reportStatus || state.letzterStatus || 404) + ")");
                });
                return;
            }

            _fehlschlag("Sync fehlgeschlagen (REPORT " + (state.letzterStatus || status || 404) + ")");
        }
    }
}
