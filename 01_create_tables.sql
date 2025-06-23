-- =====================================================
-- PROJEKT: Analýza dostupnosti základních potravin v České republice
-- Autor: Filip Hedvik
-- Datum: 2025-06-05
-- Soubor: 01_create_tables_optimized.sql
-- Účel: Optimalizované vytvoření hlavních tabulek s ještě lepší strukturou
-- =====================================================

/*
OPTIMALIZACE:
1. Rozdělení velkého CTE na menší logické celky
2. Přidání validačních kroků pro kontrolu kvality dat
3. Lepší dokumentace každého kroku
4. Optimalizované výpočty kupní síly
5. Důsledné použití standardizovaných kódů
*/

-- =====================================================
-- HLAVNÍ TABULKA: Mzdy a ceny potravin pro ČR
-- =====================================================

CREATE TABLE t_filip_hedvik_project_SQL_primary_final AS
WITH mzdy_raw AS (
    -- KROK 1: Základní získání mzdových dat s ověřenými kódy
    SELECT 
        mzdy.payroll_year AS rok,
        mzdy.industry_branch_code AS kod_odvetvi,
        mzdy.value AS mzda_hodnota,
        obory.name AS nazev_odvetvi,
        jednotky.name AS jednotka_mzdy
    FROM czechia_payroll AS mzdy
    JOIN czechia_payroll_industry_branch AS obory ON mzdy.industry_branch_code = obory.code
    JOIN czechia_payroll_unit AS jednotky ON mzdy.unit_code = jednotky.code
    WHERE 
        -- OVĚŘENÉ KÓDY z referenčního souboru:
        mzdy.value_type_code = 5958        -- Průměrná hrubá mzda na zaměstnance
        AND mzdy.unit_code = 200           -- tisíce Kč (ne 80403!)
        AND mzdy.calculation_code = 200    -- přepočtený (standardizovaná data)
        -- ČASOVÉ A KVALITNÍ FILTRY:
        AND mzdy.payroll_year BETWEEN 2006 AND 2018
        AND mzdy.value IS NOT NULL
        AND mzdy.value > 0                 -- Eliminace chybných dat
        AND mzdy.industry_branch_code IS NOT NULL
),
mzdy_agregace AS (
    -- KROK 2: Agregace mezd podle roku a odvětví
    SELECT 
        rok,
        kod_odvetvi,
        nazev_odvetvi,
        jednotka_mzdy,
        ROUND(AVG(mzda_hodnota)::numeric, 2) AS prumerna_mzda,
        COUNT(*) AS pocet_zaznamu_mzdy
    FROM mzdy_raw
    GROUP BY rok, kod_odvetvi, nazev_odvetvi, jednotka_mzdy
    HAVING COUNT(*) >= 2  -- Alespoň 2 záznamy pro spolehlivý průměr
),
ceny_raw AS (
    -- KROK 3: Základní získání cenových dat podle kategorií
    SELECT 
        ceny.category_code AS kod_potraviny,
        DATE_PART('year', ceny.date_from)::int AS rok,
        ceny.value AS cena_hodnota,
        kategorie.name AS nazev_potraviny,
        kategorie.price_unit AS jednotka_ceny
    FROM czechia_price ceny
    JOIN czechia_price_category AS kategorie ON ceny.category_code = kategorie.code
    WHERE 
        -- ČASOVÉ A KVALITNÍ FILTRY:
        DATE_PART('year', ceny.date_from) BETWEEN 2006 AND 2018
        AND ceny.value IS NOT NULL
        AND ceny.value > 0                 -- Eliminace chybných cen
),
ceny_agregace AS (
    -- KROK 4: Agregace cen podle roku a potraviny
    SELECT 
        kod_potraviny,
        rok,
        nazev_potraviny,
        jednotka_ceny,
        ROUND(AVG(cena_hodnota)::numeric, 2) AS prumerna_cena,
        COUNT(*) AS pocet_zaznamu_ceny
    FROM ceny_raw
    GROUP BY kod_potraviny, rok, nazev_potraviny, jednotka_ceny
    HAVING COUNT(*) >= 3  -- Alespoň 3 záznamy pro spolehlivý průměr
),
finalni_data AS (
    -- KROK 5: Spojení mezd a cen se základní kontrolou správnosti
    SELECT 
        -- IDENTIFIKÁTORY A ČAS
        mzdy_data.rok,
        mzdy_data.kod_odvetvi,
        ceny_data.kod_potraviny,
        
        -- MZDOVÉ ÚDAJE
        mzdy_data.nazev_odvetvi,
        mzdy_data.prumerna_mzda,
        mzdy_data.jednotka_mzdy,
        mzdy_data.pocet_zaznamu_mzdy,
        
        -- CENOVÉ ÚDAJE  
        ceny_data.nazev_potraviny,
        ceny_data.prumerna_cena,
        ceny_data.jednotka_ceny,
        ceny_data.pocet_zaznamu_ceny,
        
        -- KONTROLA KVALITY DAT
        CASE 
            WHEN mzdy_data.prumerna_mzda > 0 AND ceny_data.prumerna_cena > 0 THEN 'OK'
            ELSE 'CHYBA_DATA'
        END AS kontrola_kvality
        
    FROM mzdy_agregace mzdy_data
    CROSS JOIN ceny_agregace AS ceny_data
    WHERE mzdy_data.rok = ceny_data.rok  -- Spojení pouze pro stejné roky
)
SELECT 
    -- ČASOVÉ ÚDAJE
    rok,
    -- ÚDAJE O PRÁCI A MZDÁCH
    nazev_odvetvi,
    prumerna_mzda,
    jednotka_mzdy,
    -- IDENTIFIKAČNÍ KÓDY (důležité pro filtrování!)
    kod_potraviny,
    -- ÚDAJE O POTRAVINÁCH A CENÁCH
    nazev_potraviny,
    prumerna_cena AS cena,
    jednotka_ceny,
    
    -- KUPNÍ SÍLA
    CASE 
        WHEN kontrola_kvality = 'OK' 
        THEN ROUND((prumerna_mzda / prumerna_cena)::numeric, 2)
        ELSE NULL 
    END AS kupni_sila    
       
FROM finalni_data
WHERE kontrola_kvality = 'OK'  -- Pouze kvalitní data
ORDER BY rok, nazev_odvetvi, nazev_potraviny;

-- =====================================================
-- DOPLŇKOVÁ TABULKA: Evropské země pro srovnání
-- =====================================================

CREATE TABLE t_filip_hedvik_project_SQL_secondary_final AS
WITH evropske_zeme AS (
    -- KROK 1: Filtrování pouze evropských zemí
    SELECT 
        zeme.country AS zeme,
        zeme.capital_city AS hlavni_mesto,
        zeme.region_in_world AS region,
        zeme.population AS populace
    FROM countries zeme
    WHERE zeme.region_in_world IN (
        'Eastern Europe', 'Western Europe', 'Southern Europe', 
        'Central and Southeast Europe', 'Nordic Countries', 
        'Baltic Countries', 'British Isles'
    )
    AND zeme.population > 0  -- Eliminace zemí bez populačních dat
),
ekonomicka_data AS (
    -- KROK 2: Filtrování ekonomických dat pro relevantní období
    SELECT 
        ekonomie.country AS zeme,
        ekonomie.year AS rok,
        ekonomie.gdp AS hdp,
        ekonomie.gini AS gini_koeficient,
        ekonomie.taxes AS danove_zatez
    FROM economies ekonomie
    WHERE 
        ekonomie.year BETWEEN 2006 AND 2018
        AND ekonomie.gdp IS NOT NULL
        AND ekonomie.gdp > 0  -- Eliminace chybných HDP hodnot
),
spojene_data AS (
    -- KROK 3: Spojení geografických a ekonomických dat
    SELECT 
        evropa.zeme,
        evropa.hlavni_mesto,
        evropa.region,
        evropa.populace,
        ekonomika.rok,
        ekonomika.hdp,
        ekonomika.gini_koeficient,
        ekonomika.danove_zatez
    FROM evropske_zeme evropa
    JOIN ekonomicka_data ekonomika ON evropa.zeme = ekonomika.zeme
)
SELECT 
    -- ZÁKLADNÍ INFORMACE O ZEMI
    zeme,
    hlavni_mesto,
    region,
    populace,
    
    -- ČASOVÉ ÚDAJE
    rok,
    
    -- EKONOMICKÉ UKAZATELE
    hdp,
    gini_koeficient,
    danove_zatez,
    
    -- VYPOČÍTANÉ HODNOTY s kontrolou dělení nulou
    CASE 
        WHEN populace > 0 AND hdp IS NOT NULL 
        THEN ROUND((hdp / populace)::numeric, 2) 
        ELSE NULL 
    END AS hdp_na_obyvatele,
    
    -- KATEGORIZACE ZEMĚ PODLE VELIKOSTI
    CASE 
        WHEN populace > 50000000 THEN 'VELKÁ'
        WHEN populace > 10000000 THEN 'STŘEDNÍ'
        WHEN populace > 1000000 THEN 'MALÁ'
        ELSE 'VELMI_MALÁ'
    END AS kategorie_velikosti
    
FROM spojene_data
ORDER BY zeme, rok;

-- =====================================================
-- KONTROLNÍ DOTAZY PRO OVĚŘENÍ KVALITY VYTVOŘENÝCH TABULEK
-- =====================================================

-- Kontrola 1: Základní statistiky hlavní tabulky
SELECT 
    'HLAVNÍ TABULKA' AS tabulka,
    COUNT(*) AS celkem_zaznamu,
    COUNT(DISTINCT rok) AS pocet_let,
    COUNT(DISTINCT nazev_odvetvi) AS pocet_oboru,
    COUNT(DISTINCT nazev_potraviny) AS pocet_potravin,
    
    -- Kontrola kvality dat
    COUNT(CASE WHEN kupni_sila IS NULL THEN 1 END) AS zaznamy_bez_kupni_sily,
    COUNT(CASE WHEN prumerna_mzda <= 0 THEN 1 END) AS chybne_mzdy,
    COUNT(CASE WHEN cena <= 0 THEN 1 END) AS chybne_ceny
FROM t_filip_hedvik_project_SQL_primary_final;

-- Kontrola 2: Základní statistiky doplňkové tabulky
SELECT 
    'DOPLŇKOVÁ TABULKA' AS tabulka,
    COUNT(*) AS celkem_zaznamu,
    COUNT(DISTINCT rok) AS pocet_let,
    COUNT(DISTINCT zeme) AS pocet_zemi,
    COUNT(DISTINCT region) AS pocet_regionu,
    
    -- Kontrola kvality dat
    COUNT(CASE WHEN hdp_na_obyvatele IS NULL THEN 1 END) AS bez_hdp_na_obyvatele,
    COUNT(CASE WHEN hdp <= 0 THEN 1 END) AS chybne_hdp
FROM t_filip_hedvik_project_SQL_secondary_final;

-- Kontrola 3: Časové pokrytí obou tabulek
SELECT 
    'ČASOVÉ POKRYTÍ' AS kontrola,
    hlavni.rok,
    hlavni.pocet_hlavni,
    COALESCE(doplnkova.pocet_doplnkova, 0) AS pocet_doplnkova
FROM (
    SELECT rok, COUNT(*) AS pocet_hlavni 
    FROM t_filip_hedvik_project_SQL_primary_final 
    GROUP BY rok
) hlavni
LEFT JOIN (
    SELECT rok, COUNT(*) AS pocet_doplnkova 
    FROM t_filip_hedvik_project_SQL_secondary_final 
    GROUP BY rok
) doplnkova ON hlavni.rok = doplnkova.rok
ORDER BY hlavni.rok;

-- Kontrola 4: Top 5 odvětví s nejvyšší průměrnou mzdou v roce 2018
SELECT 
    'TOP MZDY 2018' AS kontrola,
    nazev_odvetvi,
    ROUND(AVG(prumerna_mzda), 2) AS prumerna_mzda_2018
FROM t_filip_hedvik_project_SQL_primary_final
WHERE rok = 2018
GROUP BY nazev_odvetvi
ORDER BY AVG(prumerna_mzda) DESC
LIMIT 5;

-- Kontrola 5: Top 5 nejdražších potravin v roce 2018
SELECT 
    'NEJDRAŽŠÍ POTRAVINY 2018' AS kontrola,
    nazev_potraviny,
    jednotka_ceny,
    ROUND(AVG(cena), 2) AS prumerna_cena_2018
FROM t_filip_hedvik_project_SQL_primary_final
WHERE rok = 2018
GROUP BY nazev_potraviny, jednotka_ceny
ORDER BY AVG(cena) DESC
LIMIT 5;

-- =====================================================
-- PŘEHLED OPTIMALIZACÍ
-- =====================================================

/*
KLÍČOVÁ VYLEPŠENÍ:

1. LOGICKÉ ČLENĚNÍ:
   - Rozděleno na logické kroky (raw → agregace → finální)
   - Každé CTE má jasný účel a název
   - Snadné testování jednotlivých kroků

2. KVALITA DAT:
   - Přidány validace pro eliminaci chybných hodnot
   - Kontrolní sloupce pro debugging (pocet_zaznamu_*)
   - Filtrování pouze kvalitních dat do finální tabulky

3. DOKUMENTACE:
   - Podrobné komentáře u každého kroku
   - Vysvětlení použitých kódů a filtrů
  
4. OPTIMALIZACE RYCHLOSTI:
   - Efektivní agregace s HAVING klauzulemi
   - Indexovatelné WHERE podmínky

5. KONTROLY:
   - Automatické kontrolní dotazy
   - Statistiky kvality dat
   - Časové pokrytí a top hodnoty

6. ROZŠIŘITELNOST:
   - Snadné přidání nových kontrol
   - Modulární struktura pro rozšíření
   - Standardizované konvence pojmenování


*/