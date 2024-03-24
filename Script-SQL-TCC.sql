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
	"search" tsvector GENERATED ALWAYS AS ((((setweight(to_tsvector('simple'::regconfig, abstract::text), 'A'::"char") || ''::tsvector) || setweight(to_tsvector('simple'::regconfig, name::text), 'B'::"char")) || ''::tsvector) || setweight(to_tsvector('english'::regconfig, abstract_en::text), 'C'::"char")) STORED NULL,
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
setweight(to_tsvector('simple',abstract),'A') || ' ' ||
setweight(to_tsvector('simple',name),'B') || ' ' ||
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
ts_rank(search, websearch_to_tsquery('simple','Olga Mettig BA')) +
ts_rank(search, websearch_to_tsquery('english','Olga Mettig BA'))
as rank
from researcher 
where search @@ websearch_to_tsquery('simple','Olga Mettig BA') 
or search @@ websearch_to_tsquery('english','Olga Mettig BA')
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

select * from search_researcher('Ciência de dados');
