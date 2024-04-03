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

select * from search_researcher('Ciência de dados');

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

SELECT to_tsvector('LEÃO, J. A. C. Professor e pesquisador efetivo titular na 
Graduação e Pós-Graduação da Universidade do Estado da Bahia (UNEB), no Departamento de Ciências Humanas 
(DCH I) e no Programa de Mestrado Profissional em Gestão e Tecnologias 
Aplicadas à Educação (GESTEC/UNEB). Graduação de Licenciatura Plena em 
Educação Física pela Universidade de Pernambuco (1988) e mestrado em Gestão 
de Políticas Públicas pela Fundação Joaquim Nabuco (2005). 
Doutorado Sanduíche pelo Instituto de Pesquisas 
Tropicais de Lisboa/Portugal (2010). Doutorado em Educação pela UFBA (2011) e 
Pós-doutorado em Artes Visuais pela UFBA (2021). Atua com os seguintes temas: 
Memória, Educação e diversidade cultural, Políticas públicas e linguagens 
geotecnológicas. GESTÃO E TECNOLOGIAS APLICADAS À EDUCAÇÃO 
JOSE ANTONIO CARNEIRO LEAO');

ALTER TABLE researcher ADD language text NOT NULL DEFAULT('english');

-- Criação de uma tabela View --
CREATE MATERIALIZED VIEW search_index AS
SELECT
	researcher.name,
   	researcher.abstract,
   	setweight(to_tsvector(researcher.language::regconfig, researcher.name), 'A') ||
   	setweight(to_tsvector(researcher.language::regconfig, researcher.abstract), 'B') ||
   	setweight(to_tsvector('simple', coalesce(string_agg(programa_ies.nome_docente, ' '))), 'A') as document
FROM researcher
JOIN programa_ies ON similarity(unaccent(LOWER(researcher.name)), unaccent(LOWER(programa_ies.nome_docente))) > 0.8
GROUP BY researcher.id, programa_ies.id;

--Consulta das informações--
select name varchar,
abstract varchar,
ts_rank(document, websearch_to_tsquery('simple','Pesquisa Científica')) +
ts_rank(document , websearch_to_tsquery('english','Pesquisa Científica'))
as rank
from search_index 
where document @@ websearch_to_tsquery('simple','Pesquisa Científica') 
or document  @@ websearch_to_tsquery('english','Pesquisa Científicar')
order by rank desc;


CREATE INDEX idx_fts_search ON search_index USING gin(document);
