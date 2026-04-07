.pragma library

/*
 * Dieses Projekt steht unter der MIT-Lizenz.
 * Copyright (c) [Jahr] [Dein Name]
 */

function erzeugeAufgabe(beschreibung, prioritaet, faelligkeit, notiz) {
    const bereinigteBeschreibung = (beschreibung || "").trim();
    if (!bereinigteBeschreibung) {
        return null;
    }

    return {
        beschreibung: bereinigteBeschreibung,
        prioritaet: istGueltigePrioritaet(prioritaet) ? prioritaet : 0,
        faelligkeit: faelligkeit || "",
        notiz: typeof notiz === "string" ? notiz.trim() : "",
        erledigt: false
    };
}

function parseAufgaben(json) {
    if (!json) {
        return [];
    }

    try {
        const daten = JSON.parse(json);
        if (!Array.isArray(daten)) {
            return [];
        }

        return daten.map(normalisiereAufgabe).filter(function(aufgabe) {
            return aufgabe !== null;
        });
    } catch (error) {
        console.warn("Aufgaben konnten nicht geladen werden:", error);
        return [];
    }
}

function normalisiereAufgabe(eintrag) {
    if (!eintrag || typeof eintrag !== "object") {
        return null;
    }

    const beschreibung = typeof eintrag.beschreibung === "string" ? eintrag.beschreibung.trim() : "";
    if (!beschreibung) {
        return null;
    }

    return {
        beschreibung: beschreibung,
        prioritaet: istGueltigePrioritaet(eintrag.prioritaet) ? eintrag.prioritaet : 0,
        faelligkeit: typeof eintrag.faelligkeit === "string" ? eintrag.faelligkeit : "",
        notiz: typeof eintrag.notiz === "string" ? eintrag.notiz.trim() : "",
        erledigt: !!eintrag.erledigt
    };
}

function istGueltigePrioritaet(prioritaet) {
    return prioritaet === 0 || prioritaet === 1 || prioritaet === 2;
}
