-- =====================================================
-- PROJEKT: Analýza dostupnosti základních potravin v České republice
-- Autor: Filip Hedvik
-- Soubor: 02_analytical_queries_with_create_tables.sql
-- Účel: Analytické dotazy pro zodpovězení výzkumných otázek s vytvořením výsledkových tabulek
-- AKTUALIZACE: Přidáno slovní hodnocení trendu do všech výsledkových tabulek
-- =====================================================

/*
NÁVOD K POUŽITÍ:
Tento soubor obsahuje SQL dotazy pro zodpovězení 5 výzkumných otázek.
Všechny dotazy používají POUZE vytvořené finální tabulky!
VÝSTUP: Vytvoří se výsledkové tabulky pro každou otázku

POUŽÍVANÉ TABULKY:
- t_filip_hedvik_project_SQL_primary_final (mzdy, ceny, kupní síla podle oborů a potravin)
- t_filip_hedvik_project_SQL_secondary_final (HDP, GINI, populace evropských zemí)

VYTVOŘENÉ VÝSLEDKOVÉ TABULKY:
- t_vysledky_otazka1_vyvoj_mezd
- t_vysledky_otazka2_kupni_sila
- t_vysledky_otazka3_zdrazovani_potravin
- t_vysledky_otazka4_rozdil_ceny_mzdy
- t_vysledky_otazka5_vliv_hdp
- t_vysledky_otazka5_souhrn_korelaci

STRUKTURA PRIMÁRNÍ TABULKY:
- rok, nazev_odvetvi, prumerna_mzda, jednotka_mzdy, kod_potraviny, nazev_potraviny, cena, jednotka_ceny, kupni_sila

STRUKTURA SEKUNDÁRNÍ TABULKY:  
- zeme, rok, hdp, gini_koeficient, populace, hdp_na_obyvatele

KLÍČOVÉ KÓDY POTRAVIN PRO ANALÝZY:
- 114201 = "Mléko polotučné pasterované" 
- 111301 = "Chléb konzumní kmínový"
Používáme kod_potraviny pro přesnou identifikaci potravin

METODIKA VÝPOČTŮ:
- Meziroční změny: ((nová_hodnota - stará_hodnota) / stará_hodnota) * 100
- Používáme Window funkce LAG() pro porovnání s předchozím rokem
- Agregace AVG() pro vyhlazení výkyvů mezi obory/potravinami
*/

-- =====================================================
-- VÝZKUMNÁ OTÁZKA 1: Rostou mzdy ve všech oborech?
-- =====================================================

/*
OTÁZKA 1: Rostou v průběhu let mzdy ve všech odvětvích, nebo v některých klesají?
*/

-- Vývoj mezd podle oborů (2006 vs 2018)
CREATE TABLE t_vysledky_otazka1_vyvoj_mezd AS
WITH mzdy_podle_oboru AS (
    -- KROK 1: Získáme průměrné mzdy pro každý obor v letech 2006 a 2018
    SELECT 
        p.rok,
        p.nazev_odvetvi,
        AVG(p.prumerna_mzda) AS prumerna_mzda_rok  -- Průměr přes všechny potraviny pro daný obor/rok
    FROM t_filip_hedvik_project_SQL_primary_final p
    WHERE 
        p.rok IN (2006, 2018)  -- Jen první a poslední rok pro srovnání
        AND p.prumerna_mzda IS NOT NULL AND p.prumerna_mzda > 0  -- Filtrujeme chybné hodnoty
        AND p.nazev_odvetvi IS NOT NULL   -- Jen platné obory
    GROUP BY p.rok, p.nazev_odvetvi
)
SELECT 
    nazev_odvetvi AS obor_prace,
    
    -- KROK 2: Převedeme řádky na sloupce pomocí CASE WHEN pro srovnání let
    /* MAX() nám pomáhá "vybrat" jedinou nenulovou hodnotu z každé skupiny při pivot operaci. 
    		Je to elegantní způsob, jak převést řádky na sloupce*/
    
    ROUND(MAX(CASE WHEN rok = 2006 THEN prumerna_mzda_rok END)::numeric, 0) AS mzda_2006_kc,
    ROUND(MAX(CASE WHEN rok = 2018 THEN prumerna_mzda_rok END)::numeric, 0) AS mzda_2018_kc,
    
    -- KROK 3: Vypočítáme absolutní změnu (v Kč)
    ROUND((MAX(CASE WHEN rok = 2018 THEN prumerna_mzda_rok END) - 
           MAX(CASE WHEN rok = 2006 THEN prumerna_mzda_rok END))::numeric, 0) AS zmena_kc,
    
    -- KROK 4: Vypočítáme procentní změnu: ((nová_hodnota - stará_hodnota) / stará_hodnota) * 100
    ROUND(
        ((MAX(CASE WHEN rok = 2018 THEN prumerna_mzda_rok END) - 
          MAX(CASE WHEN rok = 2006 THEN prumerna_mzda_rok END)) * 100.0 / 
         MAX(CASE WHEN rok = 2006 THEN prumerna_mzda_rok END))::numeric, 2
    ) AS zmena_v_procentech,
    
    -- NOVÉ: KROK 5: Slovní hodnocení trendu růstu mezd
    CASE 
        WHEN ((MAX(CASE WHEN rok = 2018 THEN prumerna_mzda_rok END) - 
               MAX(CASE WHEN rok = 2006 THEN prumerna_mzda_rok END)) * 100.0 / 
              MAX(CASE WHEN rok = 2006 THEN prumerna_mzda_rok END)) >= 80 
        THEN 'výrazný růst'
        
        WHEN ((MAX(CASE WHEN rok = 2018 THEN prumerna_mzda_rok END) - 
               MAX(CASE WHEN rok = 2006 THEN prumerna_mzda_rok END)) * 100.0 / 
              MAX(CASE WHEN rok = 2006 THEN prumerna_mzda_rok END)) >= 50 
        THEN 'silný růst'
        
        WHEN ((MAX(CASE WHEN rok = 2018 THEN prumerna_mzda_rok END) - 
               MAX(CASE WHEN rok = 2006 THEN prumerna_mzda_rok END)) * 100.0 / 
              MAX(CASE WHEN rok = 2006 THEN prumerna_mzda_rok END)) >= 20 
        THEN 'mírný růst'
        
        WHEN ((MAX(CASE WHEN rok = 2018 THEN prumerna_mzda_rok END) - 
               MAX(CASE WHEN rok = 2006 THEN prumerna_mzda_rok END)) * 100.0 / 
              MAX(CASE WHEN rok = 2006 THEN prumerna_mzda_rok END)) >= 0 
        THEN 'stagnace'
        
        ELSE 'pokles'
    END AS hodnoceni_trendu
    
FROM mzdy_podle_oboru
GROUP BY nazev_odvetvi  -- Seskupujeme podle oborů
HAVING 
    -- KROK 6: Zahrnujeme pouze obory, které mají data v obou letech
    MAX(CASE WHEN rok = 2006 THEN prumerna_mzda_rok END) IS NOT NULL AND
    MAX(CASE WHEN rok = 2018 THEN prumerna_mzda_rok END) IS NOT NULL
ORDER BY zmena_v_procentech DESC;  -- Seřadíme od největšího růstu k nejmenšímu

-- =====================================================
-- VÝZKUMNÁ OTÁZKA 2: Kupní síla mléka a chleba  
-- =====================================================

/*
OTÁZKA 2: Kolik je možné si koupit litrů mléka a kilogramů chleba 
za první a poslední srovnatelné období?
*/

-- Porovnání změny kupní síly 2006 vs 2018
CREATE TABLE t_vysledky_otazka2_kupni_sila AS
WITH kupni_sila_podle_roku AS (
    -- KROK 1: Získáme kupní sílu konkrétních potravin podle kódů z číselníků
    -- 114201 = Mléko polotučné pasterované, 111301 = Chléb konzumní kmínový
    SELECT 
        p.kod_potraviny,
        p.nazev_potraviny,
        p.rok,
        AVG(p.kupni_sila) AS kupni_sila  -- Průměr kupní síly přes všechny obory
    FROM t_filip_hedvik_project_SQL_primary_final AS p
    WHERE 
        -- Používáme přesné kódy potravin z číselníků
        p.kod_potraviny IN (114201, 111301)  -- Mléko a chléb podle kódů
        AND p.rok IN (2006, 2018)
        AND p.kupni_sila IS NOT NULL AND p.kupni_sila > 0
    GROUP BY p.kod_potraviny, p.nazev_potraviny, p.rok
),
kupni_sila_srovnani AS (
    -- KROK 2: Převedeme data z řádků na sloupce pro srovnání let
    SELECT 
        kod_potraviny,
        nazev_potraviny,
        AVG(CASE WHEN rok = 2006 THEN kupni_sila END) AS kupni_sila_2006,  -- Jen rok 2006
        AVG(CASE WHEN rok = 2018 THEN kupni_sila END) AS kupni_sila_2018   -- Jen rok 2018
    FROM kupni_sila_podle_roku
    GROUP BY kod_potraviny, nazev_potraviny
)
SELECT 
    kod_potraviny,
    nazev_potraviny AS potravina,
    ROUND(kupni_sila_2006::numeric, 2) AS kupni_sila_2006,
    ROUND(kupni_sila_2018::numeric, 2) AS kupni_sila_2018,
    
    -- KROK 3: Vypočítáme absolutní změnu kupní síly
    ROUND((kupni_sila_2018 - kupni_sila_2006)::numeric, 2) AS zmena_kupni_sily,
    
    -- KROK 4: Vypočítáme procentní změnu kupní síly
    -- Kladné číslo = zlepšení (více si koupíme), záporné = zhoršení
    ROUND(((kupni_sila_2018 - kupni_sila_2006) * 100.0 / kupni_sila_2006)::numeric, 2) AS zmena_v_procentech,
    
    -- NOVÉ: KROK 5: Slovní hodnocení změny kupní síly
    CASE 
        WHEN ((kupni_sila_2018 - kupni_sila_2006) * 100.0 / kupni_sila_2006) >= 30 
        THEN 'výrazné zlepšení'
        
        WHEN ((kupni_sila_2018 - kupni_sila_2006) * 100.0 / kupni_sila_2006) >= 10 
        THEN 'zlepšení'
        
        WHEN ((kupni_sila_2018 - kupni_sila_2006) * 100.0 / kupni_sila_2006) >= -5 
        THEN 'stabilní'
        
        WHEN ((kupni_sila_2018 - kupni_sila_2006) * 100.0 / kupni_sila_2006) >= -15 
        THEN 'mírné zhoršení'
        
        ELSE 'výrazné zhoršení'
    END AS hodnoceni_trendu
    
FROM kupni_sila_srovnani
WHERE kupni_sila_2006 IS NOT NULL AND kupni_sila_2018 IS NOT NULL  -- Jen kompletní data
ORDER BY kod_potraviny;

-- =====================================================
-- VÝZKUMNÁ OTÁZKA 3: Nejpomaleji zdražující potraviny
-- =====================================================

/*
OTÁZKA 3: Která kategorie potravin zdražuje nejpomaleji?
*/

CREATE TABLE t_vysledky_otazka3_zdrazovani_potravin AS
WITH cenove_zmeny_podle_potraviny AS (
    -- KROK 1: Získáme průměrné roční ceny VŠECH potravin z primární tabulky
    -- Analyzujeme celé období 2006-2018 pro výpočet meziročních změn
    SELECT 
        p.kod_potraviny,
        p.nazev_potraviny,
        p.rok,
        AVG(p.cena) AS prumerna_cena_rok  -- Průměr přes všechny obory pro danou potravinu/rok
    FROM t_filip_hedvik_project_SQL_primary_final p
    WHERE 
        p.cena IS NOT NULL AND p.cena > 0
        AND p.rok BETWEEN 2006 AND 2018  -- Celé období
    GROUP BY p.kod_potraviny, p.nazev_potraviny, p.rok
),
mezirocni_rust_podle_potraviny AS (
    -- KROK 2: Připojíme k každému roku cenu z předchozího roku pomocí LAG()
    -- LAG() je window funkce, která vrací hodnotu z předchozího řádku
    SELECT 
        kod_potraviny,
        nazev_potraviny,
        rok,
        prumerna_cena_rok,
        -- LAG() vrací cenu z předchozího roku pro stejnou potravinu (podle kod_potraviny)
        -- PARTITION BY = rozdělíme podle kódu potraviny, ORDER BY = seřadíme podle roku
        LAG(prumerna_cena_rok) OVER (PARTITION BY kod_potraviny ORDER BY rok) AS cena_predchozi_rok
    FROM cenove_zmeny_podle_potraviny
),
percentni_zmeny AS (
    -- KROK 3: Vypočítáme meziroční procentní změny
    -- Vzorec: ((nová_cena - stará_cena) / stará_cena) * 100
    SELECT 
        kod_potraviny,
        nazev_potraviny,
        rok,
        prumerna_cena_rok,
        cena_predchozi_rok,
        CASE 
            WHEN cena_predchozi_rok > 0 AND cena_predchozi_rok IS NOT NULL
            THEN ROUND(
                ((prumerna_cena_rok - cena_predchozi_rok) * 100.0 / cena_predchozi_rok)::numeric, 2
            )
            ELSE NULL   -- Pokud nemáme předchozí rok, nemůžeme spočítat změnu
        END AS mezirocni_zmena_procent
    FROM mezirocni_rust_podle_potraviny
    WHERE cena_predchozi_rok IS NOT NULL  -- Vyfiltrujeme první rok (nemá předchozí)
)
SELECT 
    kod_potraviny,
    nazev_potraviny AS potravina,
    
    -- KROK 4: Agregujeme meziroční změny pro každou potravinu
    COUNT(mezirocni_zmena_procent) AS pocet_let_s_daty,  -- Kolik let dat máme
    
    -- Průměrný meziroční růst = klíčová metrika pro "nejpomalejší zdražování"
    ROUND(AVG(mezirocni_zmena_procent)::numeric, 2) AS prumerny_mezirocni_rust_v_procentech,
    
    -- Nejmenší a největší meziroční změna = rozsah výkyvů
    ROUND(MIN(mezirocni_zmena_procent)::numeric, 2) AS nejmensi_mezirocni_zmena,
    ROUND(MAX(mezirocni_zmena_procent)::numeric, 2) AS nejvetsi_mezirocni_zmena,
    
 /*
  	 Nestabilita cen = směrodatná odchylka meziročních změn
	Ukazuje jak "divoce" se cena potraviny mění mezi roky
    PŘÍKLAD: Nestabilita 3% = cena se většinou mění ±3% kolem trendu
         	Nestabilita 15% = cena může "skočit" ±15% v kterémkoli roce
         	*/
    ROUND(STDDEV(mezirocni_zmena_procent)::numeric, 2) AS nestabilita_cen,
    
    -- NOVÉ: KROK 5: Slovní hodnocení tempa zdražování
    CASE 
        WHEN AVG(mezirocni_zmena_procent) <= 0 
        THEN 'zlevňování'
        
        WHEN AVG(mezirocni_zmena_procent) <= 2 
        THEN 'velmi pomalé zdražování'
        
        WHEN AVG(mezirocni_zmena_procent) <= 5 
        THEN 'pomalé zdražování'
        
        WHEN AVG(mezirocni_zmena_procent) <= 8 
        THEN 'střední zdražování'
        
        WHEN AVG(mezirocni_zmena_procent) <= 12 
        THEN 'rychlé zdražování'
        
        ELSE 'velmi rychlé zdražování'
    END AS hodnoceni_trendu
    
FROM percentni_zmeny
WHERE mezirocni_zmena_procent IS NOT NULL
GROUP BY kod_potraviny, nazev_potraviny
HAVING COUNT(mezirocni_zmena_procent) >= 5  -- Jen potraviny s alespoň 5 lety dat pro spolehlivost
ORDER BY prumerny_mezirocni_rust_v_procentech ASC;  -- Od nejpomalejšího zdražování

-- =====================================================
-- VÝZKUMNÁ OTÁZKA 4: Roky s výrazným nárůstem cen vs mezd
-- =====================================================

/*
OTÁZKA 4: Existuje rok s meziročním nárůstem cen potravin 
výrazně vyšším než růst mezd (větší než 10 %)?
*/

CREATE TABLE t_vysledky_otazka4_rozdil_ceny_mzdy AS
WITH rocni_agregace AS (
    -- KROK 1: Agregujeme data z primární tabulky podle roku
    -- Získáme celkové průměry cen a mezd pro každý rok
    SELECT 
        p.rok,
        AVG(p.cena) AS prumerna_cena_potravin,        -- Průměr cen všech potravin
        AVG(p.prumerna_mzda) AS prumerna_mzda_celkem  -- Průměr mezd všech oborů
    FROM t_filip_hedvik_project_SQL_primary_final p
    WHERE 
        p.cena IS NOT NULL AND p.cena > 0
        AND p.prumerna_mzda IS NOT NULL AND p.prumerna_mzda > 0
        AND p.rok BETWEEN 2006 AND 2018
    GROUP BY p.rok
),
mezirocni_zmeny AS (
    -- KROK 2: Připojíme hodnoty z předchozího roku pomocí LAG()
    -- Potřebujeme to pro výpočet meziročních změn
    SELECT 
        rok,
        prumerna_cena_potravin,
        prumerna_mzda_celkem,
        LAG(prumerna_cena_potravin) OVER (ORDER BY rok) AS cena_predchozi,  -- Cena z min. roku
        LAG(prumerna_mzda_celkem) OVER (ORDER BY rok) AS mzda_predchozi     -- Mzda z min. roku
    FROM rocni_agregace
)
SELECT 
    rok,
    ROUND(prumerna_cena_potravin::numeric, 2) AS prumerna_cena,
    ROUND(prumerna_mzda_celkem::numeric, 2) AS prumerna_mzda_tisic_kc,
    
    -- KROK 3: Vypočítáme meziroční růst cen v procentech
    CASE 
        WHEN cena_predchozi > 0 
        THEN ROUND(((prumerna_cena_potravin - cena_predchozi) * 100.0 / cena_predchozi)::numeric, 2)
        ELSE NULL 
    END AS rust_cen_v_procentech,
    
    -- KROK 4: Vypočítáme meziroční růst mezd v procentech
    CASE 
        WHEN mzda_predchozi > 0 
        THEN ROUND(((prumerna_mzda_celkem - mzda_predchozi) * 100.0 / mzda_predchozi)::numeric, 2)
        ELSE NULL 
    END AS rust_mezd_v_procentech,
    
    -- KROK 5: Klíčová metrika - rozdíl mezi růstem cen a mezd
    -- Pokud je kladný = ceny rostou rychleji než mzdy (špatné pro spotřebitele)
    -- Pokud je záporný = mzdy rostou rychleji než ceny (dobré pro spotřebitele)
    -- Hranice 10% = výrazný problém pro životní úroveň
    CASE 
        WHEN cena_predchozi > 0 AND mzda_predchozi > 0
        THEN ROUND(
            (((prumerna_cena_potravin - cena_predchozi) * 100.0 / cena_predchozi) -
             ((prumerna_mzda_celkem - mzda_predchozi) * 100.0 / mzda_predchozi))::numeric, 2
        )
        ELSE NULL 
    END AS rozdil_rustu_cen_a_mezd,
    
    -- NOVÉ: KROK 6: Slovní hodnocení dopadu na životní úroveň
    CASE 
        WHEN (((prumerna_cena_potravin - cena_predchozi) * 100.0 / cena_predchozi) -
              ((prumerna_mzda_celkem - mzda_predchozi) * 100.0 / mzda_predchozi)) >= 10 
        THEN 'výrazné zhoršení životní úrovně'
        
        WHEN (((prumerna_cena_potravin - cena_predchozi) * 100.0 / cena_predchozi) -
              ((prumerna_mzda_celkem - mzda_predchozi) * 100.0 / mzda_predchozi)) >= 5 
        THEN 'zhoršení životní úrovně'
        
        WHEN (((prumerna_cena_potravin - cena_predchozi) * 100.0 / cena_predchozi) -
              ((prumerna_mzda_celkem - mzda_predchozi) * 100.0 / mzda_predchozi)) >= -2 
        THEN 'stabilní životní úroveň'
        
        WHEN (((prumerna_cena_potravin - cena_predchozi) * 100.0 / cena_predchozi) -
              ((prumerna_mzda_celkem - mzda_predchozi) * 100.0 / mzda_predchozi)) >= -8 
        THEN 'mírné zlepšení životní úrovně'
        
        ELSE 'výrazné zlepšení životní úrovně'
    END AS hodnoceni_trendu
    
FROM mezirocni_zmeny
WHERE cena_predchozi IS NOT NULL AND mzda_predchozi IS NOT NULL  -- Jen roky s kompletními daty
ORDER BY rok;

-- =====================================================
-- VÝZKUMNÁ OTÁZKA 5: Vliv HDP na mzdy a ceny
-- =====================================================

/*
OTÁZKA 5: Má výška HDP vliv na změny ve mzdách a cenách potravin?
*/

CREATE TABLE t_vysledky_otazka5_vliv_hdp AS
WITH hdp_cr AS (
    -- KROK 1: Získáme HDP České republiky ze sekundární tabulky
    -- LAG() přidáváme pro výpočet růstu HDP meziroční
    SELECT 
        s.rok,
        s.hdp AS hdp_cr,  -- HDP v miliardách USD
        LAG(s.hdp) OVER (ORDER BY s.rok) AS hdp_predchozi_rok  -- HDP z předchozího roku
    FROM t_filip_hedvik_project_SQL_secondary_final s
    WHERE s.zeme = 'Czech Republic'  -- Jen ČR, ne ostatní evropské země
),
ekonomicke_agregace AS (
    -- KROK 2: Agregujeme ekonomické ukazatele z primární tabulky podle roku
    SELECT 
        p.rok,
        AVG(p.cena) AS prumerna_cena_potravin,        -- Průměr cen všech potravin
        AVG(p.prumerna_mzda) AS prumerna_mzda_celkem  -- Průměr mezd všech oborů
    FROM t_filip_hedvik_project_SQL_primary_final p
    WHERE 
        p.cena IS NOT NULL AND p.cena > 0
        AND p.prumerna_mzda IS NOT NULL AND p.prumerna_mzda > 0
        AND p.rok BETWEEN 2006 AND 2018
    GROUP BY p.rok
),
kompletni_data AS (
    -- KROK 3: Spojíme HDP data s ekonomickými ukazateli podle roku
    SELECT 
        e.rok,
        e.prumerna_cena_potravin,
        e.prumerna_mzda_celkem,
        h.hdp_cr,
        h.hdp_predchozi_rok
    FROM ekonomicke_agregace e
    JOIN hdp_cr h ON e.rok = h.rok  -- Jednoduchý JOIN
)
SELECT 
    rok,
    ROUND(hdp_cr::numeric, 0) AS hdp_mld_usd,
    ROUND(prumerna_mzda_celkem::numeric, 2) AS prumerna_mzda_tisic_kc,
    ROUND(prumerna_cena_potravin::numeric, 2) AS prumerna_cena,
    
    -- KROK 4: Vypočítáme meziroční růst HDP
    CASE 
        WHEN hdp_predchozi_rok > 0 
        THEN ROUND(((hdp_cr - hdp_predchozi_rok) * 100.0 / hdp_predchozi_rok)::numeric, 2)
        ELSE NULL 
    END AS rust_hdp_v_procentech,
    
    -- KROK 5: Vypočítáme meziroční růst mezd (pomocí LAG)
    ROUND(
        ((prumerna_mzda_celkem - LAG(prumerna_mzda_celkem) OVER (ORDER BY rok)) * 100.0 / 
        LAG(prumerna_mzda_celkem) OVER (ORDER BY rok))::numeric, 2
    ) AS rust_mezd_v_procentech,
    
    -- KROK 6: Vypočítáme meziroční růst cen (pomocí LAG)
    ROUND(
        ((prumerna_cena_potravin - LAG(prumerna_cena_potravin) OVER (ORDER BY rok)) * 100.0 / 
        LAG(prumerna_cena_potravin) OVER (ORDER BY rok))::numeric, 2
    ) AS rust_cen_v_procentech
    
    -- INTERPRETACE: Budeme hledat vzorce typu:
    -- - Roste-li HDP rychle, rostou i mzdy rychle? (pozitivní korelace)
    -- - Roste-li HDP rychle, rostou i ceny rychle? (možná inflace)
    -- - Je tam časový posun? (HDP v roce X ovlivní mzdy/ceny v roce X+1?)
    
FROM kompletni_data
ORDER BY rok;

-- Souhrnná analýza vztahů mezi HDP a ekonomickými ukazateli
CREATE TABLE t_vysledky_otazka5_souhrn_korelaci AS
WITH ekonomicka_data_podle_roku AS (
    -- KROK 1: Agregujeme ekonomické data z primární tabulky podle roku
    
    SELECT 
        p.rok,
        AVG(p.prumerna_mzda) AS prumerna_mzda,  -- Agregujeme přes všechny záznamy v primární tabulce
        AVG(p.cena) AS prumerna_cena            -- Agregujeme ceny ze všech kombinací obor+potravina
    FROM t_filip_hedvik_project_SQL_primary_final p
    WHERE p.rok BETWEEN 2006 AND 2018
    GROUP BY p.rok
),
hdp_data AS (
    -- KROK 2: Získáme HDP data
    SELECT 
        s.rok,
        s.hdp AS hdp_cr
    FROM t_filip_hedvik_project_SQL_secondary_final s
    WHERE s.zeme = 'Czech Republic'
),
korelacni_data AS (
    -- KROK 3: Spojíme ekonomická data s HDP
    SELECT 
        e.rok,
        h.hdp_cr,
        e.prumerna_mzda,
        e.prumerna_cena,
        
        -- KROK 4: Vypočítáme meziroční růst HDP
        CASE 
            WHEN LAG(h.hdp_cr) OVER (ORDER BY e.rok) > 0 
            THEN ((h.hdp_cr - LAG(h.hdp_cr) OVER (ORDER BY e.rok)) * 100.0 / LAG(h.hdp_cr) OVER (ORDER BY e.rok))
            ELSE NULL 
        END AS rust_hdp,
        
        -- KROK 5: Vypočítáme meziroční růst mezd (pomocí LAG na agregovaných datech)
        ((e.prumerna_mzda - LAG(e.prumerna_mzda) OVER (ORDER BY e.rok)) * 100.0 / 
        LAG(e.prumerna_mzda) OVER (ORDER BY e.rok)) AS rust_mezd,
        
        -- KROK 6: Vypočítáme meziroční růst cen (pomocí LAG na agregovaných datech)
        ((e.prumerna_cena - LAG(e.prumerna_cena) OVER (ORDER BY e.rok)) * 100.0 / 
        LAG(e.prumerna_cena) OVER (ORDER BY e.rok)) AS rust_cen
        
    FROM ekonomicka_data_podle_roku AS e
    JOIN hdp_data h ON e.rok = h.rok  -- ZJEDNODUŠENÝ JOIN
)
SELECT 
    -- KROK 5: Vytvoříme souhrnnou statistiku pro odpověď na otázku
    'SOUHRN VZTAHŮ HDP vs EKONOMIKA' AS analyza,
    COUNT(*) AS pocet_let_s_daty,
    
    -- Průměrné tempo růstu jednotlivých ukazatelů
    ROUND(AVG(rust_hdp)::numeric, 2) AS prumerny_rust_hdp_v_procentech,
    ROUND(AVG(rust_mezd)::numeric, 2) AS prumerny_rust_mezd_v_procentech,
    ROUND(AVG(rust_cen)::numeric, 2) AS prumerny_rust_cen_v_procentech,
    
    -- KROK 6: Analýza vztahu mezi růstem HDP a ekonomickými ukazateli
    COUNT(CASE WHEN rust_hdp > 5 THEN 1 END) AS roky_vyrazneho_rustu_hdp,
    
    -- V letech s výrazným růstem HDP: kolikrát rostly i mzdy rychle?
    COUNT(CASE WHEN rust_hdp > 5 AND rust_mezd > 5 THEN 1 END) AS roky_rychleho_rustu_mezd_i_hdp,
    
    -- V letech s výrazným růstem HDP: kolikrát rostly i ceny rychle?
    COUNT(CASE WHEN rust_hdp > 5 AND rust_cen > 5 THEN 1 END) AS roky_rychleho_rustu_cen_i_hdp,
    
    -- Průměrný růst mezd v letech s rychlým růstem HDP
    ROUND(AVG(CASE WHEN rust_hdp > 5 THEN rust_mezd END)::numeric, 2) AS prumerny_rust_mezd_kdyz_hdp_rostlo,
    
    -- Průměrný růst cen v letech s rychlým růstem HDP  
    ROUND(AVG(CASE WHEN rust_hdp > 5 THEN rust_cen END)::numeric, 2) AS prumerny_rust_cen_kdyz_hdp_rostlo
    
FROM korelacni_data
WHERE rust_hdp IS NOT NULL AND rust_mezd IS NOT NULL AND rust_cen IS NOT NULL;  -- Jen kompletní data


-- =====================================================
-- NÁVOD K POUŽITÍ VÝSLEDKOVÝCH TABULEK S HODNOCENÍM TRENDU
-- =====================================================

/*
VYTVOŘENÉ VÝSLEDKOVÉ TABULKY:

1. t_vysledky_otazka1_vyvoj_mezd
   
   - KATEGORIE: 'výrazný růst' (≥80%), 'silný růst' (≥50%), 'mírný růst' (≥20%), 'stagnace' (≥0%), 'pokles' (<0%)
   - POUŽITÍ: Rychlé pochopení, který obor si vedl nejlépe/nejhůře

2. t_vysledky_otazka2_kupni_sila  
   
   - KATEGORIE: 'výrazné zlepšení' (≥30%), 'zlepšení' (≥10%), 'stabilní' (≥-5%), 'mírné zhoršení' (≥-15%), 'výrazné zhoršení' (<-15%)
   - POUŽITÍ: Jasné poselství o vývoji dostupnosti základních potravin

3. t_vysledky_otazka3_zdrazovani_potravin
   
   - KATEGORIE: 'zlevňování' (≤0%), 'velmi pomalé zdražování' (≤2%), 'pomalé zdražování' (≤5%), 
     'střední zdražování' (≤8%), 'rychlé zdražování' (≤12%), 'velmi rychlé zdražování' (>12%)
   - POUŽITÍ: Identifikace "cenově stabilních" vs "problematických" potravin

4. t_vysledky_otazka4_rozdil_ceny_mzdy
   
   - KATEGORIE: 'výrazné zhoršení životní úrovně' (≥10%), 'zhoršení životní úrovně' (≥5%), 
     'stabilní životní úroveň' (≥-2%), 'mírné zlepšení životní úrovně' (≥-8%), 'výrazné zlepšení životní úrovně' (<-8%)
   - POUŽITÍ: Přímá odpověď na otázku o problematických letech



*/