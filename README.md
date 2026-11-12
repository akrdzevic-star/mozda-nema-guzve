# Možda nema gužve – Flutter aplikacija (Sarajevo)

Prototip sa pravom mapom (OpenStreetMap) i SIMULIRANIM podacima o zauzetosti.

## Šta ima
- Mapa s markerima (broj slobodnih mjesta, naziv, treperenje kad se mjesto oslobađa), mala kartica pri dodiru markera
- Pretraga, filteri (slobodno, tržni centri, javni, plaćanje, punjači, invalidi, oslobađa se, favoriti), sortiranje
- Ekran objekta: tlocrt s pojedinačnim mjestima, cijene, radno vrijeme, znamenitosti u blizini
- Navigacija (Google Maps) uz kupon "Parkiraj i uštedi" (primjer)
- Plaćanje (DEMO) s upozorenjem 15 min prije isteka (dok je aplikacija otvorena)
- Rezervacija mjesta (DEMO), prijava nepravilnog parkiranja s bodovima (DEMO), dijeljenje uličnih mjesta (DEMO)
- Zeleni vozač (procjena CO₂), kalkulator cijena, moj auto (pamti se na telefonu)
- Tamna/svijetla tema, veći tekst, osnovni engleski

## Kako dobiti .apk (bez instalacije Fluttera)
1. Na github.com napravi besplatan račun i novi repozitorij.
2. Otpremi SVE fajlove iz ovog foldera (uključujući folder `.github` i `assets`).
3. Tab **Actions** > "Build APK" > **Run workflow**.
4. Za 5–10 minuta preuzmi `mozda-nema-guzve-apk` iz završenog run-a (u njemu je app-release.apk).
5. Prebaci .apk na telefon i instaliraj (dozvoli instalaciju iz nepoznatih izvora).

## Napomene
- Podaci o zauzetosti su simulirani. Cijene i radna vremena su iz javnih izvora i mogu biti zastarjeli.
- Pozicije markera osim SCC-a su okvirne; ispravi ih u `lib/data.dart`.
- Prava obavještenja na zaključanom telefonu i fotografija pri prijavi nisu uključeni (potrebni dodatni paketi i dozvole).
