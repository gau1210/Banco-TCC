CREATE TABLE public.employee (
	id serial PRIMARY KEY,
	name VARCHAR ( 100 ) NOT NULL,
	position VARCHAR ( 100 ) NOT NULL,
	office VARCHAR ( 100 ) NOT NULL,
	age INT NOT NULL,
	salary INT NOT NULL,
	photo VARCHAR ( 150 ) NOT NULL
);


INSERT INTO
    employee(name, position, office, age, salary, photo)
VALUES
	('Tiger Wood', 'Accountant', 'Tokyo', 36, 5689, '01.jpg'),
	('Mark Oto Ednalan', 'Chief Executive Officer (CEO)', 'London', 56, 5648, '02.jpg'),
	('Jacob thompson', 'Junior Technical Author', 'San Francisco', 23, 5689, '03.jpg'),
	('cylde Ednalan', 'Software Engineer', 'Olongapo', 23, 54654, '04.jpg'),
	('Rhona Davidson', 'Software Engineer', 'San Francisco', 26, 5465, '05.jpg'),
	('Quinn Flynn', 'Integration Specialist', 'New York', 53, 56465, '06.jpg'),
	('Tiger Nixon', 'Software Engineer', 'London', 45, 456, '07.jpg'),
	('Airi Satou', 'Pre-Sales Support', 'New York', 25, 4568, '08.jpg'),
	('Angelica Ramos', 'Sales Assistant', 'New York', 45, 456, '09.jpg'),
	('Ashton updated', 'Senior Javascript Developer', 'Olongapo', 45, 54565, '01.jpg'),
	('Bradley Greer', 'Regional Director', 'San Francisco', 27, 5485, '02.jpg'),
	('Brenden Wagner', 'Javascript Developer', 'San Francisco', 38, 65468, '03.jpg'),
	('Brielle Williamson', 'Personnel Lead', 'Olongapo', 56, 354685, '04.jpg'),
	('Bruno Nash', 'Customer Support', 'New York', 36, 65465, '05.jpg'),
	('cairocoders', 'Sales Assistant', 'Sydney', 45, 56465, '06.jpg'),
	('Zorita Serrano', 'Support Engineer', 'San Francisco', 38, 6548, '07.jpg'),
	('Zenaida Frank', 'Chief Operating Officer (COO)', 'San Francisco', 39, 545, '08.jpg'),
	('Sakura Yamamoto', 'Support Engineer', 'Tokyo', 48, 5468, '05.jpg'),
	('Serge Baldwin', 'Data Coordinator', 'Singapore', 85, 5646, '05.jpg'),
	('Shad Decker', 'Regional Director', 'Tokyo', 45, 4545, '05.jpg');

CREATE TABLE public.programa_ies (
	id uuid DEFAULT uuid_generate_v4() NOT NULL,
	ano_base varchar NOT NULL,
	cod_ies varchar NOT NULL,
	nome_programa varchar NOT NULL,
	modalidade_programa varchar NOT NULL,
	entidade_ensino varchar NOT NULL,
	nome_docente varchar NOT NULL,
	ano_titulacao varchar NOT NULL,
	grau_titulacao varchar NOT NULL,
	CONSTRAINT programa_ies_pkey PRIMARY KEY (id)
);

CREATE TABLE public.researcher (
	id uuid DEFAULT uuid_generate_v4() NOT NULL,
	"name" varchar(108) NULL,
	citations varchar(3820) NULL,
	abstract varchar(34620) NULL,
	abstract_en varchar(12770) NULL,
	other_information varchar(20290) NULL,
	qtt_publications int8 NULL,
	CONSTRAINT researcher_pkey PRIMARY KEY (id)
);

CREATE TABLE public."researcher_Programa_ies" (
	researcher_id uuid NULL,
	programas_id_ies uuid NULL,
	CONSTRAINT programas_id_fk FOREIGN KEY (programas_id_ies) REFERENCES public.programa_ies(id) ON DELETE CASCADE ON UPDATE CASCADE,
	CONSTRAINT researcher_id_fk FOREIGN KEY (researcher_id) REFERENCES public.researcher(id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE EXTENSION pg_trgm;
CREATE EXTENSION unaccent;

SELECT d.name, g.nome_docente,d.id, g.id, ano_base,nome_programa, grau_titulacao, entidade_ensino  FROM researcher d, programa_ies g
WHERE
LOWER(d.name) != LOWER(g.nome_docente) AND
 similarity(unaccent(LOWER(d.name)),unaccent(LOWER(g.nome_docente)))>0.8
UNION
SELECT d.name, g.nome_docente,d.id, g.id, ano_base,nome_programa, grau_titulacao, entidade_ensino FROM researcher d, programa_ies g
WHERE unaccent(LOWER(d.name)) = unaccent(LOWER(g.nome_docente));

SELECT d.id, g.id FROM researcher d, programa_ies g
WHERE
LOWER(d.name) != LOWER(g.nome_docente) AND
 similarity(unaccent(LOWER(d.name)),unaccent(LOWER(g.nome_docente)))>0.8
UNION
SELECT d.id, g.id FROM researcher d, programa_ies g
WHERE unaccent(LOWER(d.name)) = unaccent(LOWER(g.nome_docente));


select abstract from researcher where abstract like '%experiência na área de Direito%';
explain select abstract from researcher where abstract like '%experiência na área de Direito%';
select to_tsvector('experiência na área de Direito');
select to_tsvector(abstract) from researcher limit 10; 

select abstract 
from researcher 
where to_tsvector(abstract) @@ to_tsquery('Direito');  

select abstract, ts_rank(to_tsvector(abstract),to_tsquery('Direito'))as rank
from researcher
where not to_tsvector(abstract) @@ to_tsquery('Direito')
order by rank desc;

select to_tsvector('simple','Olga Mettig BA');
select to_tsvector('simple',abstract) from researcher;

select 
setweight(to_tsvector('simple',abstract),'A') || ' ' ||
setweight(to_tsvector('simple',name),'B') || ' ' ||
setweight(to_tsvector('simple',abstract_en),'C'):: tsvector
from researcher;

alter table researcher add search tsvector;

update researcher 
set search = setweight(to_tsvector('simple',abstract),'A') || ' ' ||
setweight(to_tsvector('simple',name),'B') || ' ' ||
setweight(to_tsvector('simple',abstract_en),'C'):: tsvector;

alter table researcher drop search;

alter table researcher 
add search tsvector
generated always as (
setweight(to_tsvector('simple',abstract),'B') || ' ' ||
setweight(to_tsvector('simple',name),'A') || ' ' ||
setweight(to_tsvector('english',abstract_en),'C'):: tsvector
) stored;

create index idx_search on researcher using GIN(search);

select abstract from researcher 
where search @@ to_tsquery('Edu');

select abstract from researcher 
where search @@ plainto_tsquery('Olga Mettig BA');

select plainto_tsquery('Olga Mettig BA');
select phraseto_tsquery('Olga Mettig BA'); 

select abstract from researcher 
where search @@ phraseto_tsquery('Olga Mettig');

select websearch_to_tsquery('Olga Mettig or BA');

select abstract from researcher 
where search @@ websearch_to_tsquery('Olga Mettig BA'); 

select id uuid,
name varchar,
citations varchar,
abstract varchar,
abstract_en varchar,
other_information varchar,
qtt_publications int,
ts_rank(search, websearch_to_tsquery('simple','Ciência de dados')) +
ts_rank(search, websearch_to_tsquery('english','Ciência de dados'))
as rank
from researcher 
where search @@ websearch_to_tsquery('simple','Ciência de dados') 
or search @@ websearch_to_tsquery('english','Ciência de dados')
order by rank desc;

create or replace function search_researcher(term text)
returns table (
    id uuid,
    name varchar,
    citations varchar,
    abstract varchar,
    abstract_en varchar,
    other_information varchar
) as
$$
begin
    return QUERY
    select
        r.id,
        r.name,
        r.citations,
        r.abstract,
        r.abstract_en,
        r.other_information
    from
        researcher as r
    where
        r.search @@ websearch_to_tsquery('simple', term)
        OR r.search @@ websearch_to_tsquery('english', term)
    order by
        ts_rank(r.search, websearch_to_tsquery('simple', term)) +
        ts_rank(r.search, websearch_to_tsquery('english', term)) DESC;
end;
$$
language plpgsql;

select * from search_researcher('Robótica & inteligente');

-- Continuação -- Criação de um documento 

SELECT researcher.citations || ' ' || researcher.abstract || ' ' || programa_ies.nome_programa || ' ' ||
  COALESCE(string_agg(programa_ies.nome_docente, ' '), '') AS document
FROM researcher
JOIN programa_ies ON similarity(unaccent(LOWER(researcher.name)), unaccent(LOWER(programa_ies.nome_docente))) > 0.8
GROUP BY researcher.id, programa_ies.id;

SELECT to_tsvector(researcher.citations) ||
    to_tsvector(researcher.abstract) ||
    to_tsvector(programa_ies.nome_programa) ||
    to_tsvector(coalesce((string_agg(programa_ies.nome_docente, ' ')), '')) as document
FROM researcher
JOIN programa_ies ON similarity(unaccent(LOWER(researcher.name)), unaccent(LOWER(programa_ies.nome_docente))) > 0.8
GROUP BY researcher.id, programa_ies.id;

SELECT researcher.citations || ' ' || researcher.abstract || ' ' || programa_ies.nome_programa || ' ' ||
  COALESCE(string_agg(programa_ies.nome_docente, ' '), '') AS document
FROM "researcher_Programa_ies"
JOIN programa_ies on programa_ies.id = "researcher_Programa_ies".programas_id_ies
JOIN researcher on researcher.id = "researcher_Programa_ies".researcher_id 
GROUP BY researcher.id, programa_ies.id;

SELECT to_tsvector(researcher.citations) ||
    to_tsvector(researcher.abstract) ||
    to_tsvector(programa_ies.nome_programa) ||
    to_tsvector(coalesce((string_agg(programa_ies.nome_docente, ' ')), '')) as document
FROM "researcher_Programa_ies"
JOIN programa_ies on programa_ies.id = "researcher_Programa_ies".programas_id_ies
JOIN researcher on researcher.id = "researcher_Programa_ies".researcher_id 
GROUP BY researcher.id, programa_ies.id;

ALTER TABLE researcher ADD language text NOT NULL DEFAULT('english');

CREATE TEXT SEARCH CONFIGURATION usimple ( COPY = simple );
ALTER TEXT SEARCH CONFIGURATION usimple ALTER MAPPING
FOR hword, hword_part, word WITH unaccent, simple;

-- Criação de uma tabela View --
CREATE MATERIALIZED VIEW search_index AS
SELECT
	researcher.name,
   	researcher.abstract,
   	setweight(to_tsvector(researcher.language::regconfig, researcher.name), 'A') ||
   	setweight(to_tsvector(researcher.language::regconfig, researcher.abstract), 'B') ||
   	setweight(to_tsvector(researcher.language::regconfig, programa_ies.nome_programa), 'C') ||
   	setweight(to_tsvector('simple', coalesce(string_agg(programa_ies.nome_docente, ' '))), 'A') as document
FROM researcher
JOIN programa_ies ON similarity(unaccent(LOWER(researcher.name)), unaccent(LOWER(programa_ies.nome_docente))) > 0.8
GROUP BY researcher.id, programa_ies.id;

CREATE MATERIALIZED VIEW search_index AS
select
	researcher.id,
	researcher.name,
   	researcher.abstract,
   	programa_ies.nome_programa,
   	setweight(to_tsvector(researcher.language::regconfig, researcher.name), 'A') ||
   	setweight(to_tsvector(researcher.language::regconfig, researcher.abstract), 'B') ||
   	setweight(to_tsvector(researcher.language::regconfig, programa_ies.nome_programa), 'C') ||
   	setweight(to_tsvector('simple', coalesce(string_agg(programa_ies.nome_docente, ' '))), 'A') as document
FROM "researcher_Programa_ies"
JOIN programa_ies on programa_ies.id = "researcher_Programa_ies".programas_id_ies
JOIN researcher on researcher.id = "researcher_Programa_ies".researcher_id
GROUP BY researcher.id, programa_ies.id;

CREATE INDEX idx_fts_search ON search_index USING gin(document);

SELECT id as id,abstract
FROM search_index
WHERE document @@ to_tsquery('simple', 'Ciência')
ORDER BY ts_rank(document, to_tsquery('simple', 'Ciência')) DESC;

--Consulta das informações--
select id uuid,
name varchar,
nome_programa varchar,
abstract varchar,
ts_rank(document, websearch_to_tsquery('simple','Ciência de dados')) +
ts_rank(document , websearch_to_tsquery('english','Ciência de dados'))
as rank
from search_index 
where document @@ websearch_to_tsquery('simple','Ciência de dados') 
or document  @@ websearch_to_tsquery('english','Ciência de dados')
order by rank desc;


CREATE OR REPLACE FUNCTION search_search_index(term text)
RETURNS TABLE (
	id uuid,
    name varchar,
    abstract varchar,
    nome_programa varchar  
) AS
$$
BEGIN
    RETURN QUERY
    select
    	r.id uuid,
        r.name,
        r.abstract,
        r.nome_programa varchar 
    FROM
        search_index AS r
    WHERE
        r.document @@ websearch_to_tsquery('simple', term)
        OR r.document @@ websearch_to_tsquery('english', term)
    ORDER BY
        ts_rank(r.document, websearch_to_tsquery('simple', term)) +
        ts_rank(r.document, websearch_to_tsquery('english', term)) DESC;
END;
$$
LANGUAGE plpgsql;

select * from search_search_index('Ciência de dados');

CREATE MATERIALIZED VIEW unique_lexeme AS
SELECT word FROM ts_stat(
$$SELECT to_tsvector('simple', researcher.name) ||
	to_tsvector('simple', researcher.abstract) ||
	to_tsvector('simple', programa_ies.nome_programa) ||
	to_tsvector('simple', coalesce(string_agg(programa_ies.nome_docente, ' ')))
FROM "researcher_Programa_ies"
JOIN programa_ies on programa_ies.id = "researcher_Programa_ies".programas_id_ies
JOIN researcher on researcher.id = "researcher_Programa_ies".researcher_id
GROUP BY researcher.id, programa_ies.id$$);

CREATE INDEX words_idx ON unique_lexeme USING gin(word gin_trgm_ops);

REFRESH MATERIALIZED VIEW unique_lexeme;


SELECT word,similarity(word, 'Ciência de dados') AS sml
  FROM unique_lexeme
  WHERE word % 'Ciência de dados'
  ORDER BY sml DESC, word;

SELECT word
FROM unique_lexeme
WHERE similarity(word, 'Ciência de dados') >= 0.5
ORDER BY word <-> 'Ciência de dados';

select * from search_search_index('Ciência de dados');
