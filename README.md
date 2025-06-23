# Analýza dostupnosti základních potravin v České republice
**Projekt z SQL | Autor: Filip Hedvik **

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
- **`00_reference_dials.sql`** - Referenční číselníky a debugging poznámky
- **`01_create_tables.sql`** - Vytvoření hlavních tabulek
- **`02_analytical_queries.sql`** - Analytické dotazy pro výzkumné otázky
- **`03_create_result_tables.sql`** - Výsledkové tabulky


### Debugging kroky, které fungovaly:
1. **Systematické testování kombinací kódů** před implementací
2. **Postupné testování** každé části dotazu zvlášť
3. **Kontrola duplikátů** pomocí `COUNT() GROUP BY`
4. **Čištění dat u zdroje** místo záplat v dotazech

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
**Verze databáze**: PostgreSQL  

**Pro dotazy k projektu**:
- Referenční kódy: `00_reference_ciselníky.sql`
- Debugging historie: Komentáře v souborech
- Metodika: Tento README soubor

---

*Tento projekt byl vytvořen, v rámci kurzu Datová akademie od ENGETO,jako analýza dostupnosti základních potravin pro širokou veřejnost v České republice. Všechna data pocházejí z Portálu otevřených dat ČR a jsou zpracována v souladu s metodikou transparentní datové analýzy.*
