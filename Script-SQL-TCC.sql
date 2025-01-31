CREATE TABLE public.users (
	id serial4 NOT NULL,
	fullname varchar(100) NOT NULL,
	username varchar(50) NOT NULL,
	"password" varchar(255) NOT NULL,
	email varchar(50) NOT NULL,
	CONSTRAINT users_pkey PRIMARY KEY (id)
);

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


-- Bibliotecas 

CREATE EXTENSION pg_trgm;
CREATE EXTENSION unaccent;

-- Criação do documento na tabela researcher

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
where search @@ websearch_to_tsquery('Ciência');

select "name", abstract, ts_rank_cd(
    search,
    to_tsquery('simple', websearch_to_tsquery('simple', 'Ciência de dados')::text || ':*')
) AS rank
FROM researcher
WHERE search @@ to_tsquery('simple', websearch_to_tsquery('simple', 'Ciência de dados')::text || ':*')
ORDER BY rank DESC;

SELECT * FROM researcher 
WHERE search @@ to_tsquery('simple', 'Ciência | dados')


select id uuid,
name varchar,
citations varchar,
abstract varchar,
abstract_en varchar,
other_information varchar,
qtt_publications int,
ts_rank(search, websearch_to_tsquery('simple','Ciência <-> dados')) +
ts_rank(search, websearch_to_tsquery('english','Ciência <-> dados'))
as rank
from researcher 
where search @@ websearch_to_tsquery('simple','Ciência <-> dados') 
or search @@ websearch_to_tsquery('english','Ciência <-> dados')
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

select * from search_researcher('Robótica & ! inteligente');

-- Continuação -- Criação de um documento para o TCC

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
select
	researcher.id,
	researcher.name,
   	researcher.abstract,
   	programa_ies.nome_programa,
   	setweight(to_tsvector('simple', researcher.abstract), 'A') ||
   	setweight(to_tsvector('simple', researcher.name), 'B') ||
   	setweight(to_tsvector('simple', programa_ies.nome_programa), 'C') ||
   	setweight(to_tsvector('simple', coalesce(string_agg(programa_ies.nome_docente, ' '))), 'A') as document
FROM "researcher_Programa_ies"
JOIN programa_ies on programa_ies.id = "researcher_Programa_ies".programas_id_ies
JOIN researcher on researcher.id = "researcher_Programa_ies".researcher_id
GROUP BY researcher.id, programa_ies.id;


CREATE INDEX idx_fts_search ON search_index USING gin(document);

SELECT name,nome_programa,abstract
FROM search_index 
WHERE document @@ websearch_to_tsquery('simple', 'Ciência de dados')
ORDER BY ts_rank(document, websearch_to_tsquery('simple', 'Ciência de dados')) DESC;

--Consulta das informações--
select name varchar,
nome_programa varchar,
abstract varchar,
ts_rank(document, websearch_to_tsquery('simple','Ciência de dados'))
as rank
from search_index 
where document @@ websearch_to_tsquery('simple','Ciência de dados') 
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

select * from search_search_index('Faculdade de Educação');

SELECT * FROM search_index
WHERE document @@ to_tsquery('simple', 'Faculdade & !Educação')

select name, abstract, ts_rank_cd(
    document,
    to_tsquery('simple', websearch_to_tsquery('simple', 'Faculdade de Educação')::text || ':*')
) AS rank
FROM search_index
WHERE document @@ to_tsquery('simple', websearch_to_tsquery('simple', 'Faculdade de Educação')::text || ':*')
ORDER BY rank DESC;

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


SELECT word,similarity(word, :q) AS sml
  FROM unique_lexeme
  WHERE word % :q
  ORDER BY sml DESC, word;

SELECT word
FROM unique_lexeme
WHERE similarity(word, :q) >= 0.5
ORDER BY word <-> :q;

select * from search_search_index('Informação');

select * from search_index 
where document @@ websearch_to_tsquery('simple','Sistemas de Informação') 

SELECT * FROM search_index
WHERE document @@ to_tsquery('simple', 'Sistemas & !Informação')

SELECT *
FROM search_index
WHERE document @@ to_tsquery('simple', websearch_to_tsquery('simple', 'Sistemas de Informação')::text || ':*');
