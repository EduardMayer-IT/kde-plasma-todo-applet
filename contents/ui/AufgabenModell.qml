import QtQuick
import "../logic/AufgabenLogik.js" as AufgabenLogik

/*
 * Dieses Projekt steht unter der MIT-Lizenz.
 * Copyright (c) [Jahr] [Dein Name]
 */

ListModel {
    id: aufgabenModell

    property string tasksJson: "[]"
    property bool _laedtAusSpeicher: false

    signal persistRequested(string json)

    function aufgabeHinzufuegen(beschreibung, prioritaet, faelligkeit, notiz) {
        const neueAufgabe = AufgabenLogik.erzeugeAufgabe(beschreibung, prioritaet, faelligkeit, notiz);
        if (!neueAufgabe) {
            return;
        }

        append(neueAufgabe);
        persistiere();
    }

    function aufgabeLoeschen(index) {
        if (!istGueltigerIndex(index)) {
            return;
        }

        remove(index, 1);
        persistiere();
    }

    function erledigtSetzen(index, erledigt) {
        if (!istGueltigerIndex(index)) {
            return;
        }

        setProperty(index, "erledigt", !!erledigt);
        persistiere();
    }

    function prioritaetSetzen(index, prioritaet) {
        if (!istGueltigerIndex(index) || !AufgabenLogik.istGueltigePrioritaet(prioritaet)) {
            return;
        }

        setProperty(index, "prioritaet", prioritaet);
        persistiere();
    }

    function beschreibungSetzen(index, beschreibung) {
        if (!istGueltigerIndex(index)) {
            return;
        }

        const bereinigt = (beschreibung || "").trim();
        if (!bereinigt) {
            return;
        }

        if (get(index).beschreibung === bereinigt) {
            return;
        }

        setProperty(index, "beschreibung", bereinigt);
        persistiere();
    }

    function untereintragHinzufuegen(index, beschreibung, prioritaet, erledigt) {
        if (!istGueltigerIndex(index)) {
            return;
        }

        const bereinigt = (beschreibung || "").trim();
        if (!bereinigt) {
            return;
        }

        const liste = klonUntereintraege(index);
        liste.push({
            beschreibung: bereinigt,
            prioritaet: AufgabenLogik.istGueltigePrioritaet(prioritaet) ? prioritaet : 0,
            erledigt: !!erledigt
        });

        setzeUntereintraege(index, liste);
        persistiere();
    }

    function untereintragBeschreibungSetzen(index, unterIndex, beschreibung) {
        if (!istGueltigerUntereintragIndex(index, unterIndex)) {
            return;
        }

        const bereinigt = (beschreibung || "").trim();
        if (!bereinigt) {
            return;
        }

        const liste = klonUntereintraege(index);
        if ((liste[unterIndex].beschreibung || "") === bereinigt) {
            return;
        }

        liste[unterIndex].beschreibung = bereinigt;
        setzeUntereintraege(index, liste);
        persistiere();
    }

    function untereintragPrioritaetSetzen(index, unterIndex, prioritaet) {
        if (!istGueltigerUntereintragIndex(index, unterIndex) || !AufgabenLogik.istGueltigePrioritaet(prioritaet)) {
            return;
        }

        const liste = klonUntereintraege(index);
        liste[unterIndex].prioritaet = prioritaet;
        setzeUntereintraege(index, liste);
        persistiere();
    }

    function untereintragErledigtSetzen(index, unterIndex, erledigt) {
        if (!istGueltigerUntereintragIndex(index, unterIndex)) {
            return;
        }

        const liste = klonUntereintraege(index);
        liste[unterIndex].erledigt = !!erledigt;
        setzeUntereintraege(index, liste);
        persistiere();
    }

    function eintragAlsUnterzeileVerschieben(quellIndex, zielIndex) {
        if (!istGueltigerIndex(quellIndex)) {
            return;
        }
        if (!istGueltigerIndex(zielIndex)) {
            return;
        }
        if (quellIndex === zielIndex) {
            return;
        }

        const quelle = get(quellIndex);
        const quellBeschreibung = (quelle.beschreibung || "").trim();
        if (!quellBeschreibung) {
            return;
        }

        const zielUntereintraege = klonUntereintraege(zielIndex);
        const anzahlVorher = zielUntereintraege.length;
        zielUntereintraege.push({
            beschreibung: quellBeschreibung,
            prioritaet: AufgabenLogik.istGueltigePrioritaet(quelle.prioritaet) ? quelle.prioritaet : 0,
            erledigt: !!quelle.erledigt
        });

        const quellenUnter = normalisiereListe(quelle.untereintraege);
        for (let i = 0; i < quellenUnter.length; ++i) {
            const unter = quellenUnter[i];
            const text = (unter && unter.beschreibung ? unter.beschreibung : "").trim();
            if (!text) {
                continue;
            }

            zielUntereintraege.push({
                beschreibung: text,
                prioritaet: AufgabenLogik.istGueltigePrioritaet(unter.prioritaet) ? unter.prioritaet : 0,
                erledigt: !!unter.erledigt
            });
        }

        setzeUntereintraege(zielIndex, zielUntereintraege);

        const zielNachher = klonUntereintraege(zielIndex);
        if (zielNachher.length <= anzahlVorher) {
            return;
        }

        remove(quellIndex, 1);
        persistiere();
    }

    function untereintragZuHaupteintrag(index, unterIndex) {
        if (!istGueltigerUntereintragIndex(index, unterIndex)) {
            return;
        }

        const liste = klonUntereintraege(index);
        const unter = liste[unterIndex] || {};
        const beschreibung = (unter.beschreibung || "").trim();
        if (!beschreibung) {
            return;
        }

        liste.splice(unterIndex, 1);
        setzeUntereintraege(index, liste);

        const neuerEintrag = erzeugeListeneintrag(
            beschreibung,
            unter.prioritaet,
            "",
            [],
            unter.erledigt
        );

        insert(index + 1, neuerEintrag);
        persistiere();
    }

    function verschieben(von, nach, persistieren) {
        if (!istGueltigerIndex(von) || !istGueltigerIndex(nach) || von === nach) {
            return;
        }

        move(von, nach, 1);
        if (persistieren !== false) {
            persistiere();
        }
    }

    function aktualisiereFaelligkeit(index, faelligkeit) {
        if (!istGueltigerIndex(index)) {
            return;
        }

        setProperty(index, "faelligkeit", faelligkeit || "");
        persistiere();
    }

    function _kopiereAlsArray() {
        const arr = [];
        for (let i = 0; i < count; ++i) {
            const e = get(i);
            arr.push(erzeugeListeneintrag(
                e.beschreibung, e.prioritaet, e.faelligkeit,
                klonUntereintraege(i), e.erledigt
            ));
        }
        return arr;
    }

    function sortierenNachPrioritaet() {
        const arr = _kopiereAlsArray();
        arr.sort(function(a, b) { return b.prioritaet - a.prioritaet; });
        _laedtAusSpeicher = true;
        clear();
        for (let i = 0; i < arr.length; ++i) append(arr[i]);
        _laedtAusSpeicher = false;
        persistiere();
    }

    function sortierenNachDatum() {
        const arr = _kopiereAlsArray();
        arr.sort(function(a, b) {
            const da = a.faelligkeit ? new Date(a.faelligkeit).getTime() : Infinity;
            const db = b.faelligkeit ? new Date(b.faelligkeit).getTime() : Infinity;
            return da - db;
        });
        _laedtAusSpeicher = true;
        clear();
        for (let i = 0; i < arr.length; ++i) append(arr[i]);
        _laedtAusSpeicher = false;
        persistiere();
    }

    function alsArray() {
        const aufgaben = [];

        for (let i = 0; i < count; ++i) {
            aufgaben.push(get(i));
        }

        return aufgaben;
    }

    function exportAlsText() {
        const zeilen = [];

        function prioritaetText(prio) {
            switch (prio) {
            case 2:
                return "Hoch";
            case 1:
                return "Mittel";
            default:
                return "Niedrig";
            }
        }

        for (let i = 0; i < count; ++i) {
            const eintrag = get(i);
            const erledigtMarker = eintrag.erledigt ? "[x]" : "[ ]";
            zeilen.push(erledigtMarker + " " + (eintrag.beschreibung || ""));

            const meta = ["Prioritaet: " + prioritaetText(eintrag.prioritaet)];
            if (eintrag.faelligkeit) {
                meta.push("Faelligkeit: " + eintrag.faelligkeit);
            }
            zeilen.push("  " + meta.join(" | "));

            const untereintraege = normalisiereListe(eintrag.untereintraege);
            for (let j = 0; j < untereintraege.length; ++j) {
                const unter = untereintraege[j] || {};
                const unterMarker = unter.erledigt ? "[x]" : "[ ]";
                zeilen.push("  - " + unterMarker + " " + (unter.beschreibung || ""));
            }

            zeilen.push("");
        }

        return zeilen.join("\n").trim() + "\n";
    }

    function persistiere() {
        if (_laedtAusSpeicher) {
            return;
        }

        const json = JSON.stringify(alsArray());
        persistRequested(json);
    }

    function ausJsonLaden(json) {
        const daten = AufgabenLogik.parseAufgaben(json);
        _laedtAusSpeicher = true;
        clear();

        for (let i = 0; i < daten.length; ++i) {
            append(daten[i]);
        }

        _laedtAusSpeicher = false;
    }

    function istGueltigerIndex(index) {
        return index >= 0 && index < count;
    }

    function klonUntereintraege(index) {
        const quelle = normalisiereListe(get(index).untereintraege);

        const kopie = [];
        for (let i = 0; i < quelle.length; ++i) {
            const eintrag = quelle[i] || {};
            kopie.push({
                beschreibung: (eintrag.beschreibung || "").trim(),
                prioritaet: AufgabenLogik.istGueltigePrioritaet(eintrag.prioritaet) ? eintrag.prioritaet : 0,
                erledigt: !!eintrag.erledigt
            });
        }

        return kopie;
    }

    function setzeUntereintraege(index, liste) {
        if (!istGueltigerIndex(index)) {
            return;
        }

        const eintrag = get(index);
        set(index, erzeugeListeneintrag(
            eintrag.beschreibung,
            eintrag.prioritaet,
            eintrag.faelligkeit,
            liste,
            eintrag.erledigt
        ));
    }

    function istGueltigerUntereintragIndex(index, unterIndex) {
        if (!istGueltigerIndex(index) || unterIndex < 0) {
            return false;
        }

        const liste = normalisiereListe(get(index).untereintraege);
        return unterIndex < liste.length;
    }

    function normalisiereListe(wert) {
        if (Array.isArray(wert)) {
            return wert;
        }

        const liste = [];

        if (wert && typeof wert.length === "number") {
            for (let i = 0; i < wert.length; ++i) {
                liste.push(wert[i]);
            }
            return liste;
        }

        if (wert && typeof wert.count === "number" && typeof wert.get === "function") {
            for (let i = 0; i < wert.count; ++i) {
                liste.push(wert.get(i));
            }
            return liste;
        }

        return [];
    }

    function erzeugeListeneintrag(beschreibung, prioritaet, faelligkeit, untereintraege, erledigt) {
        return {
            beschreibung: (beschreibung || "").trim(),
            prioritaet: AufgabenLogik.istGueltigePrioritaet(prioritaet) ? prioritaet : 0,
            faelligkeit: typeof faelligkeit === "string" ? faelligkeit : "",
            untereintraege: Array.isArray(untereintraege) ? untereintraege : normalisiereListe(untereintraege),
            erledigt: !!erledigt
        };
    }

    Component.onCompleted: ausJsonLaden(tasksJson)
    onTasksJsonChanged: ausJsonLaden(tasksJson)
}
