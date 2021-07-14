DROP TABLE IF EXISTS places;
CREATE TABLE places (
     rowid  bigserial PRIMARY KEY,
     id character varying,
     name character varying,
     name_cym character varying,
     placetype character varying,
     entity character varying,
     entity_name character varying,
     entity_abbr character varying,
     parent_admin character varying,
     parent_census character varying,
     parent_electoral character varying,
     path_admin ltree,
     path_census ltree,
     path_electoral ltree,
     tree_admin character varying[],
     tree_census character varying[],
     tree_electoral character varying[],
     lng double precision,
     lat double precision,
     geom geometry(MultiPolygon,4326)
);

DROP INDEX IF EXISTS places_id_idx;
DROP INDEX IF EXISTS places_parent_admin_idx;
DROP INDEX IF EXISTS places_parent_electoral_idx;
DROP INDEX IF EXISTS places_parent_census_idx;
DROP INDEX IF EXISTS places_name_idx;
DROP INDEX IF EXISTS places_entity_idx;
DROP INDEX IF EXISTS places_path_admin_idx;
DROP INDEX IF EXISTS places_path_census_idx;
DROP INDEX IF EXISTS places_path_electoral_idx;
CREATE UNIQUE INDEX places_id_idx ON places USING btree(id);
CREATE INDEX places_parent_admin_idx ON places USING btree(parent_admin);
CREATE INDEX places_parent_census_idx ON places USING btree(parent_census);
CREATE INDEX places_parent_electoral_idx ON places USING btree(parent_electoral);
CREATE INDEX places_name_idx ON places USING btree(name);
CREATE INDEX places_entity_idx ON places USING btree(entity);
CREATE INDEX places_path_admin_idx ON places USING gist(path_admin);
CREATE INDEX places_path_census_idx ON places USING gist(path_census);
CREATE INDEX places_path_electoral_idx ON places USING gist(path_electoral);

INSERT INTO places(id,name,lng,lat,geom)
  	SELECT 'ONS:GSS:' || gsscode,name,lng,lat,geom
    FROM ons_ctry WHERE gsscode NOT LIKE 'N%';
INSERT INTO places(id,name,lng,lat,geom)
  	SELECT 'ONS:GSS:' || gsscode,name,lng,lat,geom FROM ons_rgn;
INSERT INTO places(id,name,name_cym,lng,lat,geom)
  	SELECT 'ONS:GSS:' || gsscode,name,name_cym,lng,lat,geom FROM ons_ctyua;
INSERT INTO places(id,name,lng,lat,geom)
  	SELECT 'ONS:GSS:' || gsscode,name,lng,lat,geom FROM ons_cauth;
INSERT INTO places(id,name,name_cym,lng,lat,geom)
  	SELECT 'ONS:GSS:' || gsscode,name,name_cym,lng,lat,geom
    FROM ons_lad WHERE gsscode NOT LIKE 'N%';
        -- WHERE id NOT LIKE 'E06%' AND id NOT LIKE 'E09%';
INSERT INTO places(id,name,lng,lat,geom)
  	SELECT 'ONS:GSS:' || gsscode,name,lng,lat,geom FROM ons_mcty;
INSERT INTO places(id,name,name_cym,lng,lat,geom)
  	SELECT 'ONS:GSS:' || gsscode,name,name_cym,lng,lat,geom FROM ons_parncp;
INSERT INTO places(id,name,lng,lat,geom)
  	SELECT 'ONS:GSS:' || gsscode,name,lng,lat,geom FROM os_gla;
INSERT INTO places(id,name,name_cym,lng,lat,geom)
	SELECT 'ONS:GSS:' || gsscode,name,name_cym,lng,lat,geom
    FROM ons_wd WHERE gsscode NOT LIKE 'N%';

-- UPDATE places
--     SET entity=substring(id,1,11),
--         entity_name=(SELECT name FROM ons_rgc WHERE substring(id,1,11) = ons_rgc.entity),	
--         entity_abbr=(SELECT abbr FROM ons_rgc WHERE substring(id,1,11) = ons_rgc.entity);	

INSERT INTO places(id,name,lng,lat,geom)
	SELECT 'ONS:GSS:' || gsscode,name,lng,lat,geom FROM ons_pcon;
INSERT INTO places(id,name,lng,lat,geom)
	SELECT 'ONS:GSS:' || gsscode,name,lng,lat,geom FROM ons_lac;
INSERT INTO places(id,name,lng,lat,geom)
	SELECT 'ONS:GSS:' || gsscode,name,lng,lat,geom FROM ons_spc;
INSERT INTO places(id,name,lng,lat,geom)
	SELECT 'ONS:GSS:' || gsscode,name,lng,lat,geom FROM ons_spr;
INSERT INTO places(id,name,lng,lat,geom)
	SELECT 'ONS:GSS:' || gsscode,name,lng,lat,geom FROM ons_nawc;
INSERT INTO places(id,name,name_cym,lng,lat,geom)
	SELECT 'ONS:GSS:' || gsscode,name,name_cym,lng,lat,geom FROM ons_nawer;
INSERT INTO places(id,name,lng,lat,geom)
    SELECT 'ONS:GSS:' || gsscode,name,lng,lat,geom FROM ons_eer;
INSERT INTO places(id,name,lng,lat,geom)
    SELECT gsscode,name,lng,lat,geom FROM osni_dea;
-- INSERT INTO places(id,name,lng,lat,geom)
--     SELECT 'ONS:GSS:' || gsscode,name,lng,lat,geom FROM os_ced;
INSERT INTO places(id,name,name_cym,lng,lat,geom)
    SELECT 'ONS:GSS:' || gsscode,name,name_cym,lng,lat,geom FROM osni_ctry;
INSERT INTO places(id,name,lng,lat,geom)
    SELECT 'ONS:GSS:' || gsscode,name,lng,lat,geom FROM osni_wd;
INSERT INTO places(id,name,lng,lat,geom)
    SELECT 'ONS:GSS:' || gsscode,name,lng,lat,ST_Force2D(geom) FROM osni_lgd;

-- UPDATE places
--     SET entity=substring(id,1,11),
--         entity_name=(SELECT name FROM ons_rgc WHERE substring(id,1,11) = ons_rgc.entity),	
--         entity_abbr=(SELECT abbr FROM ons_rgc WHERE substring(id,1,11) = ons_rgc.entity);	

INSERT INTO places(id,name,lng,lat,geom)
  	SELECT 'ONS:GSS:' || gsscode,name,lng,lat,geom FROM ons_msoa;
INSERT INTO places(id,name,lng,lat,geom)
  	SELECT 'ONS:GSS:' || gsscode,name,lng,lat,geom FROM ons_lsoa;
INSERT INTO places(id,lng,lat,geom)
  	SELECT 'ONS:GSS:' || gsscode,lng,lat,geom FROM ons_oa;

INSERT INTO places(id,parent_census,lng,lat,geom)
    SELECT 'ONS:GSS:' || gsscode, 'ONS:GSS:' || dz_gsscode, lng, lat, geom FROM nrs_oa;
INSERT INTO places(id,name,lng,lat,geom)
    SELECT 'ONS:GSS:' || gsscode, name, lng, lat, geom FROM mgs_dz;
INSERT INTO places(id,name,lng,lat,geom)
    SELECT 'ONS:GSS:' || gsscode, name, lng, lat, geom FROM mgs_iz;

INSERT INTO places(id,lat,lng,geom)
    SELECT 'NISRA:OA:' || code, lat, lng, geom FROM nisra_oa;

INSERT INTO places(id,parent_census,lng,lat,geom)
    SELECT 'ONS:GSS:' || gsscode, 'NISRA:SOA:' || soa_code, lng, lat, geom FROM nisra_sa;

INSERT INTO places(id,name,lng,lat,geom)
    SELECT 'NISRA:SOA:' || code, name, lng, lat, geom FROM nisra_soa;

-- UPDATE places
--     SET entity=(SELECT substring(id,1,13) FROM places WHERE id LIKE 'NISRA:OA:%');

-- UPDATE places
--     SET entity='ONS:GSS:' || substring(id,9,3) WHERE id LIKE 'ONS:GSS:%',
--         entity_name=(SELECT name FROM ons_rgc WHERE id LIKE 'ONS:GSS:%' AND substring(id,9,3) = ons_rgc.entity),	
--         entity_abbr=(SELECT abbr FROM ons_rgc WHERE id LIKE 'ONS:GSS:%' AND substring(id,9,3) = ons_rgc.entity);	

UPDATE places
    SET entity=substring(id,1,11),
        entity_name=(SELECT name FROM ons_rgc WHERE substring(id,1,11) = ons_rgc.entity),	
        entity_abbr=(SELECT abbr FROM ons_rgc WHERE substring(id,1,11) = ons_rgc.entity)
    WHERE substring(id,1,8) = 'ONS:GSS:';


-- UPDATE places
--      SET entity=(SELECT substring(id,1,13) WHERE id LIKE 'NISRA:OA:%'),
--          entity_name=(SELECT 'Output Areas' WHERE id LIKE 'NISRA:OA:%'),	
--          entity_abbr=(SELECT 'OA' WHERE id LIKE 'NISRA:OA:%');	

UPDATE places
    SET entity=(SELECT substring(id,1,11)),
        entity_name=(SELECT 'Output Areas'),	
        entity_abbr=(SELECT 'OA')
	WHERE substring(id,1,9) = 'NISRA:OA:';

-- UPDATE places
--       SET entity=(SELECT substring(id,1,14) WHERE substring(id,1,10) = 'NISRA:SOA:'),
--           entity_name=(SELECT 'Super Output Areas' WHERE substring(id,1,10) = 'NISRA:SOA:'),	
--           entity_abbr=(SELECT 'SOA' WHERE substring(id,1,10) = 'NISRA:SOA:');

UPDATE places
    SET entity=(SELECT substring(id,1,12)),
        entity_name=(SELECT 'Super Output Areas'),	
        entity_abbr=(SELECT 'SOA')
	WHERE substring(id,1,10) = 'NISRA:SOA:';

DROP TABLE IF EXISTS mgs_dz, mgs_iz;
DROP TABLE IF EXISTS nrs_oa;
DROP TABLE IF EXISTS nisra_oa, nisra_sa, nisra_soa;
DROP TABLE IF EXISTS os_gla;
DROP TABLE IF EXISTS ons_cauth, ons_ctyua, ons_lad, ons_msoa, ons_oa, ons_rgc, ons_spr;
DROP TABLE IF EXISTS ons_chd, ons_eer, ons_lsoa, ons_nawc, ons_parncp, ons_rgn, ons_wd;
DROP TABLE IF EXISTS ons_ctry, ons_lac, ons_mcty, ons_nawer, ons_pcon, ons_spc;
DROP TABLE IF EXISTS osni_ctry, osni_dea, osni_lgd, osni_wd;
