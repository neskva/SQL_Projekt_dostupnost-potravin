-- =====================================================
-- PROJEKT: Analýza dostupnosti základních potravin v České republice
-- Autor: Filip Hedvik
-- Soubor: 00_reference_dials.sql
-- Účel: Referenční číselníky a ověřené kódy pro projekt
-- =====================================================

/*
ÚČEL TOHOTO SOUBORU:
Tento soubor obsahuje všechny číselníky a ověřené kódy použité v projektu.
Slouží jako referenční dokumentace pro budoucí použití a údržbu.

STRUKTURA TOHOTO SOUBORU (00_reference_dials.sql):
1. Ověřené kódy použité v projektu
2. Historie řešených problémů
3. Historie změn  
4. Kompletní číselníky pro mzdy a ceny
5. Kontrolní dotazy pro NULL hodnoty

STRUKTURA OSTATNÍCH SOUBORŮ:
- 01_create_tables.sql: Vytvoření primární a sekundární tabulky
- 02_analytical_queries.sql: 5 výzkumných otázek (mzdy, kupní síla, zdražování, rozdíly, HDP)
- 03_create_result_tables.sql: Výsledkové tabulky pro každou otázku

DŮLEŽITÉ: Tento soubor slouží pouze k prohlížení číselníků, 
není určen pro spuštění jako celku!
*/

-- =====================================================
-- 1. OVĚŘENÉ KÓDY POUŽITÉ V PROJEKTU
-- =====================================================

/*
FINÁLNÍ KOMBINACE KÓDŮ PRO MZDY:
- value_type_code = 5958 (Průměrná hrubá mzda na zaměstnance)
- unit_code = 200 (Kč)
- calculation_code = 200 (přepočtený)
- Období: 2006-2018
- Počet záznamů: 1720

FINÁLNÍ KÓDY PRO POTRAVINY:
- 114201 = Mléko polotučné pasterované (l)
- 111301 = Chléb konzumní kmínový (kg)
- Všechny kategorie z czechia_price_category

STRUKTURA PRIMÁRNÍ TABULKY:
- rok                    -- 2006-2018
- kod_odvetvi           -- 'A', 'B', 'C'... (pro spolehlivé filtrování)
- kod_potraviny         -- 114201, 111301... (pro spolehlivé filtrování)
- nazev_odvetvi         -- "Zemědělství..." (pro čtení)
- nazev_potraviny       -- "Mléko polotučné..." (pro čtení)
- prumerna_mzda         -- Průměrná mzda v Kč
- cena                  -- Průměrná cena potraviny
- kupni_sila           -- Kolik jednotek si koupíme za mzdu


DATOVÉ TYPY (ze skutečné databázové struktury):
- czechia_payroll.value_type_code: INT8/BIGINT (5958 = průměrná hrubá mzda)
- czechia_payroll.unit_code: INT8/BIGINT (200 = Kč)  
- czechia_payroll.calculation_code: INT8/BIGINT (200 = přepočtený)
- czechia_payroll.industry_branch_code: BPCHAR(1) (A, B, C...)
- czechia_payroll.value: INT8/BIGINT (mzdové hodnoty jako celá čísla)
- czechia_price.category_code: INT8/BIGINT (114201, 111301...)
- czechia_price.value: FLOAT8/DOUBLE PRECISION (cenové hodnoty s desetinnými místy)
- czechia_price.date_from/date_to: TIMESTAMPTZ (časové razítko s časovou zónou)
*/

-- =====================================================
-- 2. HISTORIE ŘEŠENÝCH PROBLÉMŮ
-- =====================================================

/*
PROBLÉMY KTERÉ JSME VYŘEŠILI A JAK:

1. PRÁZDNÁ HLAVNÍ TABULKA
PŘÍZNAK: CREATE TABLE vrátilo 0 záznamů
PŘÍČINA: Špatná kombinace kódů value_type=5958 + unit_code=80403 + calculation=200
ZJIŠTĚNÍ: Unit_code 80403 (Kč) se nepoužívá s mzdami!
ŘEŠENÍ: Změna unit_code z 80403 na 200
DEBUGGING PROCES:
1. Test: SELECT COUNT(*) WHERE value_type_code=5958 AND unit_code=80403 → 0 záznamů ❌
2. Test: SELECT COUNT(*) WHERE value_type_code=5958 AND unit_code=200 → 3440 záznamů ✅
3. Kontrola: SELECT * FROM czechia_payroll_unit WHERE code IN (80403, 200)
   - 80403 = "Kč" ← logické, ale nefunguje s mzdami
   - 200 = "tis. osob" ← matoucí název! Ve skutečnosti pro mzdy = "tisíce Kč"

MATOUCÍ SITUACE S ČÍSELNÍKEM:
- unit_code = 200 má název "tis. osob" (tisíce osob)
- ALE pro mzdy to znamená "tisíce Kč"!
- unit_code = 80403 má logický název "Kč" 
- ALE nefunguje s mzdami, jen s počty osob

TESTOVÁNÍ: SELECT unit_code, COUNT(*) FROM czechia_payroll WHERE value_type_code=5958 GROUP BY unit_code;
VÝSLEDEK: Pouze unit_code = 200 má data pro mzdy (i když název je matoucí)
	PONAUČENÍ: 
			1. Vždy testovat existující kombinace místo předpokladů
			2. Číselníky mohou mít matoucí názvy - testovat na skutečných datech!
			3. Logický název neznamená správné použití
Finální řešení: Na jedné z následující lekcí došlo k nahlášení chyby a k opravě v základnímu číselníku, takže už název kódu odpovídá			

2. CHYBA ROUND() FUNKCE 
   PROBLÉM: "function round(double precision, integer) does not exist"
   PŘÍČINA: PostgreSQL vyžaduje explicitní přetypování na numeric
   ŘEŠENÍ: Změna ROUND(AVG(cp.value), 2) na ROUND(AVG(cp.value)::numeric, 2)
   
3. SYNTAKTICKÁ CHYBA V CREATE TABLE
   PROBLÉM: "syntax error at or near 'ceny'"
   PŘÍČINA: Špatná struktura vnořených subqueries s aliasy
   ŘEŠENÍ: Přepis na WITH klauzule (CTE) - čitelnější a syntakticky správné

4. DUPLICITNÍ DATA V SEKUNDÁRNÍ TABULCE
   PROBLÉM: Otázka 5 hlásila 26/52 let místo 13 let
   PŘÍČINA: Sekundární tabulka obsahovala 4 identické záznamy pro každý rok ČR
   ŘEŠENÍ: Vyčištění pomocí DISTINCT

5. CHYBĚJÍCÍ KÓDY V PRIMÁRNÍ TABULCE
   PROBLÉM: Nelze spolehlivě filtrovat potraviny podle category_code
   PŘÍČINA: Primární tabulka neobsahovala kod_potraviny a kod_odvetvi
   ŘEŠENÍ: Přidání těchto sloupců do SELECT části

6. NULL HODNOTY V SEKUNDÁRNÍ TABULCE
   PROBLÉM: gini_koeficient a danove_zatez obsahují NULL u některých zemí
   PŘÍČINA: Ne všechny země reportují všechny ekonomické ukazatele
   DOPAD: Zkresuje mezinárodní srovnání, ale nevadí pro ČR analýzu
   ŘEŠENÍ:
		- Aktuálně: ponechat původní tabulku (naše analýzy fungují)
		- Pro budoucí srovnání: filtrovat WHERE gini_koeficient IS NOT NULL
		- Pro reporting: vždy kontrolovat pokrytí dat pomocí COUNT(sloupec)
		KONTROLA: SELECT zeme, COUNT(*), COUNT(gini_koeficient) FROM tabulka GROUP BY zeme;
   
*/

-- =====================================================
-- 3. HISTORIE ZMĚN
-- =====================================================

/*
HISTORIE ZMĚN:
-  Vytvoření souboru, ověření všech kódů
-  Oprava unit_code z 80403 na 200 pro mzdy (debugging prázdné tabulky)
-  Oprava calculation_code z 100 na 200 (přepočtený)
-  Přidání ::numeric pro ROUND() funkce (PostgreSQL kompatibilita)
-  Přepis na WITH klauzule místo vnořených subqueries (syntaktická chyba)
-  Vyčištění sekundární tabulky od duplikátů (problém s počtem let v otázce 5)
-  Přidání kod_odvetvi a kod_potraviny do primární tabulky (spolehlivé filtrování)
-  Dokumentace NULL hodnot v sekundární tabulce (mezinárodní srovnání)
-  Přechod na české aliasy bez diakritiky


DŮLEŽITÉ POZNATKY PRO BUDOUCNOST:
1. Vždy testovat existující kombinace kódů před implementací
2. PostgreSQL vyžaduje explicitní přetypování pro některé funkce
3. WITH klauzule jsou spolehlivější než vnořené subqueries
4. Čištění duplicitních dat u zdroje je lepší než komplikování dotazů
5. Systematické debugging šetří čas při řešení komplexních problémů
6. Kódy (kod_odvetvi, kod_potraviny) jsou nutné pro spolehlivé filtrování
7. NULL hodnoty v sekundární tabulce mohou zkreslit mezinárodní srovnání



*/

-- =====================================================
-- 4. KOMPLETNÍ ČÍSELNÍKY
-- =====================================================

-- Zobrazení všech typů hodnot v payroll datech
SELECT 
    'PAYROLL VALUE TYPES' AS kategorie,
    code AS kod,
    name AS popis
FROM czechia_payroll_value_type
ORDER BY code;

-- Zobrazení všech jednotek v payroll datech
SELECT 
    'PAYROLL UNITS' AS kategorie,
    code AS kod,
    name AS popis
FROM czechia_payroll_unit
ORDER BY code;

-- Kompletní číselník potravin s kódy
SELECT 
    'FOOD CATEGORIES' AS kategorie,
    code AS kod,
    name AS nazev_potraviny,
    price_unit AS jednotka
FROM czechia_price_category
ORDER BY code;

-- =====================================================
-- 5. KONTROLNÍ DOTAZY PRO NULL HODNOTY
-- =====================================================

-- Rychlá kontrola NULL hodnot v sekundární tabulce
SELECT 
    'NULL KONTROLA' AS typ,
    COUNT(*) AS celkem_zaznamu,
    COUNT(gini_koeficient) AS ma_gini,
    COUNT(danove_zatez) AS ma_dane,
    ROUND(COUNT(gini_koeficient) * 100.0 / COUNT(*), 1) AS procento_s_gini,
    ROUND(COUNT(danove_zatez) * 100.0 / COUNT(*), 1) AS procento_s_danemi
FROM t_filip_hedvik_project_SQL_secondary_final;

-- Kontrola NULL podle zemí
SELECT 
    zeme,
    COUNT(*) AS celkem_let,
    COUNT(gini_koeficient) AS let_s_gini,
    COUNT(danove_zatez) AS let_s_danemi,
    CASE 
        WHEN COUNT(gini_koeficient) = COUNT(*) THEN 'KOMPLETNÍ_GINI'
        WHEN COUNT(gini_koeficient) > COUNT(*) * 0.5 THEN 'ČÁSTEČNÉ_GINI'
        ELSE 'MÁLO_GINI_DAT'
    END AS kvalita_gini
FROM t_filip_hedvik_project_SQL_secondary_final
GROUP BY zeme
ORDER BY let_s_gini DESC;

-- =====================================================
-- KONEC REFERENČNÍHO SOUBORU
-- =====================================================

/*
NÁVOD K POUŽITÍ:

1. PŘED ZAČÁTKEM NOVÉHO PROJEKTU:
   - Spusťte kontrolní dotazy
   - Ověřte že kódy stále existují v datech
   - Zkontrolujte časové pokrytí a NULL hodnoty

2. PRO ROZŠÍŘENÍ ANALÝZY:
   - Použijte kódy z číselníků
   - Zvažte dopad NULL hodnot na výsledky
   - Přidejte nové problémy do historie

3. PRI LADĚNÍ PROBLÉMŮ:
   - Konzultujte sekci řešených problémů
   - Použijte kontrolní dotazy
   - Dokumentujte nová řešení

KONTAKT PRO DOTAZY:
Filip Hedvik - autor projektu
*/