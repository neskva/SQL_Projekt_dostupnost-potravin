# Analýza dostupnosti základních potravin v České republice
**Projekt z SQL | Autor: Filip Hedvik | Datum: 2025-06-05**

##  Přehled projektu

### Zadání
Analytické oddělení nezávislé společnosti zabývající se životní úrovní občanů požadovalo **robustní datové podklady** pro analýzu **dostupnosti základních potravin široké veřejnosti**. Cílem bylo porovnání dostupnosti potravin na základě průměrných příjmů za určité časové období (2006-2018).

### Datové zdroje
- **Primární data**: Portál otevřených dat ČR
- **Mzdy**: `czechia_payroll` + číselníky
- **Ceny potravin**: `czechia_price` + číselníky  
- **Evropská data**: `countries` + `economies`

---

##  Výzkumné otázky

1. **Vývoj mezd**: Rostou v průběhu let mzdy ve všech odvětvích, nebo v některých klesají?
2. **Kupní síla**: Kolik litrů mléka a kg chleba si lze koupit za průměrnou mzdu v prvním vs posledním roce?
3. **Inflace potravin**: Která kategorie potravin zdražuje nejpomaleji?
4. **Cenový šok**: Existuje rok s meziročním nárůstem cen výrazně vyšším než růst mezd (>10%)?
5. **Vliv HDP**: Má výška HDP vliv na změny ve mzdách a cenách potravin?

---

##  Struktura souborů

### Hlavní SQL skripty
- **`00_reference_ciselníky.sql`** - Referenční číselníky a debugging poznámky
- **`01_create_tables.sql`** - Vytvoření hlavních tabulek
- **`02_analytical_queries.sql`** - Analytické dotazy pro výzkumné otázky
- **`03_create_result_tables.sql`** - Výsledkové tabulky

---

##   Klíčové technické poznatky

### Používané číselníky 

#### Mzdy - finální kombinace kódů:
```sql
value_type_code = 5958  -- Průměrná hrubá mzda na zaměstnance
unit_code = 200         -- tisíce Kč (ne 80403!)
calculation_code = 200  -- přepočtený (standardizovaná data)
```

#### Potraviny - konkrétní kódy:
```sql
114201 -- Mléko polotučné pasterované (l)
111301 -- Chléb konzumní kmínový (kg)
```

### Debugging kroky, které fungovaly:
1. **Systematické testování kombinací kódů** před implementací
2. **Postupné testování** každé části dotazu zvlášť
3. **Kontrola duplikátů** pomocí `COUNT() GROUP BY`
4. **Čištění dat u zdroje** místo záplat v dotazech

---

##  Hlavní problémy a jejich řešení

### 1. Prázdná hlavní tabulka 
**Problém**: `CREATE TABLE` vrátilo 0 záznamů
```sql
--  NESPRÁVNĚ (0 záznamů)
WHERE value_type_code = 5958 AND unit_code = 80403 AND calculation_code = 200

--  SPRÁVNĚ (3440 záznamů)  
WHERE value_type_code = 5958 AND unit_code = 200 AND calculation_code = 200
```
**Ponaučení**: Unit_code 80403 (Kč) se v prvotní verzi nepoužíval s mzdami, ale jen s počty osob. Při jedné z následujících lekcí došlo k opravě na straně základní databáze

### 2. Chyba ROUND() funkce 
**Problém**: `function round(double precision, integer) does not exist`
```sql
--  NESPRÁVNĚ
ROUND(AVG(cp.value), 2)

--  SPRÁVNĚ  
ROUND(AVG(cp.value)::numeric, 2)
```
**Vysvětlení**: PostgreSQL vyžaduje explicitní přetypování na `numeric` pro `ROUND()`.

### 3. Syntaktická chyba vnořených subqueries 
**Problém**: `syntax error at or near 'ceny'`
```sql
--  NESPRÁVNĚ - vnořené SELECT v FROM
FROM (SELECT ...) ceny
JOIN (SELECT ...) mzdy ON ...

--  SPRÁVNĚ - WITH klauzule (CTE)
WITH ceny AS (SELECT ...),
     mzdy AS (SELECT ...)
SELECT ... FROM ceny JOIN mzdy ON ...
```

### 4. Duplicitní data v sekundární tabulce 
**Problém**: Otázka 5 hlásila 26/52 let místo 13 let
```sql
-- Identifikace problému
SELECT rok, COUNT(*) FROM t_filip_hedvik_project_SQL_secondary_final 
WHERE zeme = 'Czech Republic' GROUP BY rok;
-- Výsledek: každý rok měl 4 identické záznamy

-- Řešení u zdroje
CREATE TABLE t_filip_hedvik_project_SQL_secondary_final AS
SELECT DISTINCT * FROM t_filip_hedvik_project_SQL_secondary_final_raw;
```

---

##  Výsledné tabulky

### Hlavní výstupy
1. **`t_filip_hedvik_project_SQL_primary_final`** 
   - Propojuje mzdy a ceny potravin v ČR (2006-2018)
   - Počítá kupní sílu pro každou kombinaci obor-potravina-rok

2. **`t_filip_hedvik_project_SQL_secondary_final`** 
   - Údaje o evropských zemích (HDP, GINI, populace)
   - Období 2006-2018 pro mezinárodní srovnání

### Výsledkové tabulky pro každou otázku
- **`t_vysledky_otazka1_vyvoj_mezd`** - Vývoj mezd podle odvětví
- **`t_vysledky_otazka2_kupni_sila`** - Kupní síla mléka a chleba
- **`t_vysledky_otazka3_zdrazovani_potravin`** - Nejpomaleji zdražující potraviny
- **`t_vysledky_otazka4_rozdil_ceny_mzdy`** - Roky s výrazným rozdílem cen vs mezd
- **`t_vysledky_otazka5_vliv_hdp`** - Vliv HDP na ekonomické ukazatele
- **`t_souhrn_klicovych_vysledku`** - Souhrnné klíčové výsledky

---

##  Klíčová zjištění 

### Otázka 1: Vývoj mezd
- **Analyzováno**: Všechna odvětví v ČR (2006 vs 2018)
- **Výsledek**: Většina odvětví zaznamenala růst mezd
- **Průměrný růst**: Cca 30-50% za 12 let

### Otázka 2: Kupní síla
- **Mléko**: Změna kupní síly 2006 → 2018
- **Chléb**: Změna kupní síly 2006 → 2018
- **Trend**: Zlepšení/zhoršení kupní síly

### Otázka 3: Inflace potravin
- **Analyzováno**: 28 kategorií potravin
- **Nejpomalejší zdražování**: [výsledek z analýzy]
- **Nejrychlejší zdražování**: [výsledek z analýzy]

### Otázka 4: Cenové šoky
- **Kritérium**: Rozdíl růstu cen vs mezd >10%
- **Problematické roky**: [identifikované roky]

### Otázka 5: Vliv HDP
- **Korelace**: HDP vs mzdy vs ceny potravin
- **Časové posuny**: Projeví se změna HDP ve stejném nebo následujícím roce?

---

##  Metodika analýzy

### Časové pokrytí
- **Období**: 2006-2018 (13 let)
- **Společné roky** pro mzdy i ceny potravin

### Datová kvalita
- **Filtrace**: Pouze platné hodnoty (NOT NULL, > 0)
- **Standardizace**: Přepočtené hodnoty (`calculation_code = 200`)
- **Agregace**: Průměry pro eliminace sezónních výkyvů
- **Čištění duplikátů**: `DISTINCT` u sekundárních dat

### Použité techniky
- **Window functions**: `LAG()`, `LEAD()` pro meziroční srovnání
- **CASE WHEN**: Pro kategorizaci a hodnocení trendů
- **CTE (WITH klauzule)**: Čitelná struktura komplexních dotazů
- **Agregace**: `AVG()`, `COUNT()`, `MIN()`, `MAX()`

---

##  Doporučení pro budoucí práci

### Pro rozšíření analýzy
1. **Regionální analýza**: Použití `czechia_region`, `czechia_district`
2. **Další potraviny**: Všechny kódy z `czechia_price_category`
3. **Další odvětví**: Detailní analýza pomocí `industry_branch_code`


---


**Autor**: Filip Hedvik  
**Poslední aktualizace**: 2025-06-05  
**Verze databáze**: PostgreSQL  

**Pro dotazy k projektu**:
- Referenční kódy: `00_reference_ciselníky.sql`
- Debugging historie: Komentáře v souborech
- Metodika: Tento README soubor

---

*Tento projekt byl vytvořen, v rámci kurzu Datová akademie od ENGETO,jako analýza dostupnosti základních potravin pro širokou veřejnost v České republice. Všechna data pocházejí z Portálu otevřených dat ČR a jsou zpracována v souladu s metodikou transparentní datové analýzy.*
